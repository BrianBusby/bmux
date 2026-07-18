import Foundation

/// Summary of an incremental Codex rollout import.
public struct CodexRolloutImportResult: Codable, Equatable, Sendable {
    /// Source rollout path.
    public var sourcePath: String
    /// Number of complete JSONL lines read.
    public var lineCount: Int
    /// Number of compact rollout event rows stored.
    public var rolloutEventCount: Int
    /// Number of non-duplicate model-call telemetry rows stored.
    public var modelCallCount: Int
    /// Number of duplicate cumulative token telemetry rows skipped.
    public var duplicateTokenTelemetryCount: Int
    /// Number of parser errors recorded.
    public var parserErrorCount: Int
    /// Number of tool calls stored.
    public var toolCallCount: Int
    /// Number of tool outputs stored.
    public var toolOutputCount: Int
    /// Number of compaction events observed.
    public var compactionCount: Int
    /// Whether the existing cursor was reset because the source shrank.
    public var resetCursor: Bool
    /// Cursor after the import completed.
    public var cursor: CodexRolloutImportCursor

    /// Creates an import result.
    public init(
        sourcePath: String,
        lineCount: Int,
        rolloutEventCount: Int,
        modelCallCount: Int,
        duplicateTokenTelemetryCount: Int,
        parserErrorCount: Int,
        toolCallCount: Int,
        toolOutputCount: Int,
        compactionCount: Int,
        resetCursor: Bool,
        cursor: CodexRolloutImportCursor
    ) {
        self.sourcePath = sourcePath
        self.lineCount = lineCount
        self.rolloutEventCount = rolloutEventCount
        self.modelCallCount = modelCallCount
        self.duplicateTokenTelemetryCount = duplicateTokenTelemetryCount
        self.parserErrorCount = parserErrorCount
        self.toolCallCount = toolCallCount
        self.toolOutputCount = toolOutputCount
        self.compactionCount = compactionCount
        self.resetCursor = resetCursor
        self.cursor = cursor
    }
}
