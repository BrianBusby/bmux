import BmuxAgentChat
import Foundation
import Testing
#if canImport(bmux_DEV)
@testable import bmux_DEV
#else
@testable import bmux
#endif

@Suite @MainActor struct ConnectedSessionOwnershipTests {
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
