import Foundation

extension ProvenanceSQLiteRepository {
    /// Rebuilds current-state projections by replaying the immutable event ledger in append order.
    ///
    /// - Parameter batchSize: Maximum number of ledger entries decoded per cursor read.
    /// - Returns: Number of ledger events replayed into projection tables.
    /// - Throws: ``ProvenanceSQLiteError`` when SQLite rejects the rebuild or stored enum data is invalid.
    func rebuildProjectionsFromEventLedger(batchSize: Int = 1_000) throws -> Int {
        let rowLimit = max(1, batchSize)
        var afterSequence: Int?
        var replayedCount = 0

        try database.execute("BEGIN IMMEDIATE TRANSACTION")
        do {
            try clearProjectionTables()
            while true {
                let entries = try eventLedgerEntries(afterSequence: afterSequence, limit: rowLimit)
                guard !entries.isEmpty else { break }

                for entry in entries {
                    try autoreleasepool {
                        try applyProjectionUpdates(
                            from: entry.event,
                            latestEventSequence: entry.sequence,
                            pruneOutcomes: false
                        )
                    }
#if DEBUG
                    try replayProgressForTesting?()
#endif
                    afterSequence = entry.sequence
                    replayedCount += 1
                }

                guard entries.count == rowLimit else { break }
            }
            // All cross-projection citations are present only after the complete replay.
            // Pruning during replay could retire a revision cited by a later event.
            if try schemaVersion() >= 29 {
                try database.execute(
                    "UPDATE provenance_outcome_retention_state SET legacy_citations_indexed = 1 WHERE policy_version = 1"
                )
            }
            try database.execute("COMMIT")
        } catch {
            try? database.execute("ROLLBACK")
            throw error
        }

        if try schemaVersion() >= 29 {
            while try pruneOutcomePayloads(dryRun: false, batchSize: 1_000).prunedRows > 0 {}
        }
        return replayedCount
    }

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
