import Foundation

/// Read-only aggregate report for imported telemetry on one calendar day.
public struct ContextEfficiencyDaySummary: Codable, Equatable, Sendable {
    /// Day in `YYYY-MM-DD` form.
    public var day: String
    /// Number of imported threads with telemetry in the day.
    public var threadCount: Int
    /// Number of non-duplicate model-call telemetry rows in the day.
    public var modelCallCount: Int
    /// Sum of total token counts when exposed by telemetry rows.
    public var totalTokens: Int64
    /// Sum of cached-input token counts when exposed by telemetry rows.
    public var cachedInputTokens: Int64
    /// Sum of output token counts when exposed by telemetry rows.
    public var outputTokens: Int64
    /// Parser errors imported from sources with events in the day.
    public var parserErrorCount: Int
    /// Count of dated tool calls by normalized command category.
    public var commandCategoryCounts: [ContextEfficiencyCommandCategoryCount]

    /// Creates a day summary report.
    public init(
        day: String,
        threadCount: Int,
        modelCallCount: Int,
        totalTokens: Int64,
        cachedInputTokens: Int64,
        outputTokens: Int64,
        parserErrorCount: Int,
        commandCategoryCounts: [ContextEfficiencyCommandCategoryCount]
    ) {
        self.day = day
        self.threadCount = threadCount
        self.modelCallCount = modelCallCount
        self.totalTokens = totalTokens
        self.cachedInputTokens = cachedInputTokens
        self.outputTokens = outputTokens
        self.parserErrorCount = parserErrorCount
        self.commandCategoryCounts = commandCategoryCounts
    }
}
