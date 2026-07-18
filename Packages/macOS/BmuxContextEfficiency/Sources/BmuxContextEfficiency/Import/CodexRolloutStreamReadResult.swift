import Foundation

struct CodexRolloutStreamReadResult: Equatable, Sendable {
    var lineCount: Int
    var nextByteOffset: Int64
    var nextLineNumber: Int
    var fileSize: Int64
    var pendingByteCount: Int
}
