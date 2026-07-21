import Foundation

/// Current-state projection for one Git worktree.
public struct ProvenanceWorktreeRecord: Codable, Equatable, Sendable, Identifiable {
    /// Stable worktree identifier.
    public let id: String

    /// Owning repository identifier.
    public let repositoryID: String

    /// Absolute worktree root path.
    public let path: String

    /// Current branch, when known.
    public let branch: String?

    /// Base commit used by the contribution, when known.
    public let baseCommit: String?

    /// Current HEAD commit, when known.
    public let currentHEAD: String?

    /// Whether a client observed a dirty worktree.
    public let isDirty: Bool

    /// Lifecycle status such as `active`, `paused`, `completed`, or `missing`.
    public let status: String

    /// Last Git/filesystem reconciliation time.
    public let lastReconciledAt: Date?

    /// Last projection update time.
    public let updatedAt: Date

    /// Creates a worktree projection record.
    public init(
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
