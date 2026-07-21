import Foundation

/// Domain entry returned by a provenance worktree-list query.
struct ProvenanceWorktreeListEntry: Codable, Equatable, Sendable {
    /// Worktree projection included in the list.
    let worktree: WorkProvenanceWorktreeRecord

    /// Repository projection linked to the worktree, when available.
    let repository: WorkProvenanceRepositoryRecord?

    /// Creates a worktree-list entry.
    init(
        worktree: WorkProvenanceWorktreeRecord,
        repository: WorkProvenanceRepositoryRecord?
    ) {
        self.worktree = worktree
        self.repository = repository
    }
}
