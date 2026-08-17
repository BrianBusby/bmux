import Foundation

/// Current-state projection for a coherent batch of file changes.
public struct ProvenanceChangeSetRecord: Codable, Equatable, Sendable, Identifiable {
    /// Stable change-set identifier.
    public let id: String

    /// Checkpoint identifier, when the change set belongs to a checkpoint.
    public let checkpointID: String?

    /// Contribution identifier, when attributed.
    public let contributionID: String?

    /// Worktree identifier.
    public let worktreeID: String

    /// Semantic summary, declared or inferred.
    public let summary: String?

    /// Fingerprint of the diff represented by this change set.
    public let diffFingerprint: String?

    /// Change-set creation time.
    public let createdAt: Date

    /// Creates a change-set projection record.
    public init(
        id: String,
        checkpointID: String? = nil,
        contributionID: String? = nil,
        worktreeID: String,
        summary: String? = nil,
        diffFingerprint: String? = nil,
        createdAt: Date
    ) {
        self.id = id
        self.checkpointID = checkpointID
        self.contributionID = contributionID
        self.worktreeID = worktreeID
        self.summary = summary
        self.diffFingerprint = diffFingerprint
        self.createdAt = createdAt
    }
}
