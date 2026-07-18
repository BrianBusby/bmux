import Foundation

struct CodexRolloutParsedToolOutput: Equatable, Sendable {
    var callID: String?
    var outputByteCount: Int64
    var estimatedOriginalTokens: Int64
    var rawOutputReferenceCount: Int
}
