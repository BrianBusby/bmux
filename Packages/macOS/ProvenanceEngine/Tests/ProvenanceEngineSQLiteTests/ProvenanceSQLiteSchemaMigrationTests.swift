import Foundation
@testable import ProvenanceEngineSQLite
import Testing

@Suite
struct ProvenanceSQLiteSchemaMigrationTests {
    @Test
    func repositoryDefaultMigrationsBootstrapEventLedgerSchema() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }

        let repository = try ProvenanceSQLiteRepository(url: url)

        #expect(try await repository.schemaVersion() == 25)

        let database = try ProvenanceSQLiteDatabase(url: url)
        try Self.expectTables([
            "provenance_events", "provenance_sessions", "provenance_repositories", "provenance_worktrees",
            "provenance_session_relationships", "provenance_session_external_identities", "provenance_work_items",
            "provenance_work_contributions", "provenance_checkpoints", "provenance_change_sets",
            "provenance_file_changes", "provenance_validation_runs", "provenance_workspace_display",
            "provenance_coding_agent_threads", "provenance_coding_agent_turns", "provenance_coding_agent_prompts",
            "provenance_coding_agent_plan_updates", "provenance_coding_agent_commands",
            "provenance_coding_agent_reasoning_summaries", "provenance_coding_agent_assistant_messages",
            "provenance_coding_agent_file_change_attributions", "provenance_coding_agent_turn_outcome_revisions",
            "provenance_coding_agent_turn_outcomes", "provenance_coding_agent_session_outcome_revisions",
            "provenance_coding_agent_session_outcomes", "provenance_semantic_inferences",
            "provenance_semantic_messages", "provenance_storage_repair_attempts", "provenance_schema_migrations",
            "provenance_related_session_revisions", "provenance_related_sessions",
            "provenance_artifact_collision_revisions", "provenance_artifact_collisions",
            "provenance_workspace_coding_agent_session_associations",
        ], in: database)
        #expect(try await repository.schemaMigrationRecords(limit: 10).map(\.version) == [25, 24, 23, 22, 21, 20, 19, 18, 17, 16])
    }

    @Test
    func repositoryMigratesExistingVersion13WorkspaceDisplaySchemaToOwnerAndDurabilityColumns() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }

        _ = try ProvenanceSQLiteRepository(
            url: url,
            migrations: Array(ProvenanceSQLiteRepository.migrations.dropLast(12))
        )

        let olderDatabase = try ProvenanceSQLiteDatabase(url: url)
        #expect(try olderDatabase.userVersion == 13)
        #expect(try Self.firstString("SELECT value FROM provenance_metadata WHERE key = 'schema_version'", in: olderDatabase) == "13")
        #expect(try Self.tableHasColumn("provenance_workspace_display", "pull_request_owner_login", in: olderDatabase) == false)

        let repository = try ProvenanceSQLiteRepository(url: url)
        let migratedDatabase = try ProvenanceSQLiteDatabase(url: url)

        #expect(try await repository.schemaVersion() == 25)
        #expect(try Self.firstString("SELECT value FROM provenance_metadata WHERE key = 'schema_version'", in: migratedDatabase) == "25")
        #expect(try Self.tableHasColumn("provenance_workspace_display", "pull_request_owner_login", in: migratedDatabase))
        #expect(try Self.tableHasColumn("provenance_workspace_display", "pull_request_owner_url", in: migratedDatabase))
        #expect(try Self.tableHasColumn("provenance_workspace_display", "current_work_summary", in: migratedDatabase))
        #expect(try Self.tableHasColumn("provenance_workspace_display", "last_submitted_prompt", in: migratedDatabase))
        #expect(try Self.tableHasColumn("provenance_workspace_display", "last_submitted_prompt_submitted_at_seconds", in: migratedDatabase))
        #expect(try Self.tableHasColumn("provenance_workspace_display", "last_submitted_prompt_session_id", in: migratedDatabase))
        #expect(try Self.tableHasColumn("provenance_workspace_display", "cleared_fields_json", in: migratedDatabase))
        #expect(try Self.tableHasColumn("provenance_workspace_display", "field_metadata_json", in: migratedDatabase))
        #expect(try Self.tableHasColumn("provenance_workspace_display", "project_links_json", in: migratedDatabase))
        #expect(try Self.tableExists("provenance_coding_agent_threads", in: migratedDatabase))
        #expect(try Self.tableExists("provenance_coding_agent_turns", in: migratedDatabase))
        #expect(try Self.tableExists("provenance_coding_agent_assistant_messages", in: migratedDatabase))
        #expect(try Self.tableExists("provenance_coding_agent_turn_outcome_revisions", in: migratedDatabase))
        #expect(try Self.tableExists("provenance_coding_agent_turn_outcomes", in: migratedDatabase))
        #expect(try Self.tableExists("provenance_coding_agent_session_outcome_revisions", in: migratedDatabase))
        #expect(try Self.tableExists("provenance_coding_agent_session_outcomes", in: migratedDatabase))
        #expect(try Self.tableExists("provenance_semantic_inferences", in: migratedDatabase))
        #expect(try Self.tableExists("provenance_semantic_messages", in: migratedDatabase))
        #expect(try Self.tableExists("provenance_related_session_revisions", in: migratedDatabase))
        #expect(try Self.tableExists("provenance_artifact_collision_revisions", in: migratedDatabase))
        #expect(try Self.tableExists("provenance_workspace_coding_agent_session_associations", in: migratedDatabase))
        #expect(try await repository.schemaMigrationRecords(limit: 3).map(\.version) == [25, 24, 23])
    }

    @Test
    func repositoryReadsSchemaMigrationRecordsNewestFirstWithLimit() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let database = try ProvenanceSQLiteDatabase(url: url)
        try database.execute(
            """
            CREATE TABLE provenance_schema_migrations (
                sequence INTEGER PRIMARY KEY AUTOINCREMENT,
                version INTEGER NOT NULL UNIQUE,
                applied_at_seconds REAL NOT NULL
            );
            INSERT INTO provenance_schema_migrations (version, applied_at_seconds)
            VALUES (3, 1800000003), (4, 1800000004);
            """
        )
        try database.setUserVersion(4)

        let repository = try ProvenanceSQLiteRepository(
            url: url,
            migrations: [
                ProvenanceSQLiteMigration(version: 1, statements: []),
                ProvenanceSQLiteMigration(version: 2, statements: []),
                ProvenanceSQLiteMigration(version: 3, statements: []),
                ProvenanceSQLiteMigration(version: 4, statements: []),
            ]
        )

        let limitedRecords = try await repository.schemaMigrationRecords(limit: 1)
        let zeroLimitRecords = try await repository.schemaMigrationRecords(limit: -1)

        #expect(limitedRecords == [
            ProvenanceSQLiteSchemaMigrationRecord(
                sequence: 2,
                version: 4,
                appliedAt: Date(timeIntervalSince1970: 1_800_000_004)
            ),
        ])
        #expect(zeroLimitRecords.isEmpty)
    }

    @Test
    func repositoryOpensEngineOwnedDefaultStorageLocation() async throws {
        let homeDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("provenance-engine-home-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: homeDirectory) }
        let storageLocation = ProvenanceSQLiteStorageLocation(homeDirectory: homeDirectory)

        #expect(storageLocation.databaseURL == homeDirectory
            .appendingPathComponent(".local", isDirectory: true)
            .appendingPathComponent("state", isDirectory: true)
            .appendingPathComponent("provenance-engine", isDirectory: true)
            .appendingPathComponent("provenance.sqlite"))

        let repository = try ProvenanceSQLiteRepository(storageLocation: storageLocation)

        #expect(try await repository.schemaVersion() == 25)
        #expect(FileManager.default.fileExists(atPath: storageLocation.databaseURL.path))
    }


    private static func temporaryDatabaseURL() -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("provenance-engine-schema-migration-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        return directory.appendingPathComponent("provenance.sqlite")
    }

    private static func removeTemporaryDatabaseDirectory(for url: URL) {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }

    private static func tableExists(_ tableName: String, in database: ProvenanceSQLiteDatabase) throws -> Bool {
        let query = try database.prepare("SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?")
        defer { query.finalize() }
        try query.bind(tableName, at: 1)
        return try query.step()
    }

    private static func expectTables(_ tableNames: [String], in database: ProvenanceSQLiteDatabase) throws {
        for tableName in tableNames {
            #expect(try Self.tableExists(tableName, in: database))
        }
    }

    private static func tableHasColumn(
        _ tableName: String,
        _ columnName: String,
        in database: ProvenanceSQLiteDatabase
    ) throws -> Bool {
        let query = try database.prepare("PRAGMA table_info(\(tableName))")
        defer { query.finalize() }
        while try query.step() {
            if query.string(at: 1) == columnName {
                return true
            }
        }
        return false
    }

    private static func firstString(_ sql: String, in database: ProvenanceSQLiteDatabase) throws -> String? {
        let query = try database.prepare(sql)
        defer { query.finalize() }
        guard try query.step() else { return nil }
        return query.string(at: 0)
    }
}
