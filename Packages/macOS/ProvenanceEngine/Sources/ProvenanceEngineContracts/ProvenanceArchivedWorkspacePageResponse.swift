import Foundation

/// One bounded page of retained closed-workspace identity records.
public struct ProvenanceArchivedWorkspacePageResponse: Codable, Equatable, Sendable {
    /// Schema version of this response shape.
    public let schemaVersion: Int
    /// Records ordered by close time, newest first, then stable ID.
    public let records: [ProvenanceArchivedWorkspaceRecord]
    /// Cursor for the next page, or nil when this query reached the end.
    public let nextCursor: String?

    /// Creates an archive page response.
    public init(schemaVersion: Int = 1, records: [ProvenanceArchivedWorkspaceRecord], nextCursor: String?) {
        self.schemaVersion = schemaVersion
        self.records = records
        self.nextCursor = nextCursor
    }
}
