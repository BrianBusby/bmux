import BmuxAgentChat
import Foundation

/// Identity of one deliberately created shared host and its original TUI.
struct ConnectedCodexHost: Sendable {
    let surfaceID: UUID
    var threadID: String?
    let processID: Int32
    let endpoint: URL
    let terminalCommand: String
    var connection: CodexRPCConnection
    var control: CodexSharedControl?
}
