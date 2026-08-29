extension ProvenanceSQLiteRepository {
    static let sessionOutcomeMigrations = [
        ProvenanceSQLiteMigration(
            version: 22,
            statements: [
                """
                CREATE TABLE provenance_coding_agent_session_outcome_revisions (
                    id TEXT PRIMARY KEY NOT NULL,
                    session_id TEXT NOT NULL,
                    projection_rule_id TEXT NOT NULL,
                    projection_rule_version TEXT NOT NULL,
                    source_watermark_sequence INTEGER,
                    content_fingerprint TEXT NOT NULL,
                    outcome_json TEXT NOT NULL,
                    created_at_seconds REAL
                )
                """,
                """
                CREATE INDEX provenance_coding_agent_session_outcome_revisions_session_index
                ON provenance_coding_agent_session_outcome_revisions (
                    session_id,
                    source_watermark_sequence,
                    created_at_seconds
                )
                """,
                """
                CREATE INDEX provenance_coding_agent_session_outcome_revisions_rule_index
                ON provenance_coding_agent_session_outcome_revisions (
                    projection_rule_id,
                    projection_rule_version,
                    content_fingerprint
                )
                """,
                """
                CREATE TABLE provenance_coding_agent_session_outcomes (
                    session_id TEXT PRIMARY KEY NOT NULL,
                    latest_revision_id TEXT NOT NULL,
                    projection_rule_id TEXT NOT NULL,
                    projection_rule_version TEXT NOT NULL,
                    latest_evaluated_sequence INTEGER,
                    updated_at_seconds REAL
                )
                """,
                """
                CREATE INDEX provenance_coding_agent_session_outcomes_sequence_index
                ON provenance_coding_agent_session_outcomes (
                    latest_evaluated_sequence,
                    updated_at_seconds
                )
                """,
                """
                UPDATE provenance_metadata
                SET value = '22'
                WHERE key = 'schema_version'
                """,
            ]
        ),
    ]
}
