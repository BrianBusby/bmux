import Foundation

/// Current-state projection for a coherent batch of file changes.
struct WorkProvenanceChangeSetRecord: Codable, Equatable, Sendable, Identifiable {
    /// Stable change-set identifier.
    let id: String

    /// Checkpoint identifier, when the change set belongs to a checkpoint.
    let checkpointID: String?

    /// Contribution identifier, when attributed.
    let contributionID: String?

    /// Worktree identifier.
    let worktreeID: String

    /// Semantic summary, declared or inferred.
    let summary: String?

    /// Fingerprint of the diff represented by this change set.
    let diffFingerprint: String?

    /// Change-set creation time.
    let createdAt: Date

    /// Creates a change-set projection record.
    init(
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
