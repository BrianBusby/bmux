import Foundation

/// Focused provenance context for one changed file.
struct WorkProvenanceFileExplanation: Equatable, Sendable {
    /// File-change record that matched the query.
    let fileChange: WorkProvenanceFileChangeRecord

    /// Change set containing the file change, when available.
    let changeSet: WorkProvenanceChangeSetRecord?

    /// Checkpoint containing the change set, when available.
    let checkpoint: WorkProvenanceCheckpointRecord?

    /// Contribution that produced the change, when attributed.
    let contribution: WorkProvenanceContributionRecord?

    /// Session that produced the contribution, when attributed.
    let session: WorkProvenanceSessionRecord?

    /// Work item the contribution belongs to, when attributed.
    let workItem: WorkProvenanceWorkItemRecord?

    /// Worktree containing the file change.
    let worktree: WorkProvenanceWorktreeRecord?

    /// Repository containing the worktree.
    let repository: WorkProvenanceRepositoryRecord?

    /// Creates a file explanation result.
    init(
        fileChange: WorkProvenanceFileChangeRecord,
        changeSet: WorkProvenanceChangeSetRecord?,
        checkpoint: WorkProvenanceCheckpointRecord?,
        contribution: WorkProvenanceContributionRecord?,
        session: WorkProvenanceSessionRecord?,
        workItem: WorkProvenanceWorkItemRecord?,
        worktree: WorkProvenanceWorktreeRecord?,
        repository: WorkProvenanceRepositoryRecord?
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
