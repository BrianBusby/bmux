import Foundation

/// Observable provider plan update associated with a coding-agent turn.
public struct ProvenanceCodingAgentPlanUpdateRecord: Codable, Equatable, Sendable, Identifiable {
    /// Stable plan update projection identifier.
    public let id: String

    /// Provenance session that owns the plan update.
    public let sessionID: String

    /// Provider thread projection identifier, when known.
    public let threadID: String?

    /// Provider turn projection identifier, when known.
    public let turnID: String?

    /// Provider name, such as `codex`.
    public let provider: String

    /// Optional provider explanation for the plan update.
    public let explanation: String?

    /// Ordered provider-emitted plan steps.
    public let steps: [ProvenanceCodingAgentPlanStepRecord]

    /// Time this update was observed.
    public let observedAt: Date

    /// Evidence class behind this plan update.
    public let source: ProvenanceSource

    /// Confidence in this plan evidence.
    public let confidence: ProvenanceConfidence

    /// Creates a coding-agent plan update projection record.
    public init(
        id: String,
        sessionID: String,
        threadID: String? = nil,
        turnID: String? = nil,
        provider: String,
        explanation: String? = nil,
        steps: [ProvenanceCodingAgentPlanStepRecord],
        observedAt: Date,
        source: ProvenanceSource,
        confidence: ProvenanceConfidence
    ) {
        self.id = id
        self.sessionID = sessionID
        self.threadID = threadID
        self.turnID = turnID
        self.provider = provider
        self.explanation = explanation
        self.steps = steps
        self.observedAt = observedAt
        self.source = source
        self.confidence = confidence
    }
}
