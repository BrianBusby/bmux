import Foundation

/// Revision metadata for a deterministic turn outcome.
public struct ProvenanceTurnOutcomeProjectionMetadata: Codable, Equatable, Sendable {
    /// Stable outcome revision identifier.
    public let revisionID: String

    /// Stable projection rule identity.
    public let projectionRuleID: String

    /// Stable projection rule version.
    public let projectionRuleVersion: String

    /// Stable fingerprint of factual outcome content.
    public let contentFingerprint: String

    /// Latest accepted event sequence used when this revision was produced.
    public let sourceEvidenceWatermark: Int?

    /// Deterministic generation time, derived from accepted evidence.
    public let generatedAt: Date?

    /// Creates projection metadata.
    public init(
        revisionID: String,
        projectionRuleID: String,
        projectionRuleVersion: String,
        contentFingerprint: String,
        sourceEvidenceWatermark: Int?,
        generatedAt: Date?
    ) {
        self.revisionID = revisionID
        self.projectionRuleID = projectionRuleID
        self.projectionRuleVersion = projectionRuleVersion
        self.contentFingerprint = contentFingerprint
        self.sourceEvidenceWatermark = sourceEvidenceWatermark
        self.generatedAt = generatedAt
    }
}
