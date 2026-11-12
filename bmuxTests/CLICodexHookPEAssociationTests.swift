import Darwin
import Foundation
import ProvenanceEngineContracts
import ProvenanceEngineSDK
import Testing

@Suite(.serialized)
struct CLICodexHookPEAssociationTests {
    @Test func codexPromptSubmitPersistsStableWorkspaceAssociationBeforeTranscriptImport() async throws {
        let cliPath = try BundledCLITestSupport.bundledCLIPath(for: BundledCLILinkageTests.self)
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("bmux-codex-hook-pe-association-\(UUID().uuidString)", isDirectory: true)
        let socketPath = makeCodexHookSocketPath("codex-pe")
        let listenerFD = try bindCodexHookUnixSocket(at: socketPath)
        let commands = CodexHookCapturedSocketCommands()
        let runtimeWorkspaceId = "11111111-1111-1111-1111-111111111111"
        let stableWorkspaceId = "33333333-3333-3333-3333-333333333333"
        let surfaceId = "22222222-2222-2222-2222-222222222222"
        let sessionId = "codex-hook-pe-association-session"
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer {
            Darwin.close(listenerFD)
            unlink(socketPath)
            try? FileManager.default.removeItem(at: root)
        }
        startCodexHookMockSocketServerAccepting(
            listenerFD: listenerFD,
            commands: commands,
            surfaceId: surfaceId,
            connectionLimit: 16
        )

        let result = runCodexHookProcess(
            executablePath: cliPath,
            arguments: ["hooks", "codex", "prompt-submit"],
            environment: [
                "HOME": root.path,
                "CFFIXED_USER_HOME": root.path,
                "BMUX_PROVENANCE_HOME": root.path,
                "PATH": "/usr/bin:/bin:/usr/sbin:/sbin",
                "PWD": root.path,
                "BMUX_SOCKET_PATH": socketPath,
                "BMUX_WORKSPACE_ID": runtimeWorkspaceId,
                "BMUX_STABLE_WORKSPACE_ID": stableWorkspaceId,
                "BMUX_SURFACE_ID": surfaceId,
                "BMUX_AGENT_HOOK_STATE_DIR": root.path,
                "BMUX_CLI_SENTRY_DISABLED": "1",
                "BMUX_CODEX_PID": "4242",
            ],
            standardInput: #"{"session_id":"\#(sessionId)","turn_id":"turn-hook-1","cwd":"\#(root.path)","hook_event_name":"UserPromptSubmit"}"#,
            timeout: 5
        )

        #expect(!result.timedOut, Comment(rawValue: result.stderr))
        #expect(result.status == 0, Comment(rawValue: result.stderr))
        #expect(result.stdout == "{}\n")

        let response = try await peAssociationResponse(root: root, stableWorkspaceId: stableWorkspaceId)
        let association = try #require(response.association)
        #expect(response.found)
        #expect(response.readiness.status == .associationEstablishedProjectionPending)
        #expect(association.workspaceID == stableWorkspaceId)
        #expect(association.sessionID == sessionId)
        #expect(association.canonicalSessionID == sessionId)
        #expect(association.rawSessionID == sessionId)
        #expect(association.surfaceID == surfaceId)
        #expect(association.sourcePath == "hook")
        #expect(association.stage == "workspace_session_association_persisted")
        #expect(association.reasonCode == "hook_prompt_observed")
        #expect(association.promptObservedAt != nil)
    }

