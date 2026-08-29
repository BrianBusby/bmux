import Foundation

/// Revision and freshness metadata for a related-session projection.
public struct ProvenanceRelatedSessionProjectionMetadata: Codable, Equatable, Sendable {
    /// Stable revision identifier for this projection content.
    public let revisionID: String

    /// Stable deterministic projection rule identifier.
    public let projectionRuleID: String

    /// Version of the deterministic projection rule.
    public let projectionRuleVersion: String

    /// Stable fingerprint of bounded query options.
    public let requestFingerprint: String

    /// Stable fingerprint of relationship content, excluding duplicate evidence copies.
    public let contentFingerprint: String

    /// Result limit applied by this projection.
    public let resultLimit: Int

    /// Exclusion explanation limit applied by this projection.
    public let exclusionLimit: Int

    /// Optional candidate freshness boundary applied by this projection.
    public let updatedAfter: Date?

    /// Latest accepted event-ledger sequence evaluated by the projection.
    public let sourceEvidenceWatermark: Int?

    /// Deterministic generation timestamp from accepted evidence.
    public let generatedAt: Date?

    /// Creates related-session projection metadata.
    public init(
        revisionID: String,
        projectionRuleID: String,
        projectionRuleVersion: String,
        requestFingerprint: String,
        contentFingerprint: String,
        resultLimit: Int,
        exclusionLimit: Int,
        updatedAfter: Date?,
        sourceEvidenceWatermark: Int?,
        generatedAt: Date?
    ) {
        self.revisionID = revisionID
        self.projectionRuleID = projectionRuleID
        self.projectionRuleVersion = projectionRuleVersion
        self.requestFingerprint = requestFingerprint
        self.contentFingerprint = contentFingerprint
        self.resultLimit = resultLimit
        self.exclusionLimit = exclusionLimit
        self.updatedAfter = updatedAfter
        self.sourceEvidenceWatermark = sourceEvidenceWatermark
        self.generatedAt = generatedAt
    }
}
