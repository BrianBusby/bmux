import Foundation

/// Bounded history lookup by the restart-stable workspace ID.
public struct ProvenanceWorkspaceSessionPageRequest: Codable, Equatable, Sendable {
    /// Restart-stable workspace identity used by PE display and session links.
    public let workspaceID: String
    /// Maximum sessions requested; implementations clamp this to 1...500.
    public let limit: Int
    /// Continuation token returned by the preceding page, if any.
    public let cursor: String?

    /// Creates a bounded query for one workspace's retained sessions.
    ///
    /// - Parameters:
    ///   - workspaceID: Restart-stable workspace ID.
    ///   - limit: Requested page size, clamped to 1...500 by the engine.
    ///   - cursor: Token returned by the preceding page.
    public init(workspaceID: String, limit: Int = 50, cursor: String? = nil) {
        self.workspaceID = workspaceID
        self.limit = limit
        self.cursor = cursor
    }
}
