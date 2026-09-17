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
            try await runtime.performConnectedAction(workspaceID: UUID(), surfaceID: surface, sessionID: "thread-a", requestID: UUID(), text: "Wrong workspace", expectedTurnID: nil)
        }
        await #expect(throws: CodexControlError.wrongThread) {
            try await runtime.performConnectedAction(workspaceID: workspace, surfaceID: surface, sessionID: "thread-b", requestID: UUID(), text: "Wrong thread", expectedTurnID: nil)
        }
        #expect(await transport.mutationThreads.isEmpty)
        try runtime.updateConnectedDraft(workspaceID: workspace, surfaceID: surface, sessionID: "thread-a", text: "Inspect the build")
        let result = try await runtime.performConnectedAction(workspaceID: workspace, surfaceID: surface, sessionID: "thread-a", requestID: UUID(), text: "Inspect the build", expectedTurnID: nil)
        #expect(result["delivery"] as? String == "accepted")
        #expect(await transport.mutationThreads == ["thread-a"])
        let refreshed = await runtime.terminalChatSnapshot(workspaceID: workspace, surfaceID: surface)
        #expect((refreshed["control"] as? [String: Any])?["draft"] as? String == "")
        await runtime.closeConnectedSession(surfaceID: surface)
    }

    @Test func healthyConnectionReconcilesUncertainAcceptanceWithoutResubmission() async throws {
        let transport = ConnectedCodexFixtureTransport()
        await transport.omitQueueAcknowledgmentID()
        let connection = CodexRPCConnection(transport: transport)
        try await connection.start()
        let runtime = TerminalChatRuntime(reader: ConnectedCodexFixtureReader(), hosts: ConnectedCodexFixtureHost(connection: connection), bind: { _, _, _, _ in })
        let workspace = UUID(), surface = UUID()
        _ = try await runtime.prepareConnectedSession(workspaceID: workspace, surfaceID: surface, workingDirectory: "/fixture")
        runtime.attachConnectedTerminal(surfaceID: surface, isAlive: { true })
        _ = await runtime.terminalChatSnapshot(workspaceID: workspace, surfaceID: surface)
        let requestID = UUID()
        try runtime.updateConnectedDraft(workspaceID: workspace, surfaceID: surface, sessionID: "thread-a", text: "Inspect the build")
        let receipt = try await runtime.performConnectedAction(workspaceID: workspace, surfaceID: surface, sessionID: "thread-a", requestID: requestID, text: "Inspect the build", expectedTurnID: nil)
        #expect(receipt["delivery"] as? String == "uncertain")
        let snapshot = await runtime.terminalChatSnapshot(workspaceID: workspace, surfaceID: surface)
        let control = try #require(snapshot["control"] as? [String: Any])
        let actions = try #require(control["actions"] as? [[String: Any]])
        #expect(control["status"] as? String == "connected")
        #expect(actions.first?["delivery"] as? String == "accepted")
        #expect(actions.first?["providerID"] as? String == "queued-a")
        #expect(control["draft"] as? String == "")
        try runtime.updateConnectedDraft(workspaceID: workspace, surfaceID: surface, sessionID: "thread-a", text: "Inspect the build")
        let nextSnapshot = await runtime.terminalChatSnapshot(workspaceID: workspace, surfaceID: surface)
        #expect((nextSnapshot["control"] as? [String: Any])?["draft"] as? String == "Inspect the build")
        #expect(await transport.mutationThreads == ["thread-a"])
        await runtime.closeConnectedSession(surfaceID: surface)
    }

    @Test func exitedTerminalAndChangedThreadDisableControlWithoutDiscardingTheDraft() async throws {
        let transport = ConnectedCodexFixtureTransport()
        let connection = CodexRPCConnection(transport: transport)
        try await connection.start()
        let runtime = TerminalChatRuntime(reader: ConnectedCodexFixtureReader(), hosts: ConnectedCodexFixtureHost(connection: connection), bind: { _, _, _, _ in })
        let workspace = UUID(), surface = UUID()
        var alive = true
        _ = try await runtime.prepareConnectedSession(workspaceID: workspace, surfaceID: surface, workingDirectory: "/fixture")
        runtime.attachConnectedTerminal(surfaceID: surface, isAlive: { alive })
        _ = await runtime.terminalChatSnapshot(workspaceID: workspace, surfaceID: surface)
        try runtime.updateConnectedDraft(workspaceID: workspace, surfaceID: surface, sessionID: "thread-a", text: "Keep this draft")
        alive = false
        let exited = await runtime.terminalChatSnapshot(workspaceID: workspace, surfaceID: surface)
        #expect((exited["control"] as? [String: Any])?["status"] as? String == "unavailable")
        #expect((exited["control"] as? [String: Any])?["draft"] as? String == "Keep this draft")
        await #expect(throws: CodexControlError.disconnected) {
            try await runtime.performConnectedAction(workspaceID: workspace, surfaceID: surface, sessionID: "thread-a", requestID: UUID(), text: "Must not send", expectedTurnID: nil)
        }
        alive = true
        await transport.setLoadedThreads(["thread-a", "thread-b"])
        let ambiguous = await runtime.terminalChatSnapshot(workspaceID: workspace, surfaceID: surface)
        #expect(ambiguous["reason"] as? String == "ambiguous")
        #expect(ambiguous["control"] == nil)
        #expect(await transport.mutationThreads.isEmpty)
        await runtime.closeConnectedSession(surfaceID: surface)
    }
}
