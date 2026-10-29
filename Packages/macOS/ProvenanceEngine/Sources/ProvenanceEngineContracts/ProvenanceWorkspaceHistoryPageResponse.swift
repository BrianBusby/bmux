import Foundation

/// A page of workspace identities established by retained session evidence.
public struct ProvenanceWorkspaceHistoryPageResponse: Codable, Equatable, Sendable {
    /// Workspace summaries in most recent activity order.
    public let workspaces: [ProvenanceWorkspaceHistorySummary]
    /// Continuation token for another page, if any.
    public let nextCursor: String?

    /// Creates a workspace history page.
    ///
    /// - Parameters:
    ///   - workspaces: Retained workspace summaries.
    ///   - nextCursor: Continuation token for another page.
    public init(workspaces: [ProvenanceWorkspaceHistorySummary], nextCursor: String?) {
        self.workspaces = workspaces
        self.nextCursor = nextCursor
    }
}
