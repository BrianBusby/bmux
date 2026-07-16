import Foundation

/// Current-state projection for one file inside a change set.
struct WorkProvenanceFileChangeRecord: Codable, Equatable, Sendable, Identifiable {
    /// Stable file-change identifier.
    let id: String

    /// Owning change-set identifier.
    let changeSetID: String

    /// Repository identifier.
    let repositoryID: String

    /// Worktree identifier.
    let worktreeID: String

    /// Repository-relative file path.
    let path: String

    /// File status such as `modified`, `added`, `deleted`, `renamed`, or `untracked`.
    let status: String

    /// Hash before the change, when known.
    let beforeHash: String?

    /// Hash after the change, when known.
    let afterHash: String?

    /// Evidence class behind this file attribution.
    let attributionSource: WorkProvenanceSource

    /// Confidence in this file attribution.
    let attributionConfidence: WorkProvenanceConfidence

    /// Last projection update time.
    let updatedAt: Date

    /// Creates a file-change projection record.
    init(
        id: String,
        changeSetID: String,
        repositoryID: String,
        worktreeID: String,
        path: String,
        status: String,
        beforeHash: String? = nil,
        afterHash: String? = nil,
        attributionSource: WorkProvenanceSource,
        attributionConfidence: WorkProvenanceConfidence,
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
