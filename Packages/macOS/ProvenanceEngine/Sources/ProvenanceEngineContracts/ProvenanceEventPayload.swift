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

    /// Workspace display projection update.
    public var workspaceDisplay: ProvenanceWorkspaceDisplayRecord?

    /// Coding-agent thread projection update.
    public var codingAgentThread: ProvenanceCodingAgentThreadRecord?

    /// Coding-agent turn projection update.
    public var codingAgentTurn: ProvenanceCodingAgentTurnRecord?

    /// Submitted coding-agent prompt projection update.
    public var codingAgentPrompt: ProvenanceCodingAgentPromptRecord?

    /// Coding-agent plan update projection update.
    public var codingAgentPlanUpdate: ProvenanceCodingAgentPlanUpdateRecord?

    /// Completed coding-agent command projection update.
    public var codingAgentCommand: ProvenanceCodingAgentCommandRecord?

    /// Completed visible coding-agent reasoning-summary projection update.
    public var codingAgentReasoningSummary: ProvenanceCodingAgentReasoningSummaryRecord?

    /// Completed visible coding-agent assistant-output projection update.
    public var codingAgentAssistantMessage: ProvenanceCodingAgentAssistantMessageRecord?

    /// Coding-agent file-change attribution projection update.
    public var codingAgentFileChangeAttribution: ProvenanceCodingAgentFileChangeAttributionRecord?

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
        case workspaceDisplay
        case codingAgentThread
        case codingAgentTurn
        case codingAgentPrompt
        case codingAgentPlanUpdate
        case codingAgentCommand
        case codingAgentReasoningSummary
        case codingAgentAssistantMessage
        case codingAgentFileChangeAttribution
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
        validationRun: ProvenanceValidationRunRecord? = nil,
        workspaceDisplay: ProvenanceWorkspaceDisplayRecord? = nil,
        codingAgentThread: ProvenanceCodingAgentThreadRecord? = nil,
        codingAgentTurn: ProvenanceCodingAgentTurnRecord? = nil,
        codingAgentPrompt: ProvenanceCodingAgentPromptRecord? = nil,
        codingAgentPlanUpdate: ProvenanceCodingAgentPlanUpdateRecord? = nil,
        codingAgentCommand: ProvenanceCodingAgentCommandRecord? = nil,
        codingAgentReasoningSummary: ProvenanceCodingAgentReasoningSummaryRecord? = nil,
        codingAgentAssistantMessage: ProvenanceCodingAgentAssistantMessageRecord? = nil,
        codingAgentFileChangeAttribution: ProvenanceCodingAgentFileChangeAttributionRecord? = nil
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
        self.workspaceDisplay = workspaceDisplay
        self.codingAgentThread = codingAgentThread
        self.codingAgentTurn = codingAgentTurn
        self.codingAgentPrompt = codingAgentPrompt
        self.codingAgentPlanUpdate = codingAgentPlanUpdate
        self.codingAgentCommand = codingAgentCommand
        self.codingAgentReasoningSummary = codingAgentReasoningSummary
        self.codingAgentAssistantMessage = codingAgentAssistantMessage
        self.codingAgentFileChangeAttribution = codingAgentFileChangeAttribution
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
        self.workspaceDisplay = try container.decodeIfPresent(
            ProvenanceWorkspaceDisplayRecord.self,
            forKey: .workspaceDisplay
        )
        self.codingAgentThread = try container.decodeIfPresent(
            ProvenanceCodingAgentThreadRecord.self,
            forKey: .codingAgentThread
        )
        self.codingAgentTurn = try container.decodeIfPresent(
            ProvenanceCodingAgentTurnRecord.self,
            forKey: .codingAgentTurn
        )
        self.codingAgentPrompt = try container.decodeIfPresent(
            ProvenanceCodingAgentPromptRecord.self,
            forKey: .codingAgentPrompt
        )
        self.codingAgentPlanUpdate = try container.decodeIfPresent(
            ProvenanceCodingAgentPlanUpdateRecord.self,
            forKey: .codingAgentPlanUpdate
        )
        self.codingAgentCommand = try container.decodeIfPresent(
            ProvenanceCodingAgentCommandRecord.self,
            forKey: .codingAgentCommand
        )
        self.codingAgentReasoningSummary = try container.decodeIfPresent(
            ProvenanceCodingAgentReasoningSummaryRecord.self,
            forKey: .codingAgentReasoningSummary
        )
        self.codingAgentAssistantMessage = try container.decodeIfPresent(
            ProvenanceCodingAgentAssistantMessageRecord.self,
            forKey: .codingAgentAssistantMessage
        )
        self.codingAgentFileChangeAttribution = try container.decodeIfPresent(
            ProvenanceCodingAgentFileChangeAttributionRecord.self,
            forKey: .codingAgentFileChangeAttribution
        )
    }
}
