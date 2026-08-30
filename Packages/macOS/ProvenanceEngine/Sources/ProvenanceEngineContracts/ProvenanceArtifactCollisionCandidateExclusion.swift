/// Bounded explanation for a candidate omitted from the collision result set.
public struct ProvenanceArtifactCollisionCandidateExclusion: Codable, Equatable, Sendable {
    /// Related session involved in the omitted candidate, when known.
    public let sessionID: String?

    /// Observed artifact path involved in the omitted candidate, when known.
    public let artifactPath: String?

    /// Normalized artifact path involved in the omitted candidate, when known.
    public let normalizedArtifactPath: String?

    /// Machine-stable omission reason.
    public let reason: String

    /// Evidence references supporting the omission.
    public let evidence: [ProvenanceArtifactCollisionEvidenceReference]

    /// Creates a candidate exclusion record.
    public init(
        sessionID: String? = nil,
        artifactPath: String? = nil,
        normalizedArtifactPath: String? = nil,
        reason: String,
        evidence: [ProvenanceArtifactCollisionEvidenceReference] = []
    ) {
        self.sessionID = sessionID
        self.artifactPath = artifactPath
        self.normalizedArtifactPath = normalizedArtifactPath
        self.reason = reason
        self.evidence = evidence
    }
}
