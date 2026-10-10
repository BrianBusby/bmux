import Foundation

@MainActor
protocol TerminalChatConnecting: TerminalChatReading {
    func prepareConnectedSession(workspaceID: UUID, surfaceID: UUID, workingDirectory: String, configuration: ConnectedCodexLaunchConfiguration) async throws -> String
    func attachConnectedTerminal(surfaceID: UUID, isAlive: @escaping @MainActor () -> Bool)
    func closeConnectedSession(surfaceID: UUID) async
    func updateConnectedDraft(workspaceID: UUID, surfaceID: UUID, sessionID: String, revision: UUID, text: String) throws
    func performConnectedAction(workspaceID: UUID, surfaceID: UUID, sessionID: String, requestID: UUID, draftRevision: UUID, text: String, expectedTurnID: String?) async throws -> [String: Any]
}

extension TerminalChatConnecting {
    func prepareConnectedSession(workspaceID: UUID, surfaceID: UUID, workingDirectory: String) async throws -> String {
        try await prepareConnectedSession(workspaceID: workspaceID, surfaceID: surfaceID,
            workingDirectory: workingDirectory, configuration: .init())
    }
}
