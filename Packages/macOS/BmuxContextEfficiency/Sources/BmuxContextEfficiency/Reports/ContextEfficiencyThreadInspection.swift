import Foundation

/// Read-only inspection report for one imported agent thread.
public struct ContextEfficiencyThreadInspection: Codable, Equatable, Sendable {
    /// Imported thread projection.
    public var thread: ContextEfficiencyAgentThreadRecord?
    /// Non-duplicate model-call telemetry rows for the thread.
    public var modelCalls: [ContextEfficiencyModelCallRecord]
    /// Raw token telemetry rows for the thread.
    public var tokenTelemetryEvents: [ContextEfficiencyTokenTelemetryRecord]
    /// Tool-call facts imported for the thread.
    public var toolCalls: [ContextEfficiencyToolCallRecord]
    /// Tool-output facts imported for the thread.
    public var toolOutputs: [ContextEfficiencyToolOutputRecord]
    /// Derived command execution candidates with attribution labels.
    public var commandExecutions: [ContextEfficiencyCommandExecutionRecord]
    /// Count of derived command executions by normalized command category.
    public var commandCategoryCounts: [ContextEfficiencyCommandCategoryCount]
    /// Compact facts for repeated normalized commands, searches, and file reads.
    public var repeatedCommandFacts: [ContextEfficiencyRepeatedCommandFact]
    /// Evidence-backed PR, ticket, branch, issue, and repository reference facts.
    public var workItemReferences: [ContextEfficiencyWorkItemReferenceRecord]
    /// Parser errors tied to the thread's source evidence when available.
    public var parserErrors: [ContextEfficiencyParserErrorRecord]

    /// Creates a thread inspection report.
    public init(
        thread: ContextEfficiencyAgentThreadRecord?,
        modelCalls: [ContextEfficiencyModelCallRecord],
        tokenTelemetryEvents: [ContextEfficiencyTokenTelemetryRecord],
        toolCalls: [ContextEfficiencyToolCallRecord],
        toolOutputs: [ContextEfficiencyToolOutputRecord],
        commandExecutions: [ContextEfficiencyCommandExecutionRecord],
        commandCategoryCounts: [ContextEfficiencyCommandCategoryCount],
        repeatedCommandFacts: [ContextEfficiencyRepeatedCommandFact],
        workItemReferences: [ContextEfficiencyWorkItemReferenceRecord],
        parserErrors: [ContextEfficiencyParserErrorRecord]
    ) {
        self.thread = thread
        self.modelCalls = modelCalls
        self.tokenTelemetryEvents = tokenTelemetryEvents
        self.toolCalls = toolCalls
        self.toolOutputs = toolOutputs
        self.commandExecutions = commandExecutions
        self.commandCategoryCounts = commandCategoryCounts
        self.repeatedCommandFacts = repeatedCommandFacts
        self.workItemReferences = workItemReferences
        self.parserErrors = parserErrors
    }
}
