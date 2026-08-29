import Foundation

/// One repository, worktree, branch, and HEAD boundary observed across a session.
public struct ProvenanceSessionOutcomeRepositoryBoundary: Codable, Equatable, Sendable {
    /// Stable session-level boundary identifier.
    public let id: String

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

    /// Turns whose outcomes observed this boundary.
    public let turnIDs: [String]

    /// Turn-outcome revisions whose facts observed this boundary.
    public let turnOutcomeRevisionIDs: [String]

    /// Supporting evidence references for the boundary.
    public let evidence: [ProvenanceTurnOutcomeEvidenceReference]

    /// Creates an aggregated repository-boundary fact.
    public init(
        id: String,
        repositoryID: String?,
        repositoryPath: String?,
        worktreeID: String?,
        worktreePath: String?,
        branch: String?,
        head: String?,
        cwd: String?,
        turnIDs: [String],
        turnOutcomeRevisionIDs: [String],
        evidence: [ProvenanceTurnOutcomeEvidenceReference]
    ) {
        self.id = id
        self.repositoryID = repositoryID
        self.repositoryPath = repositoryPath
        self.worktreeID = worktreeID
        self.worktreePath = worktreePath
        self.branch = branch
        self.head = head
        self.cwd = cwd
        self.turnIDs = turnIDs
        self.turnOutcomeRevisionIDs = turnOutcomeRevisionIDs
        self.evidence = evidence
    }
}
