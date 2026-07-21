import Foundation

/// Query parameters for listing provenance worktrees.
public struct ProvenanceWorktreeListRequest: Codable, Equatable, Sendable {
    /// Optional repository identifier used to filter returned worktrees.
    public let repositoryID: String?

    /// Optional maximum number of worktrees to return.
    public let limit: Int?

    /// Creates a worktree-list request.
    public init(repositoryID: String? = nil, limit: Int? = nil) {
        self.repositoryID = repositoryID
        self.limit = limit
    }
}
