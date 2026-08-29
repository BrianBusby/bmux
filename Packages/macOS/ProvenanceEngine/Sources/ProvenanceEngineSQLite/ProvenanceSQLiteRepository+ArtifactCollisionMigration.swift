extension ProvenanceSQLiteRepository {
    static let artifactCollisionProjectionTableNames = [
        "provenance_artifact_collisions",
        "provenance_artifact_collision_revisions",
    ]

    static let artifactCollisionMigrations = [
        ProvenanceSQLiteMigration(
            version: 24,
            statements: [
                """
                CREATE TABLE provenance_artifact_collision_revisions (
                    id TEXT PRIMARY KEY NOT NULL,
                    target_session_id TEXT NOT NULL,
                    request_fingerprint TEXT NOT NULL,
                    projection_rule_id TEXT NOT NULL,
                    projection_rule_version TEXT NOT NULL,
                    result_limit INTEGER NOT NULL,
                    related_session_limit INTEGER NOT NULL,
                    exclusion_limit INTEGER NOT NULL,
                    artifact_path TEXT,
                    normalized_artifact_path TEXT,
                    updated_after_seconds REAL,
                    stale_before_seconds REAL,
                    source_watermark_sequence INTEGER,
                    content_fingerprint TEXT NOT NULL,
                    projection_json TEXT NOT NULL,
                    created_at_seconds REAL
                )
                """,
                """
                CREATE INDEX provenance_artifact_collision_revisions_target_index
                ON provenance_artifact_collision_revisions (
                    target_session_id,
                    request_fingerprint,
                    source_watermark_sequence,
                    created_at_seconds
                )
                """,
                """
                CREATE INDEX provenance_artifact_collision_revisions_artifact_index
                ON provenance_artifact_collision_revisions (
                    normalized_artifact_path,
                    target_session_id,
                    created_at_seconds
                )
                """,
                """
                CREATE INDEX provenance_artifact_collision_revisions_rule_index
                ON provenance_artifact_collision_revisions (
                    projection_rule_id,
                    projection_rule_version,
                    content_fingerprint
                )
                """,
                """
                CREATE TABLE provenance_artifact_collisions (
                    target_session_id TEXT NOT NULL,
                    request_fingerprint TEXT NOT NULL,
                    latest_revision_id TEXT NOT NULL,
                    projection_rule_id TEXT NOT NULL,
                    projection_rule_version TEXT NOT NULL,
                    result_limit INTEGER NOT NULL,
                    related_session_limit INTEGER NOT NULL,
                    exclusion_limit INTEGER NOT NULL,
                    artifact_path TEXT,
                    normalized_artifact_path TEXT,
                    updated_after_seconds REAL,
                    stale_before_seconds REAL,
                    latest_evaluated_sequence INTEGER,
                    updated_at_seconds REAL,
                    PRIMARY KEY (target_session_id, request_fingerprint)
                )
                """,
                """
                CREATE INDEX provenance_artifact_collisions_artifact_index
                ON provenance_artifact_collisions (
                    normalized_artifact_path,
                    latest_evaluated_sequence,
                    updated_at_seconds
                )
                """,
                """
                CREATE INDEX provenance_artifact_collisions_sequence_index
                ON provenance_artifact_collisions (
                    latest_evaluated_sequence,
                    updated_at_seconds
                )
                """,
                """
                UPDATE provenance_metadata
                SET value = '24'
                WHERE key = 'schema_version'
                """,
            ]
        ),
    ]
}
