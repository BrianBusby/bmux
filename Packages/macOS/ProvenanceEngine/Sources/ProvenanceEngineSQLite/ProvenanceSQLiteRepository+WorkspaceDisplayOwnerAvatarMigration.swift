extension ProvenanceSQLiteRepository {
    static let workspaceDisplayOwnerAvatarMigrations = [
        ProvenanceSQLiteMigration(
            version: 26,
            statements: [
                "ALTER TABLE provenance_workspace_display ADD COLUMN pull_request_owner_avatar_url TEXT",
                """
                UPDATE provenance_metadata
                SET value = '26'
                WHERE key = 'schema_version'
                """,
            ]
        ),
    ]
}
