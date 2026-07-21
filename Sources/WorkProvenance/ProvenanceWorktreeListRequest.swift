import Foundation

/// Query parameters for listing provenance worktrees.
struct ProvenanceWorktreeListRequest: Codable, Equatable, Sendable {
    /// Optional repository identifier used to filter returned worktrees.
    let repositoryID: String?

    /// Optional maximum number of worktrees to return.
    let limit: Int?

    /// Creates a worktree-list request.
    init(repositoryID: String? = nil, limit: Int? = nil) {
        self.repositoryID = repositoryID
        self.limit = limit
    }
}
