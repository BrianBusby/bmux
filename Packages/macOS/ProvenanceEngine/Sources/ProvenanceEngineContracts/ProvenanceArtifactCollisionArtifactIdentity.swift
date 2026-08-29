/// Artifact identity used by deterministic collision candidate discovery.
public struct ProvenanceArtifactCollisionArtifactIdentity: Codable, Equatable, Sendable {
    /// Stable artifact identity identifier for this projection rule.
    public let id: String

    /// Observed paths that normalized into this candidate identity.
    public let observedPaths: [String]

    /// Deterministically normalized artifact path.
    public let normalizedPath: String

    /// Repository identity keys that bounded the candidate.
    public let repositoryKeys: [String]

    /// Supported path relationship used for this candidate.
    public let relationshipKind: String

    /// Case-sensitivity rule applied to path comparison.
    public let caseSensitivity: String

    /// Rename identity support state.
    public let renameSupport: String

    /// Evidence references supporting this artifact identity.
    public let evidence: [ProvenanceArtifactCollisionEvidenceReference]

    /// Creates an artifact identity record.
    public init(
        id: String,
        observedPaths: [String],
        normalizedPath: String,
        repositoryKeys: [String],
        relationshipKind: String,
        caseSensitivity: String,
        renameSupport: String,
        evidence: [ProvenanceArtifactCollisionEvidenceReference]
    ) {
        self.id = id
        self.observedPaths = observedPaths
        self.normalizedPath = normalizedPath
        self.repositoryKeys = repositoryKeys
        self.relationshipKind = relationshipKind
        self.caseSensitivity = caseSensitivity
        self.renameSupport = renameSupport
        self.evidence = evidence
    }
}
