import Foundation

extension ProvenanceSQLiteRepository {
    static let workspaceArchiveMigrations: [ProvenanceSQLiteMigration] = [
        ProvenanceSQLiteMigration(
            version: 26,
            statements: [
                """
                CREATE TABLE provenance_archived_workspaces (
                    workspace_id TEXT PRIMARY KEY NOT NULL,
                    closed_at_seconds REAL NOT NULL,
                    record_json TEXT NOT NULL
                )
                """,
                """
                CREATE INDEX provenance_archived_workspaces_closed_index
                ON provenance_archived_workspaces (closed_at_seconds DESC, workspace_id DESC)
                """,
                """
                CREATE INDEX provenance_sessions_workspace_index
                ON provenance_sessions (workspace_id, started_at_seconds DESC, id DESC)
                """,
                """
                UPDATE provenance_metadata SET value = '26' WHERE key = 'schema_version'
                """,
            ]
        ),
    ]
}
