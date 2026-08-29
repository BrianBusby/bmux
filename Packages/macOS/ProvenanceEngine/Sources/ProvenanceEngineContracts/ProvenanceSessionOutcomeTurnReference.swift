import Foundation

/// One ordered turn-outcome revision included in a session outcome.
public struct ProvenanceSessionOutcomeTurnReference: Codable, Equatable, Sendable {
    /// Zero-based order of the turn within the session outcome.
    public let order: Int

    /// Stable Provenance Engine turn projection identifier.
    public let turnID: String

    /// Provider name, such as `codex`.
    public let provider: String

    /// Provider-native turn identifier.
    public let providerTurnID: String

    /// Exact turn-outcome revision identifier aggregated for this turn.
    public let turnOutcomeRevisionID: String

    /// Content fingerprint of the aggregated turn-outcome revision.
    public let turnOutcomeContentFingerprint: String

    /// Source evidence watermark of the aggregated turn-outcome revision.
    public let sourceEvidenceWatermark: Int?

    /// Raw factual turn lifecycle state.
    public let lifecycleState: String

    /// Normalized factual turn completion state.
    public let completionState: String

    /// Observed turn start timestamp, when available.
    public let startedAt: Date?

    /// Observed turn completion timestamp, when available.
    public let completedAt: Date?

    /// Creates a constituent turn reference.
    public init(
        order: Int,
        turnID: String,
        provider: String,
        providerTurnID: String,
        turnOutcomeRevisionID: String,
        turnOutcomeContentFingerprint: String,
        sourceEvidenceWatermark: Int?,
        lifecycleState: String,
        completionState: String,
        startedAt: Date? = nil,
        completedAt: Date? = nil
    ) {
        self.order = order
        self.turnID = turnID
        self.provider = provider
        self.providerTurnID = providerTurnID
        self.turnOutcomeRevisionID = turnOutcomeRevisionID
        self.turnOutcomeContentFingerprint = turnOutcomeContentFingerprint
        self.sourceEvidenceWatermark = sourceEvidenceWatermark
        self.lifecycleState = lifecycleState
        self.completionState = completionState
        self.startedAt = startedAt
        self.completedAt = completedAt
    }
}
