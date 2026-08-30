import Foundation

/// Query parameters for PE-owned artifact and change collision awareness.
public struct ProvenanceArtifactCollisionRequest: Codable, Equatable, Sendable {
    /// Provenance session identifier used as the collision-awareness target.
    public let targetSessionID: String

    /// Maximum number of collision candidates to return.
    public let limit: Int

    /// Optional observed path filter. The projection applies deterministic path normalization.
    public let artifactPath: String?

    /// Optional lower bound for candidate latest artifact observation.
    public let updatedAfter: Date?

    /// Optional boundary used to classify stale candidates without omitting them.
    public let staleBefore: Date?

    /// Exact historical artifact-collision projection revision to read.
    public let revisionID: String?

    /// Maximum number of related-session briefs to evaluate before artifact candidate discovery.
    public let relatedSessionLimit: Int

    /// Maximum number of excluded candidates to explain.
    public let exclusionLimit: Int

    /// Creates an artifact-collision query request.
    public init(
        targetSessionID: String,
        limit: Int = 10,
        artifactPath: String? = nil,
        updatedAfter: Date? = nil,
        staleBefore: Date? = nil,
        revisionID: String? = nil,
        relatedSessionLimit: Int = 50,
        exclusionLimit: Int = 10
    ) {
        self.targetSessionID = targetSessionID
        self.limit = limit
        self.artifactPath = artifactPath
        self.updatedAfter = updatedAfter
        self.staleBefore = staleBefore
        self.revisionID = revisionID
        self.relatedSessionLimit = relatedSessionLimit
        self.exclusionLimit = exclusionLimit
    }
}
