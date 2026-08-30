/// Response for a PE artifact-collision awareness read.
public struct ProvenanceArtifactCollisionResponse: Codable, Equatable, Sendable {
    /// Schema version for this response shape.
    public let schemaVersion: Int

    /// Whether the target session or requested revision was found.
    public let found: Bool

    /// Machine-stable reason when `found` is false.
    public let reason: String?

    /// Provenance session identifier used as the collision-awareness target.
    public let targetSessionID: String

    /// Deterministic collision-awareness projection, when available.
    public let projection: ProvenanceArtifactCollisionProjection?

    /// Creates an artifact-collision response.
    public init(
        schemaVersion: Int = 1,
        found: Bool,
        reason: String? = nil,
        targetSessionID: String,
        projection: ProvenanceArtifactCollisionProjection? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.found = found
        self.reason = reason
        self.targetSessionID = targetSessionID
        self.projection = projection
    }
}
