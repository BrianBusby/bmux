import Foundation

/// Read-only, surface-scoped access to the existing provider transcript.
@MainActor
protocol TerminalChatReading: AnyObject {
    func terminalChatSnapshot(workspaceID: UUID, surfaceID: UUID) async -> [String: Any]
    func terminalChatSnapshot(workspaceID: UUID, surfaceID: UUID, sessionID: String) async -> [String: Any]
    func terminalChatRawOutput(workspaceID: UUID, surfaceID: UUID, sessionID: String, messageID: String) async throws -> String?
}

extension TerminalChatReading {
    func terminalChatSnapshot(workspaceID: UUID, surfaceID: UUID, sessionID: String) async -> [String: Any] {
        let snapshot = await terminalChatSnapshot(workspaceID: workspaceID, surfaceID: surfaceID)
        return snapshot["sessionId"] as? String == sessionID ? snapshot : ["status": "unavailable"]
    }
}
