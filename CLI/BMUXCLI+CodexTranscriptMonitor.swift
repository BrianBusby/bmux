import Darwin
import Foundation
import ProvenanceEngineContracts

extension BMUXCLI {
    private static let codexHookAssociationRetryDeadlineSeconds: TimeInterval = 120
    private static let codexHookAssociationRetryBaseDelaySeconds: TimeInterval = 0.75

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
        let transcriptImporter = (try? provenanceEngineClient(databasePath: nil).client).map(CLIProvenanceCodexTranscriptImporter.init(client:))
        var transcriptImportState = CLIProvenanceCodexTranscriptImporter.LiveImportState(
            workspaceID: associationWorkspaceId,
            surfaceID: surfaceId
        )
        let deadline = Date().addingTimeInterval(4 * 60 * 60)
        var nextOwnerCheck = Date.distantPast
        var publishedUserInputCallIds = Set<String>()
        let hasLease = normalizedHookValue(leasePath) != nil

#if DEBUG
        func logMonitor(_ reason: String, extra: String = "") {
            agentHookDebugLog(
                "codexMonitor.\(reason) session=\(agentHookDebugShort(sessionId)) turn=\(agentHookDebugShort(turnId)) workspace=\(agentHookDebugShort(workspaceId)) associationWorkspace=\(agentHookDebugShort(associationWorkspaceId)) surface=\(agentHookDebugShort(surfaceId)) hasLease=\(hasLease ? 1 : 0) offset=\(transcriptImportState.offset)\(extra.isEmpty ? "" : " \(extra)")",
                socketPath: client.socketPath,
                env: env
            )
        }

        logMonitor("start", extra: "hasTranscript=\(transcriptPath == nil ? 0 : 1)")
#endif

        func consumeCurrentTranscriptAppend() async {
            guard let transcriptImporter, let currentTranscriptPath = transcriptPath else { return }
            do {
                let result = try await transcriptImporter.importLiveTranscriptAppend(
                    at: URL(fileURLWithPath: currentTranscriptPath, isDirectory: false),
                    state: &transcriptImportState
                )
#if DEBUG
                if result.consumedLines > 0 || result.fileReport.eventsAppended > 0 || result.fileReport.duplicateEvents > 0 {
                    logMonitor(
                        "import",
                        extra: "lines=\(result.consumedLines) events=\(result.fileReport.eventsAppended) duplicates=\(result.fileReport.duplicateEvents) commands=\(result.fileReport.commands) reasoning=\(result.fileReport.reasoningSummaries) partial=\(result.retainedPartialLine ? 1 : 0) metadata=\(result.metadataAvailable ? 1 : 0)"
                    )
                }
#endif
            } catch {
#if DEBUG
                logMonitor("importError", extra: "error=\(agentHookDebugShort(String(describing: error)))")
#endif
            }
        }