    @Test func unattestedCodexHookKeepsLifecycleButDoesNotBindProvenance() async throws {
        let cliPath = try BundledCLITestSupport.bundledCLIPath(for: BundledCLILinkageTests.self)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("bmux-unattested-hook-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let socketPath = makeCodexHookSocketPath("unattested-pe")
        let listener = try bindCodexHookUnixSocket(at: socketPath)
        defer { Darwin.close(listener); unlink(socketPath); try? FileManager.default.removeItem(at: root) }
        let workspace = "11111111-1111-1111-1111-111111111111"
        let stable = "33333333-3333-3333-3333-333333333333"
        let surface = "22222222-2222-2222-2222-222222222222"
        let commands = CodexHookCapturedSocketCommands()
        startCodexHookMockSocketServerAccepting(listenerFD: listener, commands: commands, surfaceId: surface,
            connectionLimit: 16, runtimeWorkspaceId: workspace, stableWorkspaceId: stable)
        let environment = ["HOME": root.path, "CFFIXED_USER_HOME": root.path, "BMUX_PROVENANCE_HOME": root.path,
            "PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "PWD": root.path, "BMUX_SOCKET_PATH": socketPath,
            "BMUX_WORKSPACE_ID": workspace, "BMUX_STABLE_WORKSPACE_ID": stable, "BMUX_SURFACE_ID": surface,
            "BMUX_AGENT_HOOK_STATE_DIR": root.path, "BMUX_CLI_SENTRY_DISABLED": "1", "BMUX_CODEX_PID": String(getpid())]
        let hook = runCodexHookProcess(executablePath: cliPath, arguments: ["hooks", "codex", "prompt-submit"],
            environment: environment,
            standardInput: #"{"session_id":"unattested-session","turn_id":"turn-1","hook_event_name":"UserPromptSubmit"}"#,
            timeout: 10)
        #expect(!hook.timedOut && hook.status == 0)
        #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("codex-hook-sessions.json").path))
        let association = try await peAssociationResponse(root: root, stableWorkspaceId: stable)
        #expect(!association.found)
    }

    @Test func codexPromptSubmitResolvesStableWorkspaceFromRuntimeWorkspaceWhenEnvIsMissing() async throws {
        let cliPath = try BundledCLITestSupport.bundledCLIPath(for: BundledCLILinkageTests.self)
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("bmux-codex-hook-pe-runtime-association-\(UUID().uuidString)", isDirectory: true)
        let socketPath = makeCodexHookSocketPath("codex-pe")
        let listenerFD = try bindCodexHookUnixSocket(at: socketPath)
        let commands = CodexHookCapturedSocketCommands()
        let runtimeWorkspaceId = "11111111-1111-1111-1111-111111111111"
        let stableWorkspaceId = "33333333-3333-3333-3333-333333333333"
        let surfaceId = "22222222-2222-2222-2222-222222222222"
        let sessionId = "codex-hook-pe-runtime-association-session"
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer {
            Darwin.close(listenerFD)
            unlink(socketPath)
            try? FileManager.default.removeItem(at: root)
        }
        startCodexHookMockSocketServerAccepting(
            listenerFD: listenerFD,
            commands: commands,
            surfaceId: surfaceId,
            connectionLimit: 16,
            runtimeWorkspaceId: runtimeWorkspaceId,
            stableWorkspaceId: stableWorkspaceId
        )

        let result = runCodexHookProcess(
            executablePath: cliPath,
            arguments: ["hooks", "codex", "prompt-submit"],
            environment: [
                "HOME": root.path,
                "CFFIXED_USER_HOME": root.path,
                "BMUX_PROVENANCE_HOME": root.path,
                "PATH": "/usr/bin:/bin:/usr/sbin:/sbin",
                "PWD": root.path,
                "BMUX_SOCKET_PATH": socketPath,
                "BMUX_WORKSPACE_ID": runtimeWorkspaceId,
                "BMUX_SURFACE_ID": surfaceId,
                "BMUX_AGENT_HOOK_STATE_DIR": root.path,
                "BMUX_CLI_SENTRY_DISABLED": "1",
                "BMUX_CODEX_PID": "4242",
            ],
            standardInput: #"{"session_id":"\#(sessionId)","turn_id":"turn-hook-1","cwd":"\#(root.path)","hook_event_name":"UserPromptSubmit"}"#,
            timeout: 5
        )

        #expect(!result.timedOut, Comment(rawValue: result.stderr))
        #expect(result.status == 0, Comment(rawValue: result.stderr))
        #expect(result.stdout == "{}\n")
        #expect(commands.snapshot().contains {
            codexHookJSONObject($0)?["method"] as? String == "workspace.list"
        })

