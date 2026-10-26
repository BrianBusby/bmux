import Foundation

/// Bounded lookup of workspaces with retained coding-agent sessions.
public struct ProvenanceWorkspaceHistoryPageRequest: Codable, Equatable, Sendable {
    /// Maximum workspace summaries requested; implementations clamp this to 1...500.
    public let limit: Int
    /// Continuation token returned by the preceding page, if any.
    public let cursor: String?

    /// Creates a page request for retained workspace session history.
    ///
    /// - Parameters:
    ///   - limit: Requested page size.
    ///   - cursor: Token returned by the preceding page.
    public init(limit: Int = 500, cursor: String? = nil) {
        self.limit = limit
        self.cursor = cursor
    }
}
