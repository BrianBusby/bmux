import Foundation

/// Bounded explanation for a candidate session excluded from related-session results.
public struct ProvenanceRelatedSessionCandidateExclusion: Codable, Equatable, Sendable {
    /// Candidate session identifier, when known.
    public let sessionID: String?

    /// Stable exclusion reason code.
    public let reason: String

    /// Evidence or projection references that explain the exclusion.
    public let evidence: [ProvenanceRelatedSessionEvidenceReference]

    /// Creates a candidate exclusion explanation.
    public init(
        sessionID: String?,
        reason: String,
        evidence: [ProvenanceRelatedSessionEvidenceReference]
    ) {
        self.sessionID = sessionID
        self.reason = reason
        self.evidence = evidence
    }
}
