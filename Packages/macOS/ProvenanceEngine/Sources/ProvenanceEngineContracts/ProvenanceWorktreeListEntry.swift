import Foundation

/// Domain entry returned by a provenance worktree-list query.
public struct ProvenanceWorktreeListEntry: Codable, Equatable, Sendable {
    /// Worktree projection included in the list.
    public let worktree: ProvenanceWorktreeRecord

    /// Repository projection linked to the worktree, when available.
    public let repository: ProvenanceRepositoryRecord?

    /// Creates a worktree-list entry.
    public init(worktree: ProvenanceWorktreeRecord, repository: ProvenanceRepositoryRecord?) {
        self.worktree = worktree
        self.repository = repository
    }
}
