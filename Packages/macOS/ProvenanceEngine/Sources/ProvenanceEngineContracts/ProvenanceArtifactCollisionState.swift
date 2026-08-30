/// Factual state assigned to an artifact-collision candidate.
public enum ProvenanceArtifactCollisionState: String, Codable, Equatable, Sendable, CaseIterable {
    /// At least one participating session remains active or incomplete.
    case current

    /// All known participants are completed, failed, cancelled, interrupted, or unknown.
    case historical

    /// Required evidence is partial or unavailable.
    case incomplete

    /// Latest artifact observation is older than the request's stale boundary.
    case stale
}