        let response = try await peAssociationResponse(root: root, stableWorkspaceId: stableWorkspaceId)
        let association = try #require(response.association)
        #expect(response.found)
        #expect(response.readiness.status == .associationEstablishedProjectionPending)
        #expect(association.workspaceID == stableWorkspaceId)
        #expect(association.sessionID == sessionId)
        #expect(association.surfaceID == surfaceId)
        #expect(association.sourcePath == "hook")
        #expect(association.reasonCode == "hook_prompt_observed")
    }

    @Test func currentRelatedRejectsReusedSurfaceWithMultipleCodexHookSessions() async throws {
        let cliPath = try BundledCLITestSupport.bundledCLIPath(for: BundledCLILinkageTests.self)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("bmux-current-reuse-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let socketPath = makeCodexHookSocketPath("related-reuse")
        let listener = try bindCodexHookUnixSocket(at: socketPath)
        defer {
            Darwin.close(listener)
            unlink(socketPath)
            try? FileManager.default.removeItem(at: root)
        }
        let workspace = "11111111-1111-1111-1111-111111111111"
        let stable = "33333333-3333-3333-3333-333333333333"
        let surface = "22222222-2222-2222-2222-222222222222"
        let commands = CodexHookCapturedSocketCommands()
        startCodexHookMockSocketServerAccepting(listenerFD: listener, commands: commands, surfaceId: surface,
            connectionLimit: 40, runtimeWorkspaceId: workspace, stableWorkspaceId: stable)
        let environment = ["HOME": root.path, "CFFIXED_USER_HOME": root.path, "BMUX_PROVENANCE_HOME": root.path,
            "PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "PWD": root.path, "BMUX_SOCKET_PATH": socketPath,
            "BMUX_WORKSPACE_ID": workspace, "BMUX_STABLE_WORKSPACE_ID": stable, "BMUX_SURFACE_ID": surface,
            "BMUX_AGENT_HOOK_STATE_DIR": root.path, "BMUX_CLI_SENTRY_DISABLED": "1", "BMUX_CODEX_PID": String(getpid())]
        func submit(_ session: String) {
            let result = runCodexHookProcess(executablePath: cliPath, arguments: ["hooks", "codex", "prompt-submit"],
                environment: environment,
                standardInput: #"{"session_id":"\#(session)","turn_id":"turn-\#(session)","cwd":"\#(root.path)","hook_event_name":"UserPromptSubmit"}"#,
                timeout: 10)
            #expect(!result.timedOut && result.status == 0, Comment(rawValue: result.stderr))
        }
        func query(_ session: String) throws -> [String: Any] {
            var caller = environment
            caller["CODEX_THREAD_ID"] = session
            let result = runCodexHookProcess(executablePath: cliPath,
                arguments: ["--json", "provenance", "sessions", "related", "--current"],
                environment: caller, timeout: 15)
            #expect(!result.timedOut && result.status == 0, Comment(rawValue: result.stderr))
            return try #require(try JSONSerialization.jsonObject(with: Data(result.stdout.utf8)) as? [String: Any])
        }
        submit("first-session")
        let first = try query("first-session")
        #expect(first["found"] as? Bool == true)
        submit("replacement-session")
        for session in ["first-session", "replacement-session"] {
            let result = try query(session)
            #expect(result["found"] as? Bool == false)
            #expect(result["reason"] as? String == "ambiguous_caller")
            #expect(result["recovery"] as? String == "start_fresh_pane")
        }
        var caller = environment
        caller["CODEX_THREAD_ID"] = "replacement-session"
        let text = runCodexHookProcess(executablePath: cliPath,
            arguments: ["provenance", "sessions", "related", "--current"], environment: caller, timeout: 15)
        #expect(text.stdout.contains("fresh pane"))
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
            let session = ProvenanceSessionRecord(id: id, agentKind: "codex", worktreeID: worktree.id,
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

    private func peAssociationResponse(
        root: URL,
        stableWorkspaceId: String
    ) async throws -> ProvenanceWorkspaceCodingAgentSessionAssociationResponse {
        let databaseURL = root
            .appendingPathComponent(".local", isDirectory: true)
            .appendingPathComponent("state", isDirectory: true)
            .appendingPathComponent("provenance-engine", isDirectory: true)
            .appendingPathComponent("provenance.sqlite", isDirectory: false)
        let client: any ProvenanceEngineContracts.ProvenanceEngineClient =
            try ProvenanceEngineClientFactory().sqliteClient(databaseURL: databaseURL)
        return try await client.workspaceCodingAgentSessionAssociation(
            ProvenanceWorkspaceCodingAgentSessionAssociationRequest(workspaceID: stableWorkspaceId)
        )
    }
}
