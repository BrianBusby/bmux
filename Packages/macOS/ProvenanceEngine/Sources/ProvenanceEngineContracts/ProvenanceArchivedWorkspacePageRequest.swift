import Foundation

/// Bounded, newest-first archived-workspace query.
public struct ProvenanceArchivedWorkspacePageRequest: Codable, Equatable, Sendable {
    /// Maximum records returned; implementations clamp to 1...500.
    public let limit: Int
    /// Opaque cursor returned by the preceding page, or nil for the first page.
    public let cursor: String?

    /// Creates a page query. The default page size is suitable for the Explorer.
    public init(limit: Int = 100, cursor: String? = nil) {
        self.limit = limit
        self.cursor = cursor
    }
}
