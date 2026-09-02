import ProvenanceEngineContracts

extension ProvenanceSQLiteRepository {
    /// Reads internal storage counts for the event ledger and current-state projection tables.
    ///
    /// - Returns: A bounded summary of repository-owned SQLite storage state.
    /// - Throws: ``ProvenanceSQLiteError`` when SQLite rejects one of the reads.
    func storageSummary() throws -> ProvenanceSQLiteStorageSummary {
        let ledgerSummary = try eventLedgerSummary()
        return ProvenanceSQLiteStorageSummary(
            schemaVersion: try schemaVersion(),
            eventCount: ledgerSummary.count,
            latestEventSequence: ledgerSummary.latestSequence,
            repositoryCount: try countRows(in: "provenance_repositories"),
            worktreeCount: try countRows(in: "provenance_worktrees"),
            sessionCount: try countRows(in: "provenance_sessions"),
            sessionRelationshipCount: try countRows(in: "provenance_session_relationships"),
            externalIdentityCount: try countRows(in: "provenance_session_external_identities"),
            workItemCount: try countRows(in: "provenance_work_items"),
            contributionCount: try countRows(in: "provenance_work_contributions"),
            checkpointCount: try countRows(in: "provenance_checkpoints"),
            changeSetCount: try countRows(in: "provenance_change_sets"),
            fileChangeCount: try countRows(in: "provenance_file_changes"),
            validationRunCount: try countRows(in: "provenance_validation_runs"),
            workspaceDisplayCount: try countRows(in: "provenance_workspace_display"),
            workspaceCodingAgentSessionAssociationCount: try countRows(
                in: "provenance_workspace_coding_agent_session_associations"
            ),
            codingAgentThreadCount: try countRows(in: "provenance_coding_agent_threads"),
            codingAgentTurnCount: try countRows(in: "provenance_coding_agent_turns"),
            codingAgentPromptCount: try countRows(in: "provenance_coding_agent_prompts"),
            codingAgentPlanUpdateCount: try countRows(in: "provenance_coding_agent_plan_updates"),
            codingAgentCommandCount: try countRows(in: "provenance_coding_agent_commands"),
            codingAgentReasoningSummaryCount: try countRows(in: "provenance_coding_agent_reasoning_summaries"),
            codingAgentAssistantMessageCount: try countRows(in: "provenance_coding_agent_assistant_messages"),
            codingAgentFileChangeAttributionCount: try countRows(in: "provenance_coding_agent_file_change_attributions"),
            codingAgentTurnOutcomeCount: try countRows(in: "provenance_coding_agent_turn_outcomes"),
            codingAgentTurnOutcomeRevisionCount: try countRows(in: "provenance_coding_agent_turn_outcome_revisions"),
            codingAgentSessionOutcomeCount: try countRows(in: "provenance_coding_agent_session_outcomes"),
            codingAgentSessionOutcomeRevisionCount: try countRows(in: "provenance_coding_agent_session_outcome_revisions"),
            relatedSessionCount: try countRows(in: "provenance_related_sessions"),
            relatedSessionRevisionCount: try countRows(in: "provenance_related_session_revisions"),
            artifactCollisionCount: try countRows(in: "provenance_artifact_collisions"),
            artifactCollisionRevisionCount: try countRows(in: "provenance_artifact_collision_revisions")
        )
    }
}
