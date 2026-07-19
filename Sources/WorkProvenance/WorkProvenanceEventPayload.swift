import Foundation

/// Projection payload attached to a ``WorkProvenanceEvent``.
struct WorkProvenanceEventPayload: Codable, Equatable, Sendable {
    /// Repository projection update.
    var repository: WorkProvenanceRepositoryRecord?

    /// Worktree projection update.
    var worktree: WorkProvenanceWorktreeRecord?

    /// Session projection update.
    var session: WorkProvenanceSessionRecord?

    /// Session relationship projection update.
    var sessionRelationship: WorkProvenanceSessionRelationshipRecord?

    /// External identity projection updates.
    var externalIdentities: [WorkProvenanceExternalIdentityRecord]

    /// Work item projection update.
    var workItem: WorkProvenanceWorkItemRecord?

    /// Work contribution projection update.
    var contribution: WorkProvenanceContributionRecord?

    /// Checkpoint projection update.
    var checkpoint: WorkProvenanceCheckpointRecord?

    /// Change-set projection update.
    var changeSet: WorkProvenanceChangeSetRecord?

    /// File-change projection updates.
    var fileChanges: [WorkProvenanceFileChangeRecord]

    /// Validation-run projection update.
    var validationRun: WorkProvenanceValidationRunRecord?

    /// Creates an event payload.
    init(
        repository: WorkProvenanceRepositoryRecord? = nil,
        worktree: WorkProvenanceWorktreeRecord? = nil,
        session: WorkProvenanceSessionRecord? = nil,
        sessionRelationship: WorkProvenanceSessionRelationshipRecord? = nil,
        externalIdentities: [WorkProvenanceExternalIdentityRecord] = [],
        workItem: WorkProvenanceWorkItemRecord? = nil,
        contribution: WorkProvenanceContributionRecord? = nil,
        checkpoint: WorkProvenanceCheckpointRecord? = nil,
        changeSet: WorkProvenanceChangeSetRecord? = nil,
        fileChanges: [WorkProvenanceFileChangeRecord] = [],
        validationRun: WorkProvenanceValidationRunRecord? = nil
    ) {
        self.repository = repository
        self.worktree = worktree
        self.session = session
        self.sessionRelationship = sessionRelationship
        self.externalIdentities = externalIdentities
        self.workItem = workItem
        self.contribution = contribution
        self.checkpoint = checkpoint
        self.changeSet = changeSet
        self.fileChanges = fileChanges
        self.validationRun = validationRun
    }
}
