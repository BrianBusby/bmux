import Foundation

/// Point-in-time Git state for one worktree.
struct WorkProvenanceGitSnapshot: Equatable, Sendable {
    /// Absolute worktree root path.
    let repositoryRoot: String

    /// Absolute Git common directory, when known.
    let commonDirectory: String?

    /// Preferred GitHub remote slug, when known.
    let remoteSlug: String?

    /// Current branch name, when known.
    let branch: String?

    /// Current HEAD commit, when known.
    let headCommit: String?

    /// Whether the worktree is dirty.
    let isDirty: Bool

    /// Dirty file entries currently reported by Git.
    let statusEntries: [WorkProvenanceGitStatusEntry]

    /// Creates a Git snapshot.
    init(
        repositoryRoot: String,
        commonDirectory: String? = nil,
        remoteSlug: String? = nil,
        branch: String? = nil,
        headCommit: String? = nil,
        isDirty: Bool,
        statusEntries: [WorkProvenanceGitStatusEntry] = []
    ) {
        self.repositoryRoot = repositoryRoot
        self.commonDirectory = commonDirectory
        self.remoteSlug = remoteSlug
        self.branch = branch
        self.headCommit = headCommit
        self.isDirty = isDirty
        self.statusEntries = statusEntries
    }
}
