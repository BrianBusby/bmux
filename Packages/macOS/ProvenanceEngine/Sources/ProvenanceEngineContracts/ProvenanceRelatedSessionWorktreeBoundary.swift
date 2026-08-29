import Foundation

/// Repository, worktree, branch, and HEAD boundary used by a related-session brief.
public struct ProvenanceRelatedSessionWorktreeBoundary: Codable, Equatable, Sendable {
    /// Stable boundary identifier.
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

    /// Accepted evidence or projection references supporting this boundary.
    public let evidence: [ProvenanceRelatedSessionEvidenceReference]

    /// Creates a related-session worktree boundary.
    public init(
        id: String,
        repositoryID: String?,
        repositoryPath: String?,
        worktreeID: String?,
        worktreePath: String?,
        branch: String?,
        head: String?,
        cwd: String?,
        evidence: [ProvenanceRelatedSessionEvidenceReference]
    ) {
        self.id = id
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
