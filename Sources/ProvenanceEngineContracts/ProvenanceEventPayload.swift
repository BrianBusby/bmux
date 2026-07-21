import Foundation

/// Projection payload attached to a ``ProvenanceEvent``.
public struct ProvenanceEventPayload: Codable, Equatable, Sendable {
    /// Repository projection update.
    public var repository: ProvenanceRepositoryRecord?

    /// Worktree projection update.
    public var worktree: ProvenanceWorktreeRecord?

    /// Session projection update.
    public var session: ProvenanceSessionRecord?

    /// Session relationship projection update.
    public var sessionRelationship: ProvenanceSessionRelationshipRecord?

    /// External identity projection updates.
    public var externalIdentities: [ProvenanceExternalIdentityRecord]

    /// Work item projection update.
    public var workItem: ProvenanceWorkItemRecord?

    /// Work contribution projection update.
    public var contribution: ProvenanceContributionRecord?

    /// Checkpoint projection update.
    public var checkpoint: ProvenanceCheckpointRecord?

    /// Change-set projection update.
    public var changeSet: ProvenanceChangeSetRecord?

    /// File-change projection updates.
    public var fileChanges: [ProvenanceFileChangeRecord]

    /// Validation-run projection update.
    public var validationRun: ProvenanceValidationRunRecord?

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
    public init(
        repository: ProvenanceRepositoryRecord? = nil,
        worktree: ProvenanceWorktreeRecord? = nil,
        session: ProvenanceSessionRecord? = nil,
        sessionRelationship: ProvenanceSessionRelationshipRecord? = nil,
        externalIdentities: [ProvenanceExternalIdentityRecord] = [],
        workItem: ProvenanceWorkItemRecord? = nil,
        contribution: ProvenanceContributionRecord? = nil,
        checkpoint: ProvenanceCheckpointRecord? = nil,
        changeSet: ProvenanceChangeSetRecord? = nil,
        fileChanges: [ProvenanceFileChangeRecord] = [],
        validationRun: ProvenanceValidationRunRecord? = nil
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
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.repository = try container.decodeIfPresent(ProvenanceRepositoryRecord.self, forKey: .repository)
        self.worktree = try container.decodeIfPresent(ProvenanceWorktreeRecord.self, forKey: .worktree)
        self.session = try container.decodeIfPresent(ProvenanceSessionRecord.self, forKey: .session)
        self.sessionRelationship = try container.decodeIfPresent(
            ProvenanceSessionRelationshipRecord.self,
            forKey: .sessionRelationship
        )
        self.externalIdentities = try container.decodeIfPresent(
            [ProvenanceExternalIdentityRecord].self,
            forKey: .externalIdentities
        ) ?? []
        self.workItem = try container.decodeIfPresent(ProvenanceWorkItemRecord.self, forKey: .workItem)
        self.contribution = try container.decodeIfPresent(ProvenanceContributionRecord.self, forKey: .contribution)
        self.checkpoint = try container.decodeIfPresent(ProvenanceCheckpointRecord.self, forKey: .checkpoint)
        self.changeSet = try container.decodeIfPresent(ProvenanceChangeSetRecord.self, forKey: .changeSet)
        self.fileChanges = try container.decodeIfPresent(
            [ProvenanceFileChangeRecord].self,
            forKey: .fileChanges
        ) ?? []
        self.validationRun = try container.decodeIfPresent(
            ProvenanceValidationRunRecord.self,
            forKey: .validationRun
        )
    }
}
