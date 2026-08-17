import Foundation

/// Focused provenance context for one changed file.
public struct ProvenanceFileExplanation: Codable, Equatable, Sendable {
    /// File-change record that matched the query.
    public let fileChange: ProvenanceFileChangeRecord

    /// Change set containing the file change, when available.
    public let changeSet: ProvenanceChangeSetRecord?

    /// Checkpoint containing the change set, when available.
    public let checkpoint: ProvenanceCheckpointRecord?

    /// Contribution that produced the change, when attributed.
    public let contribution: ProvenanceContributionRecord?

    /// Session that produced the contribution, when attributed.
    public let session: ProvenanceSessionRecord?

    /// Work item the contribution belongs to, when attributed.
    public let workItem: ProvenanceWorkItemRecord?

    /// Worktree containing the file change.
    public let worktree: ProvenanceWorktreeRecord?

    /// Repository containing the worktree.
    public let repository: ProvenanceRepositoryRecord?

    /// Creates a file explanation result.
    public init(
        fileChange: ProvenanceFileChangeRecord,
        changeSet: ProvenanceChangeSetRecord?,
        checkpoint: ProvenanceCheckpointRecord?,
        contribution: ProvenanceContributionRecord?,
        session: ProvenanceSessionRecord?,
        workItem: ProvenanceWorkItemRecord?,
        worktree: ProvenanceWorktreeRecord?,
        repository: ProvenanceRepositoryRecord?
    ) {
        self.fileChange = fileChange
        self.changeSet = changeSet
        self.checkpoint = checkpoint
        self.contribution = contribution
        self.session = session
        self.workItem = workItem
        self.worktree = worktree
        self.repository = repository
    }
}
