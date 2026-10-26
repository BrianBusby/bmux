import Foundation

extension ProvenanceSQLiteRepository {
    func clearProjectionTables() throws {
        for tableName in Self.artifactCollisionProjectionTableNames + Self.relatedSessionProjectionTableNames + [
            "provenance_outcome_revision_citations",
            "provenance_legacy_outcome_revision_ids",
            "provenance_coding_agent_session_outcomes",
            "provenance_coding_agent_session_outcome_revisions",
            "provenance_coding_agent_turn_outcomes",
            "provenance_coding_agent_turn_outcome_revisions",
            "provenance_coding_agent_file_change_attributions",
            "provenance_coding_agent_assistant_messages",
            "provenance_coding_agent_reasoning_summaries",
            "provenance_coding_agent_commands",
            "provenance_coding_agent_plan_updates",
            "provenance_coding_agent_prompts",
            "provenance_coding_agent_turns",
            "provenance_coding_agent_threads",
            "provenance_workspace_coding_agent_session_associations",
            "provenance_workspace_display",
            "provenance_validation_runs",
            "provenance_file_changes",
            "provenance_change_sets",
            "provenance_checkpoints",
            "provenance_work_contributions",
            "provenance_work_items",
            "provenance_session_external_identities",
            "provenance_session_relationships",
            "provenance_sessions",
            "provenance_worktrees",
            "provenance_repositories",
        ] {
            try database.execute("DELETE FROM \(tableName)")
        }
    }

}
