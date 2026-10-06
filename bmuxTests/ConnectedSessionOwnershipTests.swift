import BmuxAgentChat
import BmuxFoundation
import Foundation
import Testing
#if canImport(bmux_DEV)
@testable import bmux_DEV
#else
@testable import bmux
#endif

@Suite @MainActor struct ConnectedSessionOwnershipTests {

    @Test func unsupportedChatGPTModelUsesClientDefaultWithoutChangingValidReasoningEffort() async throws {
        let arguments = try await launchedArguments(model: "unavailable-model", effort: "xhigh")
        #expect(arguments.suffix(2) == ["--model", "catalog-default"])
        #expect(!arguments.contains("-c"))
    }

    @Test func fallbackModelReplacesOnlyUnsupportedReasoningEffort() async throws {
        let arguments = try await launchedArguments(model: "unavailable-model", effort: "unsupported-effort")
        #expect(arguments.suffix(4) == ["--model", "catalog-default", "-c", "model_reasoning_effort=\"low\""])
    }

    @Test(arguments: ["chatgpt", "apiKey"])
    func validOrCustomModelsRetainCLIConfiguration(accountType: String) async throws {
        let arguments = try await launchedArguments(model: accountType == "chatgpt" ? "hidden-valid" : "custom-provider-model",
                                                   accountType: accountType)
        #expect(!arguments.contains("--model"))
        #expect(!arguments.contains("-c"))
    }

    @Test func customProviderWithChatGPTLoginRetainsCLIConfiguration() async throws {
        let arguments = try await launchedArguments(model: "local-model", provider: "local-provider")
        #expect(!arguments.contains("--model"))
    }

