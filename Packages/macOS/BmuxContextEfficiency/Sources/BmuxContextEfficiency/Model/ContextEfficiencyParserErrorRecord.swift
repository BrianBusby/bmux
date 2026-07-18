public import Foundation

/// A recoverable parser error observed while importing a rollout file.
public struct ContextEfficiencyParserErrorRecord: Codable, Equatable, Sendable, Identifiable {
    /// Stable parser-error identifier derived from source evidence.
    public var id: String
    /// Error message suitable for diagnostics.
    public var message: String
    /// Rollout event type when it could be read without full parsing.
    public var rolloutType: String?
    /// Source evidence location for the failed line.
    public var sourceReference: ContextEfficiencySourceReference
    /// Time the parser error was imported.
    public var importedAt: Date

    /// Creates a parser error record.
    public init(
        id: String,
        message: String,
        rolloutType: String?,
        sourceReference: ContextEfficiencySourceReference,
        importedAt: Date
    ) {
        self.id = id
        self.message = message
        self.rolloutType = rolloutType
        self.sourceReference = sourceReference
        self.importedAt = importedAt
    }
}
