/// Internal counts for the SQLite event ledger and current-state projection tables.
struct ProvenanceSQLiteStorageSummary: Equatable, Sendable {
    /// Current migrated schema version recorded in SQLite.
    var schemaVersion: Int32

    /// Number of immutable event-ledger rows.
    var eventCount: Int

    /// Latest SQLite append sequence in the event ledger.
    var latestEventSequence: Int?

    /// Number of repository projection rows.
    var repositoryCount: Int

    /// Number of worktree projection rows.
    var worktreeCount: Int

    /// Number of session projection rows.
    var sessionCount: Int

    /// Number of session relationship projection rows.
    var sessionRelationshipCount: Int

    /// Number of external identity projection rows.
    var externalIdentityCount: Int

    /// Number of work-item projection rows.
    var workItemCount: Int

    /// Number of contribution projection rows.
    var contributionCount: Int

    /// Number of checkpoint projection rows.
    var checkpointCount: Int

    /// Number of change-set projection rows.
    var changeSetCount: Int

    /// Number of file-change projection rows.
    var fileChangeCount: Int

    /// Number of validation-run projection rows.
    var validationRunCount: Int

    /// Number of workspace display projection rows.
    var workspaceDisplayCount: Int

    /// Number of workspace coding-agent session association projection rows.
    var workspaceCodingAgentSessionAssociationCount: Int

    /// Number of coding-agent thread projection rows.
    var codingAgentThreadCount: Int

    /// Number of coding-agent turn projection rows.
    var codingAgentTurnCount: Int

    /// Number of coding-agent prompt projection rows.
    var codingAgentPromptCount: Int

    /// Number of coding-agent plan update projection rows.
    var codingAgentPlanUpdateCount: Int

    /// Number of coding-agent command projection rows.
    var codingAgentCommandCount: Int

    /// Number of coding-agent reasoning-summary projection rows.
    var codingAgentReasoningSummaryCount: Int

    /// Number of coding-agent assistant-message projection rows.
    var codingAgentAssistantMessageCount: Int

    /// Number of coding-agent file-change attribution projection rows.
    var codingAgentFileChangeAttributionCount: Int

    /// Number of latest coding-agent turn outcome projection rows.
    var codingAgentTurnOutcomeCount: Int

    /// Number of historical coding-agent turn outcome revision rows.
    var codingAgentTurnOutcomeRevisionCount: Int

    /// Number of latest coding-agent session outcome projection rows.
    var codingAgentSessionOutcomeCount: Int

    /// Number of historical coding-agent session outcome revision rows.
    var codingAgentSessionOutcomeRevisionCount: Int

    /// Number of latest related-session projection rows.
    var relatedSessionCount: Int

    /// Number of historical related-session revision rows.
    var relatedSessionRevisionCount: Int

    /// Number of latest artifact-collision projection rows.
    var artifactCollisionCount: Int

    /// Number of historical artifact-collision revision rows.
    var artifactCollisionRevisionCount: Int

    init(
        schemaVersion: Int32,
        eventCount: Int,
        latestEventSequence: Int? = nil,
        repositoryCount: Int,
        worktreeCount: Int,
        sessionCount: Int,
        sessionRelationshipCount: Int,
        externalIdentityCount: Int,
        workItemCount: Int,
        contributionCount: Int,
        checkpointCount: Int,
        changeSetCount: Int,
        fileChangeCount: Int,
        validationRunCount: Int,
        workspaceDisplayCount: Int,
        workspaceCodingAgentSessionAssociationCount: Int = 0,
        codingAgentThreadCount: Int = 0,
        codingAgentTurnCount: Int = 0,
        codingAgentPromptCount: Int = 0,
        codingAgentPlanUpdateCount: Int = 0,
        codingAgentCommandCount: Int = 0,
        codingAgentReasoningSummaryCount: Int = 0,
        codingAgentAssistantMessageCount: Int = 0,
        codingAgentFileChangeAttributionCount: Int = 0,
        codingAgentTurnOutcomeCount: Int = 0,
        codingAgentTurnOutcomeRevisionCount: Int = 0,
        codingAgentSessionOutcomeCount: Int = 0,
        codingAgentSessionOutcomeRevisionCount: Int = 0,
        relatedSessionCount: Int = 0,
        relatedSessionRevisionCount: Int = 0,
        artifactCollisionCount: Int = 0,
        artifactCollisionRevisionCount: Int = 0
    ) {
        self.schemaVersion = schemaVersion
        self.eventCount = eventCount
        self.latestEventSequence = latestEventSequence
        self.repositoryCount = repositoryCount
        self.worktreeCount = worktreeCount
        self.sessionCount = sessionCount
        self.sessionRelationshipCount = sessionRelationshipCount
        self.externalIdentityCount = externalIdentityCount
        self.workItemCount = workItemCount
        self.contributionCount = contributionCount
        self.checkpointCount = checkpointCount
        self.changeSetCount = changeSetCount
        self.fileChangeCount = fileChangeCount
        self.validationRunCount = validationRunCount
        self.workspaceDisplayCount = workspaceDisplayCount
        self.workspaceCodingAgentSessionAssociationCount = workspaceCodingAgentSessionAssociationCount
        self.codingAgentThreadCount = codingAgentThreadCount
        self.codingAgentTurnCount = codingAgentTurnCount
        self.codingAgentPromptCount = codingAgentPromptCount
        self.codingAgentPlanUpdateCount = codingAgentPlanUpdateCount
        self.codingAgentCommandCount = codingAgentCommandCount
        self.codingAgentReasoningSummaryCount = codingAgentReasoningSummaryCount
        self.codingAgentAssistantMessageCount = codingAgentAssistantMessageCount
        self.codingAgentFileChangeAttributionCount = codingAgentFileChangeAttributionCount
        self.codingAgentTurnOutcomeCount = codingAgentTurnOutcomeCount
        self.codingAgentTurnOutcomeRevisionCount = codingAgentTurnOutcomeRevisionCount
        self.codingAgentSessionOutcomeCount = codingAgentSessionOutcomeCount
        self.codingAgentSessionOutcomeRevisionCount = codingAgentSessionOutcomeRevisionCount
        self.relatedSessionCount = relatedSessionCount
        self.relatedSessionRevisionCount = relatedSessionRevisionCount
        self.artifactCollisionCount = artifactCollisionCount
        self.artifactCollisionRevisionCount = artifactCollisionRevisionCount
    }
}