    @Test(arguments: ["{\"data\":[],\"nextCursor\":null}", "{\"data\":[],\"nextCursor\":\"repeated\"}"])
    func unavailableCatalogFailsClosedAndDisconnects(catalog: String) async throws {
        await #expect(throws: CodexControlError.invalidResponse) {
            _ = try await launchedArguments(model: "unavailable-model", catalogOverride: catalog)
        }
    }

    /// Runs the real host launcher and its shell command with an isolated fake CLI.
    /// Model/account RPC replies are values; no user configuration or auth is read.
    private func launchedArguments(model: String, effort: String = "xhigh", accountType: String = "chatgpt",
                                   provider: String = "openai", catalogOverride: String? = nil) async throws -> [String] {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("connected-model-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let executable = directory.appendingPathComponent("codex fixture")
        let script = """
        #!/bin/sh
        case "$1" in
          --version) printf 'codex-cli 0.154.0\n';;
          app-server)
            printf 'listening on: ws://127.0.0.1:1\n'
            exec /usr/bin/python3 -c 'import signal; signal.pause()';;
          *) exec /usr/bin/python3 -c 'import json,sys; print(json.dumps(sys.argv[1:]))' "$@";;
        esac
        """
        try Data(script.utf8).write(to: executable)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: executable.path)
        let config = try JSONSerialization.data(withJSONObject: ["config": ["model": model,
            "model_reasoning_effort": effort, "model_provider": provider]])
        let catalog = Data("""
        {"data":[{"model":"catalog-default","hidden":false,"isDefault":true,"defaultReasoningEffort":"low",
          "supportedReasoningEfforts":[{"reasoningEffort":"low"},{"reasoningEffort":"xhigh"}]},
          {"model":"hidden-valid","hidden":true,"isDefault":false,"defaultReasoningEffort":"low",
          "supportedReasoningEfforts":[{"reasoningEffort":"low"}]}],"nextCursor":null}
        """.utf8)
        let account = try JSONSerialization.data(withJSONObject: ["account": ["type": accountType]])
        let transport = ConnectedCodexFixtureTransport(responses: [
            "account/read": account, "config/read": config,
            "model/list": catalogOverride.map { Data($0.utf8) } ?? catalog])
        let connection = CodexRPCConnection(transport: transport)
        let service = ConnectedCodexHostService(executable: executable, root: directory.appendingPathComponent("hosts"),
                                               environment: ["PATH": "/usr/bin:/bin"], connect: { _, _ in
            try await connection.start()
            return connection
        })
        let surfaceID = UUID()
        do {
            let host = try await service.launch(surfaceID: surfaceID, workingDirectory: directory.path)
            let output = await CommandRunner(environment: ["PATH": "/usr/bin:/bin"]).runStandardOutput(
                directory: directory.path, executable: "/bin/sh", arguments: ["-c", host.terminalCommand], timeout: 5)
            await service.endOwnedHost(surfaceID: surfaceID)
            await connection.disconnect()
            let data = Data(try #require(output).utf8)
            return try JSONDecoder().decode([String].self, from: data)
        } catch {
            #expect(await transport.closeCount == 1)
            await service.endOwnedHost(surfaceID: surfaceID)
            await connection.disconnect()
            throw error
        }
    }

    @Test func overlappingSnapshotReadsKeepOneReconnectAndUsableControl() async throws {
        let entered = AsyncStream<Void>.makeStream()
        var release: CheckedContinuation<Void, Never>?
        var reconnects = 0
        let replacementTransport = ConnectedCodexFixtureTransport()
        let connection = CodexRPCConnection(transport: ConnectedCodexFixtureTransport())
        try await connection.start()
        let hosts = ConnectedCodexFixtureHost(connection: connection, replacementForReconnect: { host in
            reconnects += 1
            if reconnects == 1 {
                await withCheckedContinuation { continuation in
                    release = continuation
                    entered.continuation.yield(())
                }
            }
            let replacement = CodexRPCConnection(transport: reconnects == 1 ? replacementTransport : ConnectedCodexFixtureTransport())
            try await replacement.start()
            // Match the real host service: rebinding disconnects the previous
            // connection on the same retained control actor before returning.
            await host.control?.reconnect(using: replacement)
            var result = host
            result.connection = replacement
            return result
        })
        let runtime = TerminalChatRuntime(reader: ConnectedCodexFixtureReader(), hosts: hosts,
                                         bind: { _, _, _, _ in })
        let workspace = UUID(), surface = UUID()
        _ = try await runtime.prepareConnectedSession(workspaceID: workspace, surfaceID: surface, workingDirectory: "/tmp")
        runtime.attachConnectedTerminal(surfaceID: surface, isAlive: { true })
        _ = await runtime.terminalChatSnapshot(workspaceID: workspace, surfaceID: surface)
        await connection.disconnect()
        let firstRead = Task { await runtime.terminalChatSnapshot(workspaceID: workspace, surfaceID: surface) }
        var iterator = entered.stream.makeAsyncIterator()
        _ = await iterator.next()
        _ = await runtime.terminalChatSnapshot(workspaceID: workspace, surfaceID: surface)
        #expect(reconnects == 1)
        release?.resume()
        _ = await firstRead.value
        let revision = UUID()
        try runtime.updateConnectedDraft(workspaceID: workspace, surfaceID: surface, sessionID: "thread-a", revision: revision, text: "Continue the inspection")
        let result = try? await runtime.performConnectedAction(workspaceID: workspace, surfaceID: surface, sessionID: "thread-a", requestID: UUID(), draftRevision: revision, text: "Continue the inspection", expectedTurnID: nil)
        #expect(result?["delivery"] as? String == "accepted")
        #expect(await replacementTransport.mutationThreads == ["thread-a"])
        #expect(reconnects == 1)
        await runtime.closeConnectedSession(surfaceID: surface)
        entered.continuation.finish()
    }

    @Test func reconnectCompletingAfterCloseCannotRestoreRetiredControl() async throws {
        let entered = AsyncStream<Void>.makeStream()
        var release: CheckedContinuation<Void, Never>?
        let connection = CodexRPCConnection(transport: ConnectedCodexFixtureTransport())
        try await connection.start()
        let hosts = ConnectedCodexFixtureHost(connection: connection, beforeReconnect: {
            await withCheckedContinuation { continuation in
                release = continuation
                entered.continuation.yield(())
            }
        })
        let runtime = TerminalChatRuntime(reader: ConnectedCodexFixtureReader(), hosts: hosts,
                                         bind: { _, _, _, _ in })
        let workspace = UUID(), surface = UUID()
        _ = try await runtime.prepareConnectedSession(workspaceID: workspace, surfaceID: surface, workingDirectory: "/tmp")
        runtime.attachConnectedTerminal(surfaceID: surface, isAlive: { true })
        _ = await runtime.terminalChatSnapshot(workspaceID: workspace, surfaceID: surface)
        await connection.disconnect()
        let read = Task { await runtime.terminalChatSnapshot(workspaceID: workspace, surfaceID: surface) }
        var iterator = entered.stream.makeAsyncIterator()
        _ = await iterator.next()
        await runtime.closeConnectedSession(surfaceID: surface)
        release?.resume()
        let snapshot = await read.value
        #expect(snapshot["control"] == nil)
        #expect(snapshot["sessionId"] == nil)
        #expect(throws: (any Error).self) {
            try runtime.updateConnectedDraft(workspaceID: workspace, surfaceID: surface, sessionID: "thread-a", revision: UUID(), text: "Retired session")
        }
        let refreshed = await runtime.terminalChatSnapshot(workspaceID: workspace, surfaceID: surface)
        #expect(refreshed["control"] == nil)
        #expect(refreshed["sessionId"] == nil)
        entered.continuation.finish()
    }

    @Test func adoptionCompletingAfterCloseCannotRestoreRetiredControlOrBinding() async throws {
        let entered = AsyncStream<Void>.makeStream()
        var release: CheckedContinuation<Void, Never>?
        var bindings: [String] = []
        let connection = CodexRPCConnection(transport: ConnectedCodexFixtureTransport())
        try await connection.start()
        let hosts = ConnectedCodexFixtureHost(connection: connection, beforeAdoption: {
            await withCheckedContinuation { continuation in
                release = continuation
                entered.continuation.yield(())
            }
        })
        let runtime = TerminalChatRuntime(reader: ConnectedCodexFixtureReader(), hosts: hosts,
                                         bind: { thread, _, _, _ in bindings.append(thread) })
        let workspace = UUID(), surface = UUID()
        _ = try await runtime.prepareConnectedSession(workspaceID: workspace, surfaceID: surface, workingDirectory: "/tmp")
        runtime.attachConnectedTerminal(surfaceID: surface, isAlive: { true })
        let read = Task { await runtime.terminalChatSnapshot(workspaceID: workspace, surfaceID: surface) }
        var iterator = entered.stream.makeAsyncIterator()
        _ = await iterator.next()
        await runtime.closeConnectedSession(surfaceID: surface)
        release?.resume()
        let snapshot = await read.value
        #expect(bindings.isEmpty)
        #expect(snapshot["control"] == nil)
        #expect(snapshot["sessionId"] == nil)
        #expect(throws: (any Error).self) {
            try runtime.updateConnectedDraft(workspaceID: workspace, surfaceID: surface, sessionID: "thread-a", revision: UUID(), text: "Retired session")
        }
        entered.continuation.finish()
    }

    @Test func connectionAuthoritySurvivesMissingHistoryButCannotCrossWorkspaceOrThread() async throws {
        let transport = ConnectedCodexFixtureTransport()
        let connection = CodexRPCConnection(transport: transport)
        try await connection.start()
        let runtime = TerminalChatRuntime(reader: ConnectedCodexFixtureReader(), hosts: ConnectedCodexFixtureHost(connection: connection), bind: { _, _, _, _ in })
        let workspace = UUID(), surface = UUID()
        _ = try await runtime.prepareConnectedSession(workspaceID: workspace, surfaceID: surface, workingDirectory: "/fixture")
        runtime.attachConnectedTerminal(surfaceID: surface, isAlive: { true })
        let snapshot = await runtime.terminalChatSnapshot(workspaceID: workspace, surfaceID: surface)
        #expect(snapshot["status"] as? String == "unavailable")
        #expect((snapshot["control"] as? [String: Any])?["status"] as? String == "connected")
        await #expect(throws: CodexControlError.wrongThread) {
            try await runtime.performConnectedAction(workspaceID: UUID(), surfaceID: surface, sessionID: "thread-a", requestID: UUID(), draftRevision: UUID(), text: "Wrong workspace", expectedTurnID: nil)
        }
        await #expect(throws: CodexControlError.wrongThread) {
            try await runtime.performConnectedAction(workspaceID: workspace, surfaceID: surface, sessionID: "thread-b", requestID: UUID(), draftRevision: UUID(), text: "Wrong thread", expectedTurnID: nil)
        }
        #expect(await transport.mutationThreads.isEmpty)
        let draftRevision = UUID()
        try runtime.updateConnectedDraft(workspaceID: workspace, surfaceID: surface, sessionID: "thread-a", revision: draftRevision, text: "Inspect the build")
        let result = try await runtime.performConnectedAction(workspaceID: workspace, surfaceID: surface, sessionID: "thread-a", requestID: UUID(), draftRevision: draftRevision, text: "Inspect the build", expectedTurnID: nil)
        #expect(result["delivery"] as? String == "accepted")
        #expect(await transport.mutationThreads == ["thread-a"])
        let refreshed = await runtime.terminalChatSnapshot(workspaceID: workspace, surfaceID: surface)
        #expect((refreshed["control"] as? [String: Any])?["draft"] == nil)
        await runtime.closeConnectedSession(surfaceID: surface)
    }

    @Test func additionalLoadedThreadDoesNotDisplaceTheVerifiedOriginalConnection() async throws {
        let transport = ConnectedCodexFixtureTransport()
        let connection = CodexRPCConnection(transport: transport)
        try await connection.start()
        let runtime = TerminalChatRuntime(reader: ConnectedCodexFixtureReader(), hosts: ConnectedCodexFixtureHost(connection: connection), bind: { _, _, _, _ in })
        let workspace = UUID(), surface = UUID()
        var alive = true
        _ = try await runtime.prepareConnectedSession(workspaceID: workspace, surfaceID: surface, workingDirectory: "/fixture")
        runtime.attachConnectedTerminal(surfaceID: surface, isAlive: { alive })
        _ = await runtime.terminalChatSnapshot(workspaceID: workspace, surfaceID: surface)
        let draftRevision = UUID()
        try runtime.updateConnectedDraft(workspaceID: workspace, surfaceID: surface, sessionID: "thread-a", revision: draftRevision, text: "Follow up")
        await transport.setLoadedThreads(["thread-a", "thread-b"])
        let snapshot = await runtime.terminalChatSnapshot(workspaceID: workspace, surfaceID: surface)
        #expect((snapshot["control"] as? [String: Any])?["status"] as? String == "connected")
        let retainedDraft = (snapshot["control"] as? [String: Any])?["draft"] as? [String: Any]
        #expect(retainedDraft?["text"] as? String == "Follow up")
        let result = try await runtime.performConnectedAction(
            workspaceID: workspace,
            surfaceID: surface,
            sessionID: "thread-a",
            requestID: UUID(), draftRevision: draftRevision,
            text: "Follow up",
            expectedTurnID: nil
        )
        #expect(result["delivery"] as? String == "accepted")
        #expect(await transport.mutationThreads == ["thread-a"])
        await runtime.closeConnectedSession(surfaceID: surface)
    }

    @Test func exitedTerminalDisablesControlWithoutDiscardingTheDraft() async throws {
        let transport = ConnectedCodexFixtureTransport()
        let connection = CodexRPCConnection(transport: transport)
        try await connection.start()
        let runtime = TerminalChatRuntime(reader: ConnectedCodexFixtureReader(), hosts: ConnectedCodexFixtureHost(connection: connection), bind: { _, _, _, _ in })
        let workspace = UUID(), surface = UUID()
        var alive = true
        _ = try await runtime.prepareConnectedSession(workspaceID: workspace, surfaceID: surface, workingDirectory: "/fixture")
        runtime.attachConnectedTerminal(surfaceID: surface, isAlive: { alive })
        _ = await runtime.terminalChatSnapshot(workspaceID: workspace, surfaceID: surface)
        let draftRevision = UUID()
        try runtime.updateConnectedDraft(workspaceID: workspace, surfaceID: surface, sessionID: "thread-a", revision: draftRevision, text: "Keep this draft")

        alive = false

        let snapshot = await runtime.terminalChatSnapshot(workspaceID: workspace, surfaceID: surface)
        #expect((snapshot["control"] as? [String: Any])?["status"] as? String == "unavailable")
        let retainedDraft = (snapshot["control"] as? [String: Any])?["draft"] as? [String: Any]
        #expect(retainedDraft?["text"] as? String == "Keep this draft")
        await #expect(throws: CodexControlError.disconnected) {
            try await runtime.performConnectedAction(
                workspaceID: workspace,
                surfaceID: surface,
                sessionID: "thread-a",
                requestID: UUID(), draftRevision: draftRevision,
                text: "Must not send",
                expectedTurnID: nil
            )
        }
        await runtime.closeConnectedSession(surfaceID: surface)
    }

    @Test func recoveredAcceptanceDoesNotRetireALaterSameTextDraft() async throws {
        let transport = ConnectedCodexFixtureTransport()
        await transport.omitQueueAcknowledgmentID()
        let connection = CodexRPCConnection(transport: transport)
        try await connection.start()
        let runtime = TerminalChatRuntime(reader: ConnectedCodexFixtureReader(), hosts: ConnectedCodexFixtureHost(connection: connection), bind: { _, _, _, _ in })
        let workspace = UUID(), surface = UUID()
        _ = try await runtime.prepareConnectedSession(workspaceID: workspace, surfaceID: surface, workingDirectory: "/fixture")
        runtime.attachConnectedTerminal(surfaceID: surface, isAlive: { true })
        _ = await runtime.terminalChatSnapshot(workspaceID: workspace, surfaceID: surface)
        let r1 = UUID(), r2 = UUID(), r3 = UUID(), request = UUID()
        try runtime.updateConnectedDraft(workspaceID: workspace, surfaceID: surface, sessionID: "thread-a", revision: r1, text: "X")
        let result = try await runtime.performConnectedAction(workspaceID: workspace, surfaceID: surface, sessionID: "thread-a", requestID: request, draftRevision: r1, text: "X", expectedTurnID: nil)
        #expect(result["delivery"] as? String == "uncertain")
        try runtime.updateConnectedDraft(workspaceID: workspace, surfaceID: surface, sessionID: "thread-a", revision: r2, text: "Y")
        try runtime.updateConnectedDraft(workspaceID: workspace, surfaceID: surface, sessionID: "thread-a", revision: r3, text: "X")
        let refreshed = await runtime.terminalChatSnapshot(workspaceID: workspace, surfaceID: surface)
        let draft = (refreshed["control"] as? [String: Any])?["draft"] as? [String: Any]
        #expect(draft?["revision"] as? String == r3.uuidString)
        #expect(draft?["text"] as? String == "X")
        #expect(await transport.mutationThreads == ["thread-a"])
        await runtime.closeConnectedSession(surfaceID: surface)
    }

    @Test func scopedPartialHistoryOverrideRecoversWithoutCrossSessionLeakage() async throws {
        let transport = ConnectedCodexFixtureTransport()
        let connection = CodexRPCConnection(transport: transport)
        try await connection.start()
        let reader = ConnectedCodexFixtureReader()
        reader.response = [
            "status": "observed", "sessionId": "thread-a",
            "history": ["messages": [["id": "one"], ["id": "two"]]]
        ]
        let runtime = TerminalChatRuntime(reader: reader, hosts: ConnectedCodexFixtureHost(connection: connection), bind: { _, _, _, _ in })
        let workspace = UUID(), surface = UUID()
        _ = try await runtime.prepareConnectedSession(workspaceID: workspace, surfaceID: surface, workingDirectory: "/fixture")
        runtime.attachConnectedTerminal(surfaceID: surface, isAlive: { true })
        _ = await runtime.terminalChatSnapshot(workspaceID: workspace, surfaceID: surface)
        let defaults = UserDefaults.standard
        defaults.set(workspace.uuidString, forKey: "bmux.acceptance.history.workspace")
        defaults.set(surface.uuidString, forKey: "bmux.acceptance.history.surface")
        defaults.set("thread-a", forKey: "bmux.acceptance.history.session")
        defaults.set("partial", forKey: "bmux.acceptance.history.mode")
        defer {
            ["bmux.acceptance.history.workspace", "bmux.acceptance.history.surface", "bmux.acceptance.history.session", "bmux.acceptance.history.mode"].forEach(defaults.removeObject(forKey:))
        }
        let partial = await runtime.terminalChatSnapshot(workspaceID: workspace, surfaceID: surface)
        #expect(partial["status"] as? String == "partial")
        #expect(partial["historyFreshness"] as? String == "partial")
        #expect(((partial["history"] as? [String: Any])?["messages"] as? [[String: Any]])?.count == 1)
        defaults.removeObject(forKey: "bmux.acceptance.history.mode")
        let recovered = await runtime.terminalChatSnapshot(workspaceID: workspace, surfaceID: surface)
        #expect(recovered["status"] as? String == "observed")
        #expect(((recovered["history"] as? [String: Any])?["messages"] as? [[String: Any]])?.count == 2)
        defaults.set("other-thread", forKey: "bmux.acceptance.history.session")
        let otherSession = await runtime.terminalChatSnapshot(workspaceID: workspace, surfaceID: surface)
        #expect(otherSession["status"] as? String == "observed")
        await runtime.closeConnectedSession(surfaceID: surface)
    }

    @Test func scopedTransportDisconnectFlagIsConsumedWithoutResubmission() async throws {
        let transport = ConnectedCodexFixtureTransport()
        let connection = CodexRPCConnection(transport: transport)
        try await connection.start()
        let runtime = TerminalChatRuntime(reader: ConnectedCodexFixtureReader(), hosts: ConnectedCodexFixtureHost(connection: connection), bind: { _, _, _, _ in })
        let workspace = UUID(), surface = UUID()
        _ = try await runtime.prepareConnectedSession(workspaceID: workspace, surfaceID: surface, workingDirectory: "/fixture")
        runtime.attachConnectedTerminal(surfaceID: surface, isAlive: { true })
        _ = await runtime.terminalChatSnapshot(workspaceID: workspace, surfaceID: surface)
        let key = "bmux.acceptance.disconnectTransport.\(surface.uuidString)"
        UserDefaults.standard.set(true, forKey: key)
        defer { UserDefaults.standard.removeObject(forKey: key) }
        _ = await runtime.terminalChatSnapshot(workspaceID: workspace, surfaceID: surface)
        #expect(UserDefaults.standard.bool(forKey: key) == false)
        #expect(await transport.mutationThreads.isEmpty)
        await runtime.closeConnectedSession(surfaceID: surface)
    }
}