        func finishCurrentTranscriptImport(flushPendingPrompts: Bool = true) async {
            await consumeCurrentTranscriptAppend()
            guard flushPendingPrompts else { return }
            guard let transcriptImporter, let currentTranscriptPath = transcriptPath else { return }
            do {
                let report = try await transcriptImporter.finishLiveTranscriptImport(
                    state: &transcriptImportState,
                    path: currentTranscriptPath
                )
#if DEBUG
                logMonitor(
                    "finish",
                    extra: "events=\(report.eventsAppended) duplicates=\(report.duplicateEvents) prompts=\(report.prompts)"
                )
#endif
            } catch {
#if DEBUG
                logMonitor("finishError", extra: "error=\(agentHookDebugShort(String(describing: error)))")
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

            if let currentTranscriptPath = transcriptPath {
                await consumeCurrentTranscriptAppend()

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
                            transcriptImportState = CLIProvenanceCodexTranscriptImporter.LiveImportState(
                                workspaceID: associationWorkspaceId,
                                surfaceID: surfaceId
                            )
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
            waitForCodexTranscriptChange(path: transcriptPath, leasePath: leasePath, timeout: min(30, remaining))
        }
#if DEBUG
        logMonitor("exit.loop")
#endif
        await finishCurrentTranscriptImport()
    }

    func recordCodexHookWorkspaceSessionAssociation(
        workspaceId: String,
        surfaceId: String?,
        sessionId: String,
        turnId: String?,
        cwd: String?,
        promptObserved: Bool,
        socketPath: String?,
        env: [String: String]
    ) async {
        let normalizedSessionId = sessionId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedSessionId.isEmpty else { return }
        guard let associationWorkspaceId = normalizedHookValue(env["BMUX_STABLE_WORKSPACE_ID"])
            ?? normalizedHookValue(env["CMUX_STABLE_WORKSPACE_ID"])
            ?? provenanceStableWorkspaceIDForRuntimeWorkspace(
                workspaceId,
                explicitSocketPath: socketPath,
                processEnv: env,
                cliBundleIdentifier: CLISocketPathResolver.currentAppBundleIdentifier()
            ) else {
#if DEBUG
            agentHookDebugLog(
                "codexHookAssociation.skipped session=\(agentHookDebugShort(normalizedSessionId)) workspace=\(agentHookDebugShort(workspaceId)) reason=stable_workspace_unresolved",
                socketPath: socketPath,
                env: env
            )
#endif
            return
        }

        let observedAt = Date()
        let stage = promptObserved
            ? "workspace_session_association_persisted"
            : "agent_detected_awaiting_first_prompt"
        let reasonCode = promptObserved
            ? "hook_prompt_observed"
            : "hook_session_start_observed"

        do {
            let (provenanceClient, _) = try provenanceEngineClient(databasePath: nil)
            let importer = CLIProvenanceCodexTranscriptImporter(client: provenanceClient)
            let gitContext = await importer.gitContext(for: cwd, observedAt: observedAt)
            let trimmedSurfaceId = CLIProvenanceCodexTranscriptImporter.trimmedNonEmpty(surfaceId)
            let trimmedCwd = CLIProvenanceCodexTranscriptImporter.trimmedNonEmpty(cwd)
            let association = ProvenanceWorkspaceCodingAgentSessionAssociationRecord(
                id: importer.stableIDFactory.workspaceCodingAgentSessionAssociationID(
                    workspaceID: associationWorkspaceId,
                    agentKind: "codex",
                    sessionID: normalizedSessionId
                ),
                workspaceID: associationWorkspaceId,
                sessionID: normalizedSessionId,
                agentKind: "codex",
                rawSessionID: normalizedSessionId,
                canonicalSessionID: normalizedSessionId,
                surfaceID: trimmedSurfaceId,
                repositoryID: gitContext?.repositoryID,
                worktreeID: gitContext?.worktreeID,
                currentDirectory: trimmedCwd,
                sourcePath: "hook",
                stage: stage,
                reasonCode: reasonCode,
                retryable: true,
                firstObservedAt: observedAt,
                promptObservedAt: promptObserved ? observedAt : nil,
                lastObservedAt: observedAt,
                lastTransitionAt: observedAt
            )
            let session = ProvenanceSessionRecord(
                id: normalizedSessionId,
                agentKind: "codex",
                workspaceID: associationWorkspaceId,
                surfaceID: trimmedSurfaceId,
                worktreeID: gitContext?.worktreeID,
                cwd: trimmedCwd,
                status: "active",
                startedAt: observedAt,
                updatedAt: observedAt
            )
            let identity = ProvenanceExternalIdentityRecord(
                id: importer.stableIDFactory.id(
                    prefix: "identity",
                    value: "\(normalizedSessionId)\ncodex\nhook_session\n\(normalizedSessionId)"
                ),
                sessionID: normalizedSessionId,
                system: "codex",
                kind: "hook_session",
                externalID: normalizedSessionId,
                source: .observed,
                confidence: .high,
                createdAt: observedAt,
                updatedAt: observedAt
            )
            let eventDiscriminator = [
                "codex-hook-workspace-session-association",
                associationWorkspaceId.lowercased(),
                normalizedSessionId,
                normalizedHookValue(turnId) ?? "session",
                stage,
            ].joined(separator: "\n")
            let event = ProvenanceEvent(
                id: importer.stableIDFactory.id(prefix: "event", value: eventDiscriminator),
                eventType: promptObserved ? .codingAgentPromptSubmitted : .codingAgentThreadObserved,
                timestamp: observedAt,
                repositoryID: gitContext?.repositoryID,
                worktreeID: gitContext?.worktreeID,
                sessionID: normalizedSessionId,
                source: .observed,
                evidenceOrigin: ProvenanceEvidenceOrigin(rawValue: "codex-hook"),
                evidenceScope: CLIProvenanceCodexTranscriptImporter.localEvidenceScope,
                confidence: .high,
                payload: ProvenanceEventPayload(
                    repository: gitContext?.repository,
                    worktree: gitContext?.worktree,
                    session: session,
                    externalIdentities: [identity],
                    workspaceCodingAgentSessionAssociation: association
                )
            )
            try await appendCodexHookWorkspaceSessionAssociation(
                event,
                client: provenanceClient,
                socketPath: socketPath,
                env: env
            )
#if DEBUG
            agentHookDebugLog(
                "codexHookAssociation.persisted session=\(agentHookDebugShort(normalizedSessionId)) workspace=\(agentHookDebugShort(associationWorkspaceId)) surface=\(agentHookDebugShort(trimmedSurfaceId)) stage=\(stage) reason=\(reasonCode)",
                socketPath: socketPath,
                env: env
            )
#endif
        } catch {
#if DEBUG
            agentHookDebugLog(
                "codexHookAssociation.error session=\(agentHookDebugShort(normalizedSessionId)) workspace=\(agentHookDebugShort(associationWorkspaceId)) error=\(agentHookDebugShort(String(describing: error)))",
                socketPath: socketPath,
                env: env
            )
#endif
        }
    }

    func recordCodexHookSessionStartAssociation(
        workspaceId: String,
        surfaceId: String?,
        sessionId: String,
        turnId: String?,
        cwd: String?,
        socketPath: String?,
        env: [String: String]
    ) async {
        await recordCodexHookWorkspaceSessionAssociation(
            workspaceId: workspaceId,
            surfaceId: surfaceId,
            sessionId: sessionId,
            turnId: turnId,
            cwd: cwd,
            promptObserved: false,
            socketPath: socketPath,
            env: env
        )
    }

    func recordCodexHookPromptSubmitAssociation(
        workspaceId: String,
        surfaceId: String?,
        sessionId: String,
        turnId: String?,
        cwd: String?,
        socketPath: String?,
        env: [String: String]
    ) async {
        await recordCodexHookWorkspaceSessionAssociation(
            workspaceId: workspaceId,
            surfaceId: surfaceId,
            sessionId: sessionId,
            turnId: turnId,
            cwd: cwd,
            promptObserved: true,
            socketPath: socketPath,
            env: env
        )
    }

    private func appendCodexHookWorkspaceSessionAssociation(
        _ event: ProvenanceEvent,
        client: any ProvenanceEngineContracts.ProvenanceEngineClient,
        socketPath: String?,
        env: [String: String]
    ) async throws {
        var attempts = 0
        let deadline = Date().addingTimeInterval(Self.codexHookAssociationRetryDeadlineSeconds)
        while true {
            do {
                _ = try await client.appendEvent(ProvenanceEngineContracts.ProvenanceAppendEventRequest(event: event))
                return
            } catch {
                if CLIProvenanceCodexTranscriptImporter.isDuplicateAppendError(error) {
                    return
                }
                attempts += 1
                let remaining = deadline.timeIntervalSinceNow
                guard remaining > 0, isRetryableCodexHookAssociationSQLiteError(error) else {
                    throw error
                }
                let boundedError = boundedCodexHookAssociationErrorDescription(error)
#if DEBUG
                agentHookDebugLog(
                    "codexHookAssociation.retry session=\(agentHookDebugShort(event.sessionID)) attempt=\(attempts) remaining=\(Int(remaining.rounded(.down))) error=\(boundedError)",
                    socketPath: socketPath,
                    env: env
                )
#endif
                // Bounded retry covers transient SQLite writer contention in the detached hook worker.
                let delay = min(
                    remaining,
                    Self.codexHookAssociationRetryBaseDelaySeconds * Double(min(attempts, 8))
                )
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
    }

    private func boundedCodexHookAssociationErrorDescription(_ error: Error) -> String {
        let description = String(describing: error)
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
        return String(description.prefix(160))
    }

    private func isRetryableCodexHookAssociationSQLiteError(_ error: Error) -> Bool {
        let description = String(describing: error).lowercased()
        return description.contains("database is locked")
            || description.contains("database is busy")
            || description.contains("busy")
            || description.contains("locked")
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
