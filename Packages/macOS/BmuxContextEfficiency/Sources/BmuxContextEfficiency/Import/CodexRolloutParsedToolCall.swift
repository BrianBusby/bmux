import Foundation

struct CodexRolloutParsedToolCall: Equatable, Sendable {
    var callID: String?
    var toolName: String?
    var commandSummary: String?
    var argumentsByteCount: Int64
}
