import Foundation

/// Completed command fact observed during a coding-agent turn.
public struct ProvenanceCodingAgentCommandRecord: Codable, Equatable, Sendable, Identifiable {
    /// Stable command projection identifier.
    public let id: String

    /// Provenance session that owns the command.
    public let sessionID: String

    /// Provider thread projection identifier, when known.
    public let threadID: String?

    /// Provider turn projection identifier, when known.
    public let turnID: String?

    /// Provider name, such as `codex`.
    public let provider: String

    /// Provider operation or item identifier, when available.
    public let operationID: String?

    /// Command text or argv rendering.
    public let command: String

    /// Working directory where the command ran, when known.
    public let cwd: String?

    /// Completion status, such as `succeeded`, `failed`, `cancelled`, or `unknown`.
    public let status: String

    /// Process exit code, when available.
    public let exitCode: Int?

    /// Bounded output or result summary, when policy permits it.
    public let outputSummary: String?

    /// Command start time, when observed.
    public let startedAt: Date?

    /// Command completion time.
    public let completedAt: Date

    /// Evidence class behind this command fact.
    public let source: ProvenanceSource

    /// Confidence in this command evidence.
    public let confidence: ProvenanceConfidence

    /// Creates a completed command projection record.
    public init(
        id: String,
        sessionID: String,
        threadID: String? = nil,
        turnID: String? = nil,
        provider: String,
        operationID: String? = nil,
        command: String,
        cwd: String? = nil,
        status: String,
        exitCode: Int? = nil,
        outputSummary: String? = nil,
        startedAt: Date? = nil,
        completedAt: Date,
        source: ProvenanceSource,
        confidence: ProvenanceConfidence
    ) {
        self.id = id
        self.sessionID = sessionID
        self.threadID = threadID
        self.turnID = turnID
        self.provider = provider
        self.operationID = operationID
        self.command = command
        self.cwd = cwd
        self.status = status
        self.exitCode = exitCode
        self.outputSummary = outputSummary
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.source = source
        self.confidence = confidence
    }

    /// Creates a completed command projection record from explicit tool text.
    public init(
        id: String,
        sessionID: String,
        threadID: String? = nil,
        turnID: String? = nil,
        provider: String,
        operationID: String? = nil,
        toolText: String,
        cwd: String? = nil,
        status: String,
        exitCode: Int? = nil,
        outputSummary: String? = nil,
        startedAt: Date? = nil,
        completedAt: Date,
        source: ProvenanceSource,
        confidence: ProvenanceConfidence
    ) {
        self.id = id
        self.sessionID = sessionID
        self.threadID = threadID
        self.turnID = turnID
        self.provider = provider
        self.operationID = operationID
        self.command = toolText
        self.cwd = cwd
        self.status = status
        self.exitCode = exitCode
        self.outputSummary = outputSummary
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.source = source
        self.confidence = confidence
    }
}
