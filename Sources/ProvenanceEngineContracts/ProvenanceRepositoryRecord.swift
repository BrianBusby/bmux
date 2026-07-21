import Foundation

/// Current-state projection for one Git repository.
public struct ProvenanceRepositoryRecord: Codable, Equatable, Sendable, Identifiable {
    /// Stable repository identifier.
    public let id: String

    /// Absolute working-tree path most recently observed for the repository.
    public let path: String

    /// Absolute Git common directory, when known.
    public let commonDirectory: String?

    /// Preferred remote slug such as `owner/name`, when known.
    public let remoteSlug: String?

    /// First observed time.
    public let createdAt: Date

    /// Last projection update time.
    public let updatedAt: Date

    /// Creates a repository projection record.
    public init(
        id: String,
        path: String,
        commonDirectory: String? = nil,
        remoteSlug: String? = nil,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.path = path
        self.commonDirectory = commonDirectory
        self.remoteSlug = remoteSlug
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
