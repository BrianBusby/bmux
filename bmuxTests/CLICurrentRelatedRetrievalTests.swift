import Darwin
import Foundation
import ProvenanceEngineContracts
import ProvenanceEngineSDK
import Testing

@Suite(.serialized)
struct CLICurrentRelatedRetrievalTests {
    @Test func codexWrapperProvidesBoundedCrossSessionGuidance() throws {
        let cliPath = try BundledCLITestSupport.bundledCLIPath(for: BundledCLILinkageTests.self)
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("bmux-codex-guidance-\(UUID().uuidString)", isDirectory: true)
        let codexHome = root.appendingPathComponent(".codex", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let environment = codexHookTestEnvironment(root: root, codexHome: codexHome)
        let injection = runCodexHookProcess(executablePath: cliPath, arguments: ["hooks", "codex", "inject-args"],
            environment: environment, timeout: 10)
        #expect(injection.status == 0, Comment(rawValue: injection.stderr))
        let args = injection.stdout.split(separator: "\0").map(String.init)
        let sessionHooks = try #require(args.first { $0.hasPrefix("hooks.SessionStart=") })
        #expect(sessionHooks.contains("bmux-codex-hook-context-guidance.sh"))
        #expect(sessionHooks.contains("bmux-codex-hook-session-start.sh"))
        let script = root.appendingPathComponent(".bmux/hooks/bmux-codex-hook-context-guidance.sh")
        let result = runCodexHookProcess(executablePath: script.path, arguments: [], environment: environment, timeout: 5)
        let output = try #require(codexHookJSONObject(result.stdout))
        let hook = try #require(output["hookSpecificOutput"] as? [String: Any])
        let context = try #require(hook["additionalContext"] as? String)
        #expect(hook["hookEventName"] as? String == "SessionStart")
        #expect(context.utf8.count < 1_024)
        #expect(context.contains("provenance sessions related --current"))
        #expect(context.contains("provenance session outcome"))
        var disabled = environment
        disabled["BMUX_CODEX_HOOKS_DISABLED"] = "1"
        let disabledResult = runCodexHookProcess(executablePath: script.path, arguments: [], environment: disabled, timeout: 5)
        #expect(codexHookJSONObject(disabledResult.stdout)?.isEmpty == true)
    }

    @Test func currentRelatedUsesCallerSurfaceAndPublicEvidence() async throws {
        let cliPath = try BundledCLITestSupport.bundledCLIPath(for: BundledCLILinkageTests.self)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("bmux-current-related-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let socketPath = makeCodexHookSocketPath("related-current")
        let listener = try bindCodexHookUnixSocket(at: socketPath)
        defer {
            Darwin.close(listener)
            unlink(socketPath)
            try? FileManager.default.removeItem(at: root)
        }
        let workspace = "11111111-1111-1111-1111-111111111111"
        let stable = "33333333-3333-3333-3333-333333333333"
        let surface = "22222222-2222-2222-2222-222222222222"
        let sessionID = "current-provider-session"
        let commands = CodexHookCapturedSocketCommands()
        startCodexHookMockSocketServerAccepting(listenerFD: listener, commands: commands, surfaceId: surface,
            connectionLimit: 16, runtimeWorkspaceId: workspace, stableWorkspaceId: stable)
        let database = root.appendingPathComponent("provenance.sqlite")
        let client = try ProvenanceEngineClientFactory().sqliteClient(databaseURL: database)
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let repository = ProvenanceRepositoryRecord(id: "repo", path: "/repos/roof", remoteSlug: "team/roof", createdAt: now, updatedAt: now)
        let worktree = ProvenanceWorktreeRecord(id: "worktree", repositoryID: repository.id,
            path: "/repos/roof", branch: "main", currentHEAD: "head", isDirty: false, status: "active", updatedAt: now)
        _ = try await client.appendEvent(.init(event: ProvenanceEvent(id: "worktree-event", eventType: .worktreeObserved,
            timestamp: now, repositoryID: repository.id, worktreeID: worktree.id, source: .observed, confidence: .high,
            payload: .init(repository: repository, worktree: worktree))))
        for (id, status) in [(sessionID, "active"), ("related-active", "active"), ("related-closed", "completed")] {
            let session = ProvenanceSessionRecord(id: id, agentKind: "codex", workspaceID: "workspace-\(id)", worktreeID: worktree.id,
                status: status, startedAt: now, updatedAt: now)
            let association: ProvenanceWorkspaceCodingAgentSessionAssociationRecord? = id == sessionID
                ? .init(id: "association", workspaceID: stable, sessionID: id, agentKind: "codex", rawSessionID: id,
                        surfaceID: surface, sourcePath: "hook", stage: "linked", firstObservedAt: now,
                        lastObservedAt: now, lastTransitionAt: now) : nil
            _ = try await client.appendEvent(.init(event: ProvenanceEvent(id: "event-\(id)", eventType: .sessionObserved,
                timestamp: now, worktreeID: worktree.id, sessionID: id, source: .observed, confidence: .high,
                payload: .init(session: session, workspaceCodingAgentSessionAssociation: association))))
        }
        let thread = ProvenanceCodingAgentThreadRecord(id: "closed-thread", sessionID: "related-closed",
            provider: "codex", providerThreadID: "closed-provider", worktreeID: worktree.id,
            source: .observed, confidence: .high, firstObservedAt: now, updatedAt: now)
        let turn = ProvenanceCodingAgentTurnRecord(id: "closed-turn", sessionID: "related-closed", threadID: thread.id,
            provider: "codex", providerTurnID: "closed-turn-provider", status: "completed", model: nil, effort: nil,
            startedAt: now, completedAt: now, updatedAt: now, source: .observed, confidence: .high)
        let failed = ProvenanceCodingAgentCommandRecord(id: "closed-command", sessionID: "related-closed",
            threadID: thread.id, turnID: turn.id, provider: "codex", operationID: "validation-operation",
            command: "swift test --filter Roofing", cwd: worktree.path, status: "failed", exitCode: 1,
            outputSummary: "Fixture database unavailable", startedAt: now, completedAt: now,
            source: .observed, confidence: .high)
        _ = try await client.appendEvent(.init(event: ProvenanceEvent(id: "closed-turn-event", eventType: .codingAgentTurnObserved,
            timestamp: now, worktreeID: worktree.id, sessionID: "related-closed", source: .observed, confidence: .high,
            payload: .init(codingAgentThread: thread, codingAgentTurn: turn))))
        _ = try await client.appendEvent(.init(event: ProvenanceEvent(id: "closed-command-event", eventType: .codingAgentCommandCompleted,
            timestamp: now, worktreeID: worktree.id, sessionID: "related-closed", source: .observed, confidence: .high,
            payload: .init(codingAgentCommand: failed))))
        let prompt = ProvenanceCodingAgentPromptRecord(id: "closed-prompt", sessionID: "related-closed",
            threadID: thread.id, turnID: turn.id, provider: "codex", text: "Repair roof flashing",
            submittedAt: now, source: .observed, confidence: .high)
        let files = ProvenanceCodingAgentFileChangeAttributionRecord(id: "closed-files", sessionID: "related-closed",
            threadID: thread.id, turnID: turn.id, provider: "codex", operationID: "file-operation",
            changeSetID: nil, fileChangeIDs: [], paths: ["Sources/Flashing.swift"], summary: nil,
            observedAt: now, source: .inferred, confidence: .low)
        let display = ProvenanceWorkspaceDisplayRecord(id: "closed-display", workspaceID: "workspace-related-closed",
            repositoryID: repository.id, ticketIDs: ["ROOF-42"], observedAt: now, updatedAt: now)
        for (id, type, payload) in [
            ("closed-prompt-event", ProvenanceEventType.codingAgentPromptSubmitted, ProvenanceEventPayload(codingAgentPrompt: prompt)),
            ("closed-files-event", ProvenanceEventType.codingAgentFileChangeAttributed, ProvenanceEventPayload(codingAgentFileChangeAttribution: files)),
            ("closed-display-event", ProvenanceEventType.workspaceDisplayObserved, ProvenanceEventPayload(workspaceDisplay: display)),
        ] {
            _ = try await client.appendEvent(.init(event: ProvenanceEvent(id: id, eventType: type,
                timestamp: now, repositoryID: repository.id, worktreeID: worktree.id, sessionID: "related-closed",
                source: id == "closed-files-event" ? .inferred : .observed,
                confidence: id == "closed-files-event" ? .low : .high, payload: payload)))
        }
        for (id, text, offset) in [
            ("closed-blocker-open", "Blocker: activity=run package suite; condition=database offline", 1.0),
            ("closed-blocker-resolved", "Blocker resolved: activity=run package suite; condition=database offline; outcome=bypassed", 2.0),
        ] {
            let message = ProvenanceCodingAgentAssistantMessageRecord(id: id, sessionID: "related-closed",
                threadID: thread.id, turnID: turn.id, provider: "codex", itemID: "item-\(id)", text: text,
                completedAt: now.addingTimeInterval(offset), source: .observed, confidence: .high)
            _ = try await client.appendEvent(.init(event: ProvenanceEvent(id: "event-\(id)",
                eventType: .codingAgentAssistantMessageCompleted, timestamp: message.completedAt,
                repositoryID: repository.id, worktreeID: worktree.id, sessionID: "related-closed",
                source: .observed, confidence: .high, payload: .init(codingAgentAssistantMessage: message))))
        }
        _ = try await client.publishCodingAgentSessionSemanticInferences(.init(
            sessionID: "related-closed", createdAt: now.addingTimeInterval(3)))
        let activeThread = ProvenanceCodingAgentThreadRecord(id: "active-thread", sessionID: "related-active",
            provider: "codex", providerThreadID: "active-provider", worktreeID: worktree.id,
            source: .observed, confidence: .high, firstObservedAt: now, updatedAt: now)
        let activeTurn = ProvenanceCodingAgentTurnRecord(id: "active-turn", sessionID: "related-active", threadID: activeThread.id,
            provider: "codex", providerTurnID: "active-turn-provider", status: "completed", model: nil, effort: nil,
            startedAt: now, completedAt: now, updatedAt: now, source: .observed, confidence: .high)
        let activeFile = ProvenanceCodingAgentFileChangeAttributionRecord(id: "active-file", sessionID: "related-active",
            threadID: activeThread.id, turnID: activeTurn.id, provider: "codex", operationID: "active-file-operation",
            paths: ["Sources/Flashing.swift"], observedAt: now, source: .observed, confidence: .high)
        let activePrompt = ProvenanceCodingAgentPromptRecord(id: "active-prompt", sessionID: "related-active",
            threadID: activeThread.id, turnID: activeTurn.id, provider: "codex",
            text: String(repeating: "Inspect flashing and source evidence. ", count: 10),
            submittedAt: now, source: .observed, confidence: .high)
        let activeMessage = ProvenanceCodingAgentAssistantMessageRecord(id: "active-message", sessionID: "related-active",
            threadID: activeThread.id, turnID: activeTurn.id, provider: "codex", itemID: "active-message-item",
            text: "Blocker: activity=run package suite; condition=database offline", completedAt: now,
            source: .observed, confidence: .high)
        for (id, type, payload) in [
            ("active-turn-event", ProvenanceEventType.codingAgentTurnObserved, ProvenanceEventPayload(codingAgentThread: activeThread, codingAgentTurn: activeTurn)),
            ("active-file-event", ProvenanceEventType.codingAgentFileChangeAttributed, ProvenanceEventPayload(codingAgentFileChangeAttribution: activeFile)),
            ("active-prompt-event", ProvenanceEventType.codingAgentPromptSubmitted, ProvenanceEventPayload(codingAgentPrompt: activePrompt)),
            ("active-message-event", ProvenanceEventType.codingAgentAssistantMessageCompleted, ProvenanceEventPayload(codingAgentAssistantMessage: activeMessage)),
        ] {
            _ = try await client.appendEvent(.init(event: ProvenanceEvent(id: id, eventType: type,
                timestamp: now, repositoryID: repository.id, worktreeID: worktree.id, sessionID: "related-active",
                source: .observed, confidence: .high, payload: payload)))
        }
        _ = try await client.publishCodingAgentSessionSemanticInferences(.init(
            sessionID: "related-active", createdAt: now.addingTimeInterval(3)))
        var hookState: [String: Any] = [
            "version": 1,
            "activeSessionsBySurface": [:],
            "sessions": [sessionID: ["sessionId": sessionID, "workspaceId": workspace, "surfaceId": surface,
                                     "pid": Int(getpid()), "startedAt": now.timeIntervalSince1970, "updatedAt": now.timeIntervalSince1970]]
        ]
        let hookData = try JSONSerialization.data(withJSONObject: hookState)
        try hookData.write(to: root.appendingPathComponent("codex-hook-sessions.json"))
        let environment = ["HOME": root.path, "BMUX_PROVENANCE_HOME": root.path,
            "PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "BMUX_SOCKET_PATH": socketPath,
            "BMUX_WORKSPACE_ID": workspace, "BMUX_SURFACE_ID": surface,
            "BMUX_AGENT_HOOK_STATE_DIR": root.path, "BMUX_CLI_SENTRY_DISABLED": "1",
            "BMUX_SOCKET_PASSWORD": "fixture-password", "CODEX_THREAD_ID": sessionID]
        let result = runCodexHookProcess(executablePath: cliPath,
            arguments: ["--json", "provenance", "sessions", "related", "--current", "--database", database.path],
            environment: environment, timeout: 15)
        #expect(!result.timedOut, Comment(rawValue: result.stderr))
        #expect(result.status == 0, Comment(rawValue: result.stderr))
        let payload = try #require(try JSONSerialization.jsonObject(with: Data(result.stdout.utf8)) as? [String: Any])
        let results = try #require(payload["results"] as? [[String: Any]])
        #expect(Set(results.compactMap { $0["session_id"] as? String }) == ["related-active", "related-closed"])
        #expect(payload["target_session_id"] as? String == sessionID)
        #expect(result.stdout.utf8.count <= 16 * 1024)
        for (option, value, reason) in [
            ("--artifact-path", "Sources/Flashing.swift", "requested_artifact"),
            ("--ticket", "ROOF-42", "current_workspace_ticket"),
            ("--objective", "repair roof", "objective_text_match"),
        ] {
            let selected = runCodexHookProcess(executablePath: cliPath,
                arguments: ["--json", "provenance", "sessions", "related", "--current", option, value,
                            "--database", database.path], environment: environment, timeout: 15)
            #expect(selected.status == 0, Comment(rawValue: selected.stderr))
            let selectedPayload = try #require(try JSONSerialization.jsonObject(with: Data(selected.stdout.utf8)) as? [String: Any])
            let selectedResults = try #require(selectedPayload["results"] as? [[String: Any]])
            let expected: Set<String> = option == "--artifact-path" ? ["related-active", "related-closed"] : ["related-closed"]
            #expect(Set(selectedResults.compactMap { $0["session_id"] as? String }) == expected)
            #expect(selectedPayload["briefs_omitted_for_budget"] as? Int == 0)
            let matches = try #require(selectedResults.first?["match_evidence"] as? [[String: Any]])
            #expect(matches.contains { ($0["kind"] as? String) == reason && !($0["evidence"] as? [[String: Any]] ?? []).isEmpty })
            let matched = try #require(matches.first { $0["kind"] as? String == reason })
            let observedAt = try #require(matched["observed_at"] as? Double)
            #expect((now.timeIntervalSince1970...now.addingTimeInterval(3).timeIntervalSince1970).contains(observedAt))
            #expect(selected.stdout.utf8.count <= 12 * 1024 + 1)
            if option == "--artifact-path" {
                let closed = try #require(selectedResults.first { $0["session_id"] as? String == "related-closed" })
                let reasons = try #require(closed["match_evidence"] as? [[String: Any]])
                let pathMatch = try #require(reasons.first { $0["kind"] as? String == "requested_artifact" })
                let references = try #require(pathMatch["evidence"] as? [[String: Any]])
                #expect(references.contains { $0["id"] as? String == "closed-files-event" && $0["source"] as? String == "inferred" })
            }
            if option == "--objective" {
                let fields = try #require(selectedResults.first?["semantic_fields"] as? [[String: Any]])
                let blockers = try #require(fields.first { $0["kind"] as? String == "coding_agent.blockers" })
                let items = try #require(blockers["blocker_items"] as? [[String: Any]])
                #expect(items.first?["state"] as? String == "reported_bypassed")
                let refs = try #require(items.first?["source_evidence"] as? [[String: Any]])
                #expect(refs.compactMap { $0["id"] as? String } == ["closed-blocker-open", "closed-blocker-resolved"])
            }
        }
        // A retained PID that is not an ancestor cannot establish ownership.
        var unknownOwnerState = hookState
        var unknownSessions = try #require(unknownOwnerState["sessions"] as? [String: Any])
        var unknownRecord = try #require(unknownSessions[sessionID] as? [String: Any])
        unknownRecord["pid"] = 999_999_999
        unknownSessions[sessionID] = unknownRecord
        unknownOwnerState["sessions"] = unknownSessions
        try JSONSerialization.data(withJSONObject: unknownOwnerState).write(to: root.appendingPathComponent("codex-hook-sessions.json"), options: .atomic)
        let unknownOwner = runCodexHookProcess(executablePath: cliPath,
            arguments: ["--json", "provenance", "sessions", "related", "--current", "--database", database.path],
            environment: environment, timeout: 15)
        let unknownPayload = try #require(try JSONSerialization.jsonObject(with: Data(unknownOwner.stdout.utf8)) as? [String: Any])
        #expect(unknownPayload["reason"] as? String == "caller_ownership_unavailable")
        try JSONSerialization.data(withJSONObject: hookState).write(to: root.appendingPathComponent("codex-hook-sessions.json"), options: .atomic)

        // Model the shared daemon as an actual parent process, retaining one hook record.
        let daemon = runCodexHookProcess(executablePath: "/bin/bash",
            arguments: ["-c", "shift 2; \"$@\"; result=$?; exit $result", "codex", "app-server", "--managed-daemon",
                        cliPath, "--json", "provenance", "sessions", "related", "--current", "--database", database.path],
            environment: environment, timeout: 15)
        #expect(!daemon.timedOut && daemon.status == 0, Comment(rawValue: daemon.stderr))
        let daemonPayload = try #require(try JSONSerialization.jsonObject(with: Data(daemon.stdout.utf8)) as? [String: Any])
        #expect(daemonPayload["found"] as? Bool == false)
        #expect(daemonPayload["reason"] as? String == "caller_ownership_unavailable")
        #expect(daemonPayload["recovery"] as? String == "use_independent_codex_session")
        let textResult = runCodexHookProcess(executablePath: cliPath,
            arguments: ["provenance", "sessions", "related", "--current", "--database", database.path],
            environment: environment, timeout: 15)
        #expect(!textResult.timedOut && textResult.status == 0)
        #expect(textResult.stdout.utf8.count <= 16 * 1024)
        #expect(textResult.stdout.contains("related-active") && textResult.stdout.contains("related-closed"))
        #expect(textResult.stdout.contains("swift test --filter Roofing"))
        #expect(results.allSatisfy { !($0["evidence"] as? [[String: Any]] ?? []).isEmpty })
        let closed = try #require(results.first { $0["session_id"] as? String == "related-closed" })
        let freshness = try #require(closed["freshness"] as? [String: Any])
        #expect(freshness["recency"] as? String == "stale")
        let validations = try #require(closed["validations"] as? [[String: Any]])
        #expect(validations.contains { $0["command"] as? String == "swift test --filter Roofing" && $0["result"] as? String == "failed" })
        let closedRevision = try #require(closed["outcome_revision"] as? String)
        let drillDown = runCodexHookProcess(executablePath: cliPath,
            arguments: ["provenance", "session", "outcome", "related-closed", "--revision", closedRevision, "--database", database.path],
            environment: environment, timeout: 15)
        #expect(!drillDown.timedOut)
        #expect(drillDown.status == 0, Comment(rawValue: drillDown.stderr))
        #expect(drillDown.stdout.contains("Session outcome for related-closed"))
        let requests = commands.snapshot().compactMap(codexHookJSONObject)
        #expect(requests.contains { ($0["method"] as? String) == "system.identify" })
        #expect(requests.contains { ($0["method"] as? String) == "workspace.list" &&
            (($0["params"] as? [String: Any])?["window_id"] as? String) == "44444444-4444-4444-4444-444444444444" })

        let secondSurface = "55555555-5555-5555-5555-555555555555"
        let secondSession = "second-provider-session"
        let secondSocket = makeCodexHookSocketPath("related-second")
        let secondListener = try bindCodexHookUnixSocket(at: secondSocket)
        defer { Darwin.close(secondListener); unlink(secondSocket) }
        startCodexHookMockSocketServerAccepting(listenerFD: secondListener, commands: commands, surfaceId: secondSurface,
            connectionLimit: 8, runtimeWorkspaceId: workspace, stableWorkspaceId: stable)
        let secondRecord = ProvenanceSessionRecord(id: secondSession, agentKind: "codex", worktreeID: worktree.id,
            status: "active", startedAt: now, updatedAt: now)
        let secondAssociation = ProvenanceWorkspaceCodingAgentSessionAssociationRecord(
            id: "second-association", workspaceID: stable, sessionID: secondSession, agentKind: "codex",
            rawSessionID: secondSession, surfaceID: secondSurface, sourcePath: "hook", stage: "linked",
            firstObservedAt: now, lastObservedAt: now, lastTransitionAt: now)
        _ = try await client.appendEvent(.init(event: ProvenanceEvent(id: "second-event", eventType: .sessionObserved,
            timestamp: now, worktreeID: worktree.id, sessionID: secondSession, source: .observed, confidence: .high,
            payload: .init(session: secondRecord, workspaceCodingAgentSessionAssociation: secondAssociation))))
        var active = try #require(hookState["activeSessionsBySurface"] as? [String: Any])
        active[secondSurface] = ["sessionId": secondSession, "updatedAt": now.timeIntervalSince1970]
        hookState["activeSessionsBySurface"] = active
        var sessions = try #require(hookState["sessions"] as? [String: Any])
        sessions[secondSession] = ["sessionId": secondSession, "workspaceId": workspace, "surfaceId": secondSurface,
                                   "pid": Int(getpid()), "startedAt": now.timeIntervalSince1970, "updatedAt": now.timeIntervalSince1970]
        hookState["sessions"] = sessions
        try JSONSerialization.data(withJSONObject: hookState).write(to: root.appendingPathComponent("codex-hook-sessions.json"), options: .atomic)
        var secondEnvironment = environment
        secondEnvironment["BMUX_SOCKET_PATH"] = secondSocket
        secondEnvironment["BMUX_SURFACE_ID"] = secondSurface
        secondEnvironment["CODEX_THREAD_ID"] = secondSession
        let second = runCodexHookProcess(executablePath: cliPath,
            arguments: ["--json", "provenance", "sessions", "related", "--current", "--database", database.path],
            environment: secondEnvironment, timeout: 15)
        let secondPayload = try #require(try JSONSerialization.jsonObject(with: Data(second.stdout.utf8)) as? [String: Any])
        #expect(secondPayload["target_session_id"] as? String == secondSession)
        let secondResults = try #require(secondPayload["results"] as? [[String: Any]])
        #expect(secondResults.contains { $0["session_id"] as? String == sessionID })

        var replacedEnvironment = environment
        replacedEnvironment["CODEX_THREAD_ID"] = "different-provider-session"
        let replaced = runCodexHookProcess(executablePath: cliPath,
            arguments: ["--json", "provenance", "sessions", "related", "--current", "--database", database.path],
            environment: replacedEnvironment, timeout: 15)
        let replacedPayload = try #require(try JSONSerialization.jsonObject(with: Data(replaced.stdout.utf8)) as? [String: Any])
        #expect(replacedPayload["reason"] as? String == "caller_unlinked")
        #expect(replacedPayload["found"] as? Bool == false)

        var noSocketEnvironment = environment
        noSocketEnvironment["BMUX_SOCKET_PATH"] = root.appendingPathComponent("missing.sock").path
        let unavailable = runCodexHookProcess(executablePath: cliPath,
            arguments: ["--json", "provenance", "sessions", "related", "--current", "--database", database.path],
            environment: noSocketEnvironment, timeout: 15)
        let unavailablePayload = try #require(try JSONSerialization.jsonObject(with: Data(unavailable.stdout.utf8)) as? [String: Any])
        #expect(unavailablePayload["reason"] as? String == "app_linkage_unavailable")
        #expect(unavailablePayload["recovery"] as? String == "check_app_and_socket_access")
        #expect(unavailablePayload["recovery_steps"] as? [String] == [
            "verify_app_running", "verify_socket_path", "allow_sandbox_socket_access_or_retry_outside_sandbox"
        ])
        let unavailableText = runCodexHookProcess(executablePath: cliPath,
            arguments: ["provenance", "sessions", "related", "--current", "--database", database.path],
            environment: noSocketEnvironment, timeout: 15)
        #expect(unavailableText.stdout.contains("socket"))
        #expect(unavailableText.stdout.contains("sandbox"))

        let explicit = runCodexHookProcess(executablePath: cliPath,
            arguments: ["provenance", "sessions", "related", sessionID, "--limit", "1", "--database", database.path],
            environment: noSocketEnvironment, timeout: 15)
        #expect(!explicit.timedOut)
        #expect(explicit.status == 0, Comment(rawValue: explicit.stderr))
        #expect(explicit.stdout.contains("Related sessions for \(sessionID)"))

        for index in 0..<5 {
            let id = "oversized-\(index)-" + String(repeating: "x", count: 3_500)
            let longSession = ProvenanceSessionRecord(id: id, agentKind: "codex", worktreeID: worktree.id,
                status: "active", startedAt: now, updatedAt: now.addingTimeInterval(100))
            _ = try await client.appendEvent(.init(event: ProvenanceEvent(id: "event-\(id)", eventType: .sessionObserved,
                timestamp: longSession.updatedAt, worktreeID: worktree.id, sessionID: id, source: .observed,
                confidence: .high, payload: .init(session: longSession))))
        }
        let emptyDatabase = runCodexHookProcess(executablePath: cliPath,
            arguments: ["provenance", "sessions", "related", "--current", "--database", "  "],
            environment: environment, timeout: 15)
        #expect(emptyDatabase.status != 0)
        #expect(emptyDatabase.stderr.contains("--database"))
        let boundedArguments = ["--json", "provenance", "sessions", "related", "--current", "--database", database.path]
        let bounded = runCodexHookProcess(executablePath: cliPath, arguments: boundedArguments, environment: environment, timeout: 15)
        let repeated = runCodexHookProcess(executablePath: cliPath, arguments: boundedArguments, environment: environment, timeout: 15)
        #expect(!bounded.timedOut && !repeated.timedOut)
        #expect(bounded.status == 0 && repeated.status == 0)
        #expect(bounded.stdout.utf8.count <= 12 * 1024 + 1)
        #expect(bounded.stdout == repeated.stdout)
        let boundedPayload = try #require(try JSONSerialization.jsonObject(with: Data(bounded.stdout.utf8)) as? [String: Any])
        #expect((boundedPayload["briefs_omitted_for_budget"] as? Int ?? 0) > 0)
    }

}
