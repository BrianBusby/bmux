import Foundation
#if canImport(bmux_DEV)
@testable import bmux_DEV
#else
@testable import bmux
#endif

@MainActor final class ConnectedCodexFixtureReader: TerminalChatReading {
    func terminalChatSnapshot(workspaceID: UUID, surfaceID: UUID) async -> [String: Any] {
        ["status": "unavailable", "reason": "historyUnavailable"]
    }
    func terminalChatRawOutput(workspaceID: UUID, surfaceID: UUID, sessionID: String, messageID: String) async throws -> String? { nil }
}
