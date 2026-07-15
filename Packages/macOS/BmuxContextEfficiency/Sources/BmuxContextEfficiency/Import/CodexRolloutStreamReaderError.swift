import Foundation

enum CodexRolloutStreamReaderError: Error, Equatable, Sendable {
    case invalidUTF8(sourcePath: String, byteOffset: Int64, lineNumber: Int)
    case negativeOffset(Int64)
}
