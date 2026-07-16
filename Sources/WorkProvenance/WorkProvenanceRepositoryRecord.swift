import Foundation

/// Current-state projection for one Git repository.
struct WorkProvenanceRepositoryRecord: Codable, Equatable, Sendable, Identifiable {
    /// Stable repository identifier.
    let id: String

    /// Absolute working-tree path most recently observed for the repository.
    let path: String

    /// Absolute Git common directory, when known.
    let commonDirectory: String?

    /// Preferred remote slug such as `owner/name`, when known.
    let remoteSlug: String?

    /// First observed time.
    let createdAt: Date

    /// Last projection update time.
    let updatedAt: Date

    /// Creates a repository projection record.
    init(
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
