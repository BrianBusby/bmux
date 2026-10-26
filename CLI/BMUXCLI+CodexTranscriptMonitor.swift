import Darwin
import Foundation
import BmuxSettings
import ProvenanceEngineContracts

extension BMUXCLI {
    func runCodexTranscriptMonitor(commandArgs: [String], client: SocketClient) async throws {
        let env = ProcessInfo.processInfo.environment
        let workspaceId = optionValue(commandArgs, name: "--workspace") ?? env["BMUX_WORKSPACE_ID"] ?? ""
        let associationWorkspaceId = optionValue(commandArgs, name: "--stable-workspace")
            ?? env["BMUX_STABLE_WORKSPACE_ID"]
            ?? env["CMUX_STABLE_WORKSPACE_ID"]
            ?? workspaceId
        let surfaceId = optionValue(commandArgs, name: "--surface") ?? env["BMUX_SURFACE_ID"]
        let sessionId = optionValue(commandArgs, name: "--session") ?? env["BMUX_CODEX_SESSION_ID"] ?? env["CODEX_SESSION_ID"] ?? env["BMUX_AGENT_SESSION_ID"] ?? ""
        let turnId = optionValue(commandArgs, name: "--turn")
        var transcriptPath = optionValue(commandArgs, name: "--transcript")
        let leasePath = optionValue(commandArgs, name: "--lease")

        guard !workspaceId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !sessionId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        defer { removeCodexMonitorLease(path: leasePath) }
        let cursorDirectory = BmuxStateDirectory.url(
            homeDirectory: FileManager.default.homeDirectoryForCurrentUser
        ).appendingPathComponent("codex-transcript-cursors", isDirectory: true)
        let cursorStore = CLIProvenanceCodexTranscriptCursorStore(directoryURL: cursorDirectory)
        let transcriptTailer = (try? provenanceEngineClient(databasePath: nil).client).map {
            CLIProvenanceCodexTranscriptTailer(
                providerSessionID: sessionId, workspaceID: associationWorkspaceId,
                surfaceID: surfaceId, client: $0, cursorStore: cursorStore
            )
        }
        var lastReportedOffset: UInt64 = 0
        let deadline = Date().addingTimeInterval(4 * 60 * 60)
        var nextOwnerCheck = Date.distantPast
        var publishedUserInputCallIds = Set<String>()
        let hasLease = normalizedHookValue(leasePath) != nil

#if DEBUG
        func logMonitor(_ reason: String, extra: String = "") {
            agentHookDebugLog(
                "codexMonitor.\(reason) session=\(agentHookDebugShort(sessionId)) turn=\(agentHookDebugShort(turnId)) workspace=\(agentHookDebugShort(workspaceId)) associationWorkspace=\(agentHookDebugShort(associationWorkspaceId)) surface=\(agentHookDebugShort(surfaceId)) hasLease=\(hasLease ? 1 : 0) offset=\(lastReportedOffset)\(extra.isEmpty ? "" : " \(extra)")",
                socketPath: client.socketPath,
                env: env
            )
        }

        logMonitor("start", extra: "hasTranscript=\(transcriptPath == nil ? 0 : 1)")
#endif

        func consumeCurrentTranscriptAppend() async -> Bool {
            guard let transcriptTailer, let currentTranscriptPath = transcriptPath else { return false }
            do {
                let url = URL(fileURLWithPath: currentTranscriptPath, isDirectory: false)
                var hasBacklog = false
                for _ in 0..<16 {
                    let outcome = try await transcriptTailer.consume(at: url)
                    let result = outcome.importResult
                    lastReportedOffset = outcome.offset
#if DEBUG
                    if result.consumedLines > 0 || result.skippedLines > 0 ||
                       result.fileReport.eventsAppended > 0 || outcome.cursorWriteFailed {
                        logMonitor(
                            "import",
                            extra: "lines=\(result.consumedLines) skipped=\(result.skippedLines) events=\(result.fileReport.eventsAppended) duplicates=\(result.fileReport.duplicateEvents) partial=\(result.retainedPartialLine ? 1 : 0) cursor=\(outcome.cursorPersisted ? 1 : 0) cursorWriteFailed=\(outcome.cursorWriteFailed ? 1 : 0) unreadBytes=\(outcome.unreadBytes)"
                        )
                    }
#endif
                    hasBacklog = result.hasMoreData
                    guard hasBacklog else { break }
                }
                return hasBacklog
            } catch {
                await transcriptTailer.recordFailure(kind: String(describing: type(of: error)))
#if DEBUG
                logMonitor("importError", extra: "errorType=\(type(of: error))")
#endif
                return false
            }
        }

        func finishCurrentTranscriptImport(flushPendingPrompts: Bool = true) async {
            _ = await consumeCurrentTranscriptAppend()
            guard flushPendingPrompts else { return }
            guard let transcriptTailer, let currentTranscriptPath = transcriptPath else { return }
            do {
                let report = try await transcriptTailer.finish(path: currentTranscriptPath)
#if DEBUG
                logMonitor(
                    "finish",
                    extra: "events=\(report.eventsAppended) duplicates=\(report.duplicateEvents) prompts=\(report.prompts)"
                )
#endif
            } catch {
#if DEBUG
                logMonitor("finishError", extra: "errorType=\(type(of: error))")
#endif
            }
        }

        while Date() < deadline {
            if isCodexMonitorLeaseRetired(path: leasePath) {
#if DEBUG
                logMonitor("exit.leaseRetired")
#endif
                await finishCurrentTranscriptImport(flushPendingPrompts: false)
                return
            }
            let now = Date()
            if now >= nextOwnerCheck {
                nextOwnerCheck = now.addingTimeInterval(Self.codexMonitorOwnerCheckIntervalSeconds)
                if codexMonitorOwnerState(workspaceId: workspaceId, surfaceId: surfaceId, client: client) == .gone {
#if DEBUG
                    logMonitor("exit.ownerGone")
#endif
                    await finishCurrentTranscriptImport()
                    return
                }
            }

            if transcriptPath == nil {
                transcriptPath = findCodexTranscriptPath(sessionId: sessionId, env: env)
#if DEBUG
                if transcriptPath != nil {
                    logMonitor("transcriptResolved")
                }
#endif
            }

            var hasTranscriptBacklog = false
            if let currentTranscriptPath = transcriptPath {
                hasTranscriptBacklog = await consumeCurrentTranscriptAppend()

                if let userInput = readCodexTranscriptUserInput(
                    path: currentTranscriptPath,
                    turnId: turnId,
                    excluding: publishedUserInputCallIds
                ) {
                    publishedUserInputCallIds.insert(userInput.callId)
                    publishCodexMonitorUserInput(
                        userInput,
                        workspaceId: workspaceId,
                        surfaceId: surfaceId,
                        client: client
                    )
                }

                switch readCodexTranscriptFailure(
                    path: currentTranscriptPath,
                    turnId: turnId,
                    requireTerminalCompletion: true
                ) {
                case .failure(let failure):
#if DEBUG
                    logMonitor("exit.failure")
#endif
                    await finishCurrentTranscriptImport()
                    publishCodexMonitorFailure(
                        failure,
                        workspaceId: workspaceId,
                        surfaceId: surfaceId,
                        client: client
                    )
                    return
                case .healthy:
                    guard hasLease else {
#if DEBUG
                        logMonitor("exit.healthyNoLease")
#endif
                        await finishCurrentTranscriptImport()
                        return
                    }
                    break
                case .pending:
                    break
                case .unavailable:
                    let unavailableTranscriptPath = currentTranscriptPath
                    transcriptPath = nil
                    if let resolvedTranscriptPath = findCodexTranscriptPath(sessionId: sessionId, env: env) {
                        transcriptPath = resolvedTranscriptPath
                        if resolvedTranscriptPath != unavailableTranscriptPath {
                            await transcriptTailer?.reset()
                            lastReportedOffset = 0
                            continue
                        }
                    }
                }
            }

            let remaining = deadline.timeIntervalSinceNow
            guard remaining > 0 else {
#if DEBUG
                logMonitor("exit.deadline")
#endif
                await finishCurrentTranscriptImport()
                return
            }
            if hasTranscriptBacklog { continue }
            waitForCodexTranscriptChange(path: transcriptPath, leasePath: leasePath, timeout: min(30, remaining))
        }
#if DEBUG
        logMonitor("exit.loop")
#endif
        await finishCurrentTranscriptImport()
    }

