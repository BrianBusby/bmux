import Foundation

/// Current-state projection for one file inside a change set.
public struct ProvenanceFileChangeRecord: Codable, Equatable, Sendable, Identifiable {
    /// Stable file-change identifier.
    public let id: String

    /// Owning change-set identifier.
    public let changeSetID: String

    /// Repository identifier.
    public let repositoryID: String

    /// Worktree identifier.
    public let worktreeID: String

    /// Repository-relative file path.
    public let path: String

    /// File status such as `modified`, `added`, `deleted`, `renamed`, or `untracked`.
    public let status: String

    /// Hash before the change, when known.
    public let beforeHash: String?

    /// Hash after the change, when known.
    public let afterHash: String?

    /// Evidence class behind this file attribution.
    public let attributionSource: ProvenanceSource

    /// Confidence in this file attribution.
    public let attributionConfidence: ProvenanceConfidence

    /// Last projection update time.
    public let updatedAt: Date

    /// Creates a file-change projection record.
    public init(
        id: String,
        changeSetID: String,
        repositoryID: String,
        worktreeID: String,
        path: String,
        status: String,
        beforeHash: String? = nil,
        afterHash: String? = nil,
        attributionSource: ProvenanceSource,
        attributionConfidence: ProvenanceConfidence,
        updatedAt: Date
    ) {
        self.id = id
        self.changeSetID = changeSetID
        self.repositoryID = repositoryID
        self.worktreeID = worktreeID
        self.path = path
        self.status = status
        self.beforeHash = beforeHash
        self.afterHash = afterHash
        self.attributionSource = attributionSource
        self.attributionConfidence = attributionConfidence
        self.updatedAt = updatedAt
    }
}
