import Foundation

/// One completed command or tool execution observed for a coding-agent turn.
public struct ProvenanceTurnOutcomeCommand: Codable, Equatable, Sendable {
    /// Stable coding-agent command identifier.
    public let id: String

    /// Provider operation identifier, when present.
    public let operationID: String?

    /// Command or tool text copied from accepted evidence.
    public let command: String

    /// Working directory observed for the command, when present.
    public let cwd: String?

    /// Provider command status.
    public let status: String

    /// Process exit code, when observed.
    public let exitCode: Int?

    /// Output summary copied from accepted evidence, when present.
    public let outputSummary: String?

    /// Observed command start timestamp.
    public let startedAt: Date?

    /// Observed command completion timestamp.
    public let completedAt: Date?

    /// Deterministic command classification.
    public let classification: ProvenanceTurnOutcomeCommandClassification

    /// Supporting evidence references for this command.
    public let evidence: [ProvenanceTurnOutcomeEvidenceReference]

    /// Creates a completed command fact.
    public init(
        id: String,
        operationID: String?,
        command: String,
        cwd: String?,
        status: String,
        exitCode: Int?,
        outputSummary: String?,
        startedAt: Date?,
        completedAt: Date?,
        classification: ProvenanceTurnOutcomeCommandClassification,
        evidence: [ProvenanceTurnOutcomeEvidenceReference]
    ) {
        self.id = id
        self.operationID = operationID
        self.command = command
        self.cwd = cwd
        self.status = status
        self.exitCode = exitCode
        self.outputSummary = outputSummary
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.classification = classification
        self.evidence = evidence
    }
}
