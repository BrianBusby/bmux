extension ProvenanceSQLiteRepository {
    static let workspaceDisplayOwnerAvatarMigrations = [
        ProvenanceSQLiteMigration(
            version: 28,
            statements: [
                """
                UPDATE provenance_metadata
                SET value = '28'
                WHERE key = 'schema_version'
                """,
            ],
            conditionalColumnAddition: .init(
                table: "provenance_workspace_display",
                column: "pull_request_owner_avatar_url",
                statement: "ALTER TABLE provenance_workspace_display ADD COLUMN pull_request_owner_avatar_url TEXT"
            )
        ),
    ]
}
