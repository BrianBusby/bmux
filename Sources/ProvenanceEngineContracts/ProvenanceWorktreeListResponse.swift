import Foundation

/// Domain response for a provenance worktree-list query.
public struct ProvenanceWorktreeListResponse: Codable, Equatable, Sendable {
    /// Schema version for this response shape.
    public let schemaVersion: Int

    /// Status for the list query.
    public let status: String

    /// Optional stable reason code when the list is unavailable.
    public let reason: String?

    /// Worktrees included in query order.
    public let worktrees: [ProvenanceWorktreeListEntry]

    /// Creates a worktree-list response.
    public init(
        schemaVersion: Int = 1,
        status: String = "ok",
        reason: String? = nil,
        worktrees: [ProvenanceWorktreeListEntry]
    ) {
        self.schemaVersion = schemaVersion
        self.status = status
        self.reason = reason
        self.worktrees = worktrees
    }
}
