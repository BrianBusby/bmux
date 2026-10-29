extension ProvenanceSQLiteRepository {
    static let workspaceDisplayPullRequestTitleMigrations = [
        ProvenanceSQLiteMigration(
            version: 30,
            statements: [
                """
                UPDATE provenance_metadata
                SET value = '30'
                WHERE key = 'schema_version'
                """,
            ],
            conditionalColumnAddition: .init(
                table: "provenance_workspace_display",
                column: "pull_request_title",
                statement: "ALTER TABLE provenance_workspace_display ADD COLUMN pull_request_title TEXT"
            )
        ),
    ]
}
