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

    private enum CodingKeys: String, CodingKey {
        case repository
        case worktree
        case session
        case sessionRelationship
        case externalIdentities
        case workItem
        case contribution
        case checkpoint
        case changeSet
        case fileChanges
        case validationRun
    }

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

    /// Creates an event payload from stored JSON, preserving compatibility with older payload shapes.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.repository = try container.decodeIfPresent(WorkProvenanceRepositoryRecord.self, forKey: .repository)
        self.worktree = try container.decodeIfPresent(WorkProvenanceWorktreeRecord.self, forKey: .worktree)
        self.session = try container.decodeIfPresent(WorkProvenanceSessionRecord.self, forKey: .session)
        self.sessionRelationship = try container.decodeIfPresent(
            WorkProvenanceSessionRelationshipRecord.self,
            forKey: .sessionRelationship
        )
        self.externalIdentities = try container.decodeIfPresent(
            [WorkProvenanceExternalIdentityRecord].self,
            forKey: .externalIdentities
        ) ?? []
        self.workItem = try container.decodeIfPresent(WorkProvenanceWorkItemRecord.self, forKey: .workItem)
        self.contribution = try container.decodeIfPresent(WorkProvenanceContributionRecord.self, forKey: .contribution)
        self.checkpoint = try container.decodeIfPresent(WorkProvenanceCheckpointRecord.self, forKey: .checkpoint)
        self.changeSet = try container.decodeIfPresent(WorkProvenanceChangeSetRecord.self, forKey: .changeSet)
        self.fileChanges = try container.decodeIfPresent(
            [WorkProvenanceFileChangeRecord].self,
            forKey: .fileChanges
        ) ?? []
        self.validationRun = try container.decodeIfPresent(
            WorkProvenanceValidationRunRecord.self,
            forKey: .validationRun
        )
    }
}
