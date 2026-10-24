import Foundation

/// A workspace's retained PE sessions; capture can be partial.
public struct ProvenanceWorkspaceSessionPageResponse: Codable, Equatable, Sendable {
    /// Response shape version.
    public let schemaVersion: Int
    /// Restart-stable workspace ID queried by the caller.
    public let workspaceID: String
    /// Unique linked sessions in most recent meaningful activity order.
    public let sessions: [ProvenanceWorkspaceSessionSummary]
    /// Continuation token for the next page, if any.
    public let nextCursor: String?
    /// Unique linked sessions across all pages, when supplied by the reader.
    public let totalCount: Int?
    /// True because PE only returns linked, observed work evidence; capture may omit unobserved activity.
    public let partialCoverage: Bool

    /// Creates a page of linked sessions and its coverage signal.
    ///
    /// - Parameters:
    ///   - schemaVersion: Response shape version.
    ///   - workspaceID: Restart-stable workspace ID.
    ///   - sessions: Linked sessions in activity order.
    ///   - nextCursor: Continuation token for another page.
    ///   - totalCount: Unique linked sessions across all pages, when known.
    ///   - partialCoverage: Whether capture can omit unobserved sessions.
    public init(
        schemaVersion: Int = 1,
        workspaceID: String,
        sessions: [ProvenanceWorkspaceSessionSummary],
        nextCursor: String?,
        totalCount: Int? = nil,
        partialCoverage: Bool = true
    ) {
        self.schemaVersion = schemaVersion
        self.workspaceID = workspaceID
        self.sessions = sessions
        self.nextCursor = nextCursor
        self.totalCount = totalCount
        self.partialCoverage = partialCoverage
    }
}