    private func codexMonitorOwnerState(workspaceId: String, surfaceId: String?, client: SocketClient) -> CodexMonitorOwnerState {
        guard client.connectionAppearsOpen() else { return .unknown }
        guard let payload = try? client.sendV2(
            method: "surface.list",
            params: ["workspace_id": workspaceId],
            responseTimeout: Self.codexMonitorOwnerCheckTimeoutSeconds
        ) else {
            return .unknown
        }
        let surfaces = payload["surfaces"] as? [[String: Any]] ?? []
        guard let surfaceId, !surfaceId.isEmpty else { return surfaces.isEmpty ? .gone : .alive }
        let ownerFound = surfaces.contains { surface in
            (surface["id"] as? String) == surfaceId || (surface["ref"] as? String) == surfaceId
        }
        return ownerFound ? .alive : .gone
    }

    private func waitForCodexTranscriptChange(path: String?, leasePath: String?, timeout: TimeInterval) {
        guard timeout > 0 else { return }

        let semaphore = DispatchSemaphore(value: 0)
        var sources: [DispatchSourceFileSystemObject] = []

        func addFileSource(path: String?, eventMask: DispatchSource.FileSystemEvent) {
            guard let path, !path.isEmpty else { return }
            let expandedPath = NSString(string: path).expandingTildeInPath
            let fd = open(expandedPath, O_EVTONLY)
            guard fd >= 0 else { return }
            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fd,
                eventMask: eventMask,
                queue: DispatchQueue.global(qos: .utility)
            )
            source.setEventHandler {
                semaphore.signal()
            }
            source.setCancelHandler {
                close(fd)
            }
            source.resume()
            sources.append(source)
        }

        addFileSource(path: path, eventMask: [.write, .extend, .delete, .rename])
        addFileSource(path: leasePath, eventMask: [.write, .delete, .rename])

        guard !sources.isEmpty else {
            _ = DispatchSemaphore(value: 0).wait(timeout: .now() + timeout)
            return
        }

        _ = semaphore.wait(timeout: .now() + timeout)
        sources.forEach { $0.cancel() }
    }
}
