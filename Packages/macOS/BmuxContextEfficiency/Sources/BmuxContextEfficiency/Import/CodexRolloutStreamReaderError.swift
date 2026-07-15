import Foundation

enum CodexRolloutStreamReaderError: Error, Equatable, Sendable {
    case negativeOffset(Int64)
}
