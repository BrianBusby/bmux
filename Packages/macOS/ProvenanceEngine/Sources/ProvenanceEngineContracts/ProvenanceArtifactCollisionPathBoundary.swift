/// Path boundary and unsupported path-identity semantics for a candidate.
public struct ProvenanceArtifactCollisionPathBoundary: Codable, Equatable, Sendable {
    /// Observed paths that normalized into the candidate path.
    public let observedPaths: [String]

    /// Deterministically normalized path used for exact comparison.
    public let normalizedPath: String

    /// Path relationship used for candidate discovery.
    public let pathRelationship: String

    /// Repository identity keys that make this path repository-relative for the candidate.
    public let repositoryKeys: [String]

    /// Case-sensitivity rule used by the projection.
    public let caseSensitivity: String

    /// Rename or move support state for this path boundary.
    public let renameRelationship: String

    /// Evidence references supporting the path boundary.
    public let evidence: [ProvenanceArtifactCollisionEvidenceReference]

    /// Creates a path boundary record.
    public init(
        observedPaths: [String],
        normalizedPath: String,
        pathRelationship: String,
        repositoryKeys: [String],
        caseSensitivity: String,
        renameRelationship: String,
        evidence: [ProvenanceArtifactCollisionEvidenceReference]
    ) {
        self.observedPaths = observedPaths
        self.normalizedPath = normalizedPath
        self.pathRelationship = pathRelationship
        self.repositoryKeys = repositoryKeys
        self.caseSensitivity = caseSensitivity
        self.renameRelationship = renameRelationship
        self.evidence = evidence
    }
}
