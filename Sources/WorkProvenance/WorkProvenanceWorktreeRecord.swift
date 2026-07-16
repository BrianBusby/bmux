import Foundation

/// Current-state projection for one Git worktree.
struct WorkProvenanceWorktreeRecord: Codable, Equatable, Sendable, Identifiable {
    /// Stable worktree identifier.
    let id: String

    /// Owning repository identifier.
    let repositoryID: String

    /// Absolute worktree root path.
    let path: String

    /// Current branch, when known.
    let branch: String?

    /// Base commit used by the contribution, when known.
    let baseCommit: String?

    /// Current HEAD commit, when known.
    let currentHEAD: String?

    /// Whether bmux observed a dirty worktree.
    let isDirty: Bool

    /// Lifecycle status such as `active`, `paused`, `completed`, or `missing`.
    let status: String

    /// Last Git/filesystem reconciliation time.
    let lastReconciledAt: Date?

    /// Last projection update time.
    let updatedAt: Date

    /// Creates a worktree projection record.
    init(
        id: String,
        repositoryID: String,
        path: String,
        branch: String? = nil,
        baseCommit: String? = nil,
        currentHEAD: String? = nil,
        isDirty: Bool,
        status: String,
        lastReconciledAt: Date? = nil,
        updatedAt: Date
    ) {
        self.id = id
        self.repositoryID = repositoryID
        self.path = path
        self.branch = branch
        self.baseCommit = baseCommit
        self.currentHEAD = currentHEAD
        self.isDirty = isDirty
        self.status = status
        self.lastReconciledAt = lastReconciledAt
        self.updatedAt = updatedAt
    }
}
