/// Repository and worktree boundary observed for a turn outcome or validation.
public struct ProvenanceTurnOutcomeRepositoryBoundary: Codable, Equatable, Sendable {
    /// Repository projection identifier, when observed.
    public let repositoryID: String?

    /// Repository root path, when observed.
    public let repositoryPath: String?

    /// Worktree projection identifier, when observed.
    public let worktreeID: String?

    /// Worktree path, when observed.
    public let worktreePath: String?

    /// Branch name, when observed.
    public let branch: String?

    /// Observed HEAD or commit boundary, when present.
    public let head: String?

    /// Command/session working directory, when observed.
    public let cwd: String?

    /// Supporting evidence references for the boundary.
    public let evidence: [ProvenanceTurnOutcomeEvidenceReference]

    /// Creates a repository-boundary fact.
    public init(
        repositoryID: String?,
        repositoryPath: String?,
        worktreeID: String?,
        worktreePath: String?,
        branch: String?,
        head: String?,
        cwd: String?,
        evidence: [ProvenanceTurnOutcomeEvidenceReference]
    ) {
        self.repositoryID = repositoryID
        self.repositoryPath = repositoryPath
        self.worktreeID = worktreeID
        self.worktreePath = worktreePath
        self.branch = branch
        self.head = head
        self.cwd = cwd
        self.evidence = evidence
    }
}
