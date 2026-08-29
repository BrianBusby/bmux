extension ProvenanceSQLiteRepository {
    static let relatedSessionProjectionTableNames = [
        "provenance_related_sessions",
        "provenance_related_session_revisions",
    ]

    static let relatedSessionMigrations = [
        ProvenanceSQLiteMigration(
            version: 23,
            statements: [
                """
                CREATE TABLE provenance_related_session_revisions (
                    id TEXT PRIMARY KEY NOT NULL,
                    target_session_id TEXT NOT NULL,
                    request_fingerprint TEXT NOT NULL,
                    projection_rule_id TEXT NOT NULL,
                    projection_rule_version TEXT NOT NULL,
                    result_limit INTEGER NOT NULL,
                    exclusion_limit INTEGER NOT NULL,
                    updated_after_seconds REAL,
                    source_watermark_sequence INTEGER,
                    content_fingerprint TEXT NOT NULL,
                    projection_json TEXT NOT NULL,
                    created_at_seconds REAL
                )
                """,
                """
                CREATE INDEX provenance_related_session_revisions_target_index
                ON provenance_related_session_revisions (
                    target_session_id,
                    request_fingerprint,
                    source_watermark_sequence,
                    created_at_seconds
                )
                """,
                """
                CREATE INDEX provenance_related_session_revisions_rule_index
                ON provenance_related_session_revisions (
                    projection_rule_id,
                    projection_rule_version,
                    content_fingerprint
                )
                """,
                """
                CREATE TABLE provenance_related_sessions (
                    target_session_id TEXT NOT NULL,
                    request_fingerprint TEXT NOT NULL,
                    latest_revision_id TEXT NOT NULL,
                    projection_rule_id TEXT NOT NULL,
                    projection_rule_version TEXT NOT NULL,
                    result_limit INTEGER NOT NULL,
                    exclusion_limit INTEGER NOT NULL,
                    updated_after_seconds REAL,
                    latest_evaluated_sequence INTEGER,
                    updated_at_seconds REAL,
                    PRIMARY KEY (target_session_id, request_fingerprint)
                )
                """,
                """
                CREATE INDEX provenance_related_sessions_sequence_index
                ON provenance_related_sessions (
                    latest_evaluated_sequence,
                    updated_at_seconds
                )
                """,
                """
                UPDATE provenance_metadata
                SET value = '23'
                WHERE key = 'schema_version'
                """,
            ]
        ),
    ]
}
