extension ProvenanceSQLiteRepository {
    static let outcomeRetentionMigrations = [
        ProvenanceSQLiteMigration(
            version: 29,
            statements: [
                """
                CREATE TABLE provenance_outcome_retention_state (
                    policy_version INTEGER PRIMARY KEY NOT NULL,
                    legacy_event_watermark INTEGER NOT NULL,
                    legacy_citations_indexed INTEGER NOT NULL DEFAULT 0
                )
                """,
                """
                INSERT INTO provenance_outcome_retention_state (policy_version, legacy_event_watermark)
                SELECT 1, COALESCE(MAX(sequence), 0) FROM provenance_events
                """,
                """
                CREATE TABLE provenance_outcome_revision_citations (
                    source_revision_id TEXT NOT NULL,
                    target_revision_id TEXT NOT NULL,
                    PRIMARY KEY (source_revision_id, target_revision_id)
                )
                """,
                """
                CREATE INDEX provenance_outcome_revision_citations_target_index
                ON provenance_outcome_revision_citations (target_revision_id)
                """,
                """
                CREATE TABLE provenance_outcome_revision_pins (
                    revision_id TEXT PRIMARY KEY NOT NULL,
                    reason TEXT NOT NULL,
                    pinned_at_seconds REAL NOT NULL
                )
                """,
                """
                CREATE TABLE provenance_legacy_outcome_revision_ids (
                    revision_id TEXT PRIMARY KEY NOT NULL
                )
                """,
                """
                INSERT INTO provenance_legacy_outcome_revision_ids (revision_id)
                SELECT id FROM provenance_coding_agent_session_outcome_revisions
                UNION SELECT id FROM provenance_coding_agent_turn_outcome_revisions
                """,
                """
                UPDATE provenance_metadata SET value = '29' WHERE key = 'schema_version'
                """,
            ]
        ),
    ]
}
