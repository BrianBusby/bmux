/// Deterministic repository, worktree, branch, and HEAD comparison for a candidate.
public struct ProvenanceArtifactCollisionBoundaryComparison: Codable, Equatable, Sendable {
    /// Repository relationship, such as `shared_repository` or `missing_repository_evidence`.
    public let repositoryRelationship: String

    /// Worktree relationship, such as `same_worktree`, `different_worktrees`, or `unknown_worktree`.
    public let worktreeRelationship: String

    /// Branch relationship, such as `same_branch`, `different_branches`, or `unknown_branch`.
    public let branchRelationship: String

    /// HEAD relationship, such as `same_head`, `divergent_head`, or `unknown_head`.
    public let headRelationship: String

    /// Shared repository identity keys that bounded candidate discovery.
    public let sharedRepositoryKeys: [String]

    /// Distinct observed worktree identifiers across participants.
    public let worktreeIDs: [String]

    /// Distinct observed worktree paths across participants.
    public let worktreePaths: [String]

    /// Distinct observed branch names across participants.
    public let branches: [String]

    /// Distinct observed HEAD values across participants.
    public let heads: [String]

    /// Evidence references supporting the boundary comparison.
    public let evidence: [ProvenanceArtifactCollisionEvidenceReference]

    /// Creates a boundary comparison record.
    public init(
        repositoryRelationship: String,
        worktreeRelationship: String,
        branchRelationship: String,
        headRelationship: String,
        sharedRepositoryKeys: [String],
        worktreeIDs: [String],
        worktreePaths: [String],
        branches: [String],
        heads: [String],
        evidence: [ProvenanceArtifactCollisionEvidenceReference]
    ) {
        self.repositoryRelationship = repositoryRelationship
        self.worktreeRelationship = worktreeRelationship
        self.branchRelationship = branchRelationship
        self.headRelationship = headRelationship
        self.sharedRepositoryKeys = sharedRepositoryKeys
        self.worktreeIDs = worktreeIDs
        self.worktreePaths = worktreePaths
        self.branches = branches
        self.heads = heads
        self.evidence = evidence
    }
}
