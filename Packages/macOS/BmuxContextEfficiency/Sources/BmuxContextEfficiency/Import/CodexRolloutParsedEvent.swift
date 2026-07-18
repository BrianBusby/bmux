import Foundation

struct CodexRolloutParsedEvent: Equatable, Sendable {
    var kind: CodexRolloutEventKind
    var rolloutType: String?
    var payloadType: String?
    var threadID: String
    var timestamp: Date?
    var sourceReference: ContextEfficiencySourceReference
    var tokenUsage: ContextEfficiencyTokenUsage?
    var toolCall: CodexRolloutParsedToolCall?
    var toolOutput: CodexRolloutParsedToolOutput?
    var workItemReferences: [CodexRolloutParsedWorkItemReference]
    var parserErrorMessage: String?
    var model: String?
    var reasoningEffort: String?
    var cwd: String?
}
