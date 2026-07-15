import Foundation

enum CodexRolloutEventKind: String, Codable, Sendable {
    case unknownImported
    case sessionObserved
    case tokenTelemetryObserved
    case compactionObserved
    case toolCallObserved
    case toolOutputObserved
    case userMessageObserved
    case assistantMessageObserved
    case parserErrorObserved
}
