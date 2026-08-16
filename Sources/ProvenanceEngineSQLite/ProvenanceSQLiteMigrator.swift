import Foundation

/// Applies ordered SQLite schema migrations using `PRAGMA user_version`.
struct ProvenanceSQLiteMigrator: Sendable {
    private static let schemaFamilyKey = "schema_family"
    private static let schemaFamilyValue = "provenance-engine"
    private static let schemaIdentityVersionKey = "schema_identity_version"
    private static let schemaIdentityVersionValue = "1"
    private static let schemaVersionKey = "schema_version"
    private let migrations: [ProvenanceSQLiteMigration]
    private let enforcesSchemaIdentity: Bool

    /// Creates a migrator with strictly increasing migration versions.
    ///
    /// - Parameter migrations: Schema migrations in application order.
    /// - Throws: ``ProvenanceSQLiteError`` when versions are not strictly increasing.
    init(migrations: [ProvenanceSQLiteMigration]) throws {
        var previousVersion: Int32 = 0
        for migration in migrations {
            guard migration.version > previousVersion else {
                throw ProvenanceSQLiteError.invalidMigrationPlan(
                    message: "migration versions must be strictly increasing"
                )
            }
            previousVersion = migration.version
        }
        self.migrations = migrations
        self.enforcesSchemaIdentity = migrations.contains { migration in
            migration.statements.contains { statement in
                statement.contains("provenance_events") || statement.contains("provenance_metadata")
            }
        }
    }

    /// Applies migrations newer than the database's current `user_version`.
    ///
    /// - Parameter database: Open SQLite database connection.
    /// - Throws: ``ProvenanceSQLiteError`` when the schema is newer than supported or migration fails.
    func migrate(_ database: ProvenanceSQLiteDatabase) throws {
        let currentVersion = try database.userVersion
        guard currentVersion <= targetVersion else {
            throw ProvenanceSQLiteError.unsupportedSchema(
                found: currentVersion,
                supported: targetVersion
            )
        }

        if enforcesSchemaIdentity {
            try validateSchemaIdentity(for: database, currentVersion: currentVersion)
        }

        let pendingMigrations = migrations.filter { $0.version > currentVersion }
        guard !pendingMigrations.isEmpty else {
            if enforcesSchemaIdentity {
                try validateCurrentSchemaIdentity(for: database)
            }
            return
        }

        try database.execute("BEGIN IMMEDIATE TRANSACTION")
        do {
            for migration in pendingMigrations {
                for statement in migration.statements {
                    guard !statement.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        continue
                    }
                    try database.execute(statement)
                }
                try recordAppliedMigration(migration, in: database)
                try database.setUserVersion(migration.version)
            }
            try database.execute("COMMIT")
        } catch {
            try? database.execute("ROLLBACK")
            throw error
        }
        if enforcesSchemaIdentity {
            try validateCurrentSchemaIdentity(for: database)
        }
    }

    private var targetVersion: Int32 {
        migrations.last?.version ?? 0
    }

    private func recordAppliedMigration(
        _ migration: ProvenanceSQLiteMigration,
        in database: ProvenanceSQLiteDatabase
    ) throws {
        guard try migrationRecordTableExists(in: database) else { return }

        let insert = try database.prepare(
            """
            INSERT INTO provenance_schema_migrations (
                version,
                applied_at_seconds
            ) VALUES (?, ?)
            """
        )
        defer { insert.finalize() }

        try insert.bind(Int(migration.version), at: 1)
        try insert.bind(Date().timeIntervalSince1970, at: 2)
        _ = try insert.step()
    }

    private func migrationRecordTableExists(in database: ProvenanceSQLiteDatabase) throws -> Bool {
        let query = try database.prepare(
            "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'provenance_schema_migrations'"
        )
        defer { query.finalize() }
        return try query.step()
    }

    private func validateSchemaIdentity(
        for database: ProvenanceSQLiteDatabase,
        currentVersion: Int32
    ) throws {
        if try metadataTableExists(in: database) {
            try validateMetadata(in: database, expectedSchemaVersion: currentVersion)
            return
        }

        if currentVersion == 0 {
            let tables = try userTableNames(in: database)
            guard tables.isEmpty else {
                throw incompatibleDatabase(
                    database,
                    "expected a new empty database, but found existing tables: \(tables.sorted().joined(separator: ", "))"
                )
            }
            return
        }

        let missingTables = try requiredTables(for: currentVersion).filter { tableName in
            try !tableExists(tableName, in: database)
        }
        guard missingTables.isEmpty else {
            throw incompatibleDatabase(
                database,
                "schema version \(currentVersion) is missing required Provenance Engine tables: \(missingTables.sorted().joined(separator: ", "))"
            )
        }
    }

    private func validateCurrentSchemaIdentity(for database: ProvenanceSQLiteDatabase) throws {
        guard try metadataTableExists(in: database) else {
            throw incompatibleDatabase(database, "current schema is missing provenance_metadata")
        }
        try validateMetadata(in: database, expectedSchemaVersion: targetVersion)
    }

    private func validateMetadata(
        in database: ProvenanceSQLiteDatabase,
        expectedSchemaVersion: Int32
    ) throws {
        let metadata = try metadataValues(in: database)
        guard metadata[Self.schemaFamilyKey] == Self.schemaFamilyValue else {
            throw incompatibleDatabase(
                database,
                "metadata key \(Self.schemaFamilyKey) does not identify \(Self.schemaFamilyValue)"
            )
        }
        guard metadata[Self.schemaIdentityVersionKey] == Self.schemaIdentityVersionValue else {
            throw incompatibleDatabase(
                database,
                "metadata key \(Self.schemaIdentityVersionKey) is not supported"
            )
        }
        guard metadata[Self.schemaVersionKey] == "\(expectedSchemaVersion)" else {
            throw incompatibleDatabase(
                database,
                "metadata key \(Self.schemaVersionKey) does not match schema version \(expectedSchemaVersion)"
            )
        }
    }

    private func metadataValues(in database: ProvenanceSQLiteDatabase) throws -> [String: String] {
        let query = try database.prepare("SELECT key, value FROM provenance_metadata")
        defer { query.finalize() }

        var values: [String: String] = [:]
        while try query.step() {
            guard let key = query.string(at: 0),
                  let value = query.string(at: 1) else {
                continue
            }
            values[key] = value
        }
        return values
    }

    private func metadataTableExists(in database: ProvenanceSQLiteDatabase) throws -> Bool {
        try tableExists("provenance_metadata", in: database)
    }

    private func tableExists(_ tableName: String, in database: ProvenanceSQLiteDatabase) throws -> Bool {
        let query = try database.prepare(
            "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?"
        )
        defer { query.finalize() }
        try query.bind(tableName, at: 1)
        return try query.step()
    }

    private func userTableNames(in database: ProvenanceSQLiteDatabase) throws -> [String] {
        let query = try database.prepare(
            """
            SELECT name
            FROM sqlite_master
            WHERE type = 'table'
              AND name NOT LIKE 'sqlite_%'
            ORDER BY name
            """
        )
        defer { query.finalize() }

        var names: [String] = []
        while try query.step() {
            if let name = query.string(at: 0) {
                names.append(name)
            }
        }
        return names
    }

    private func requiredTables(for version: Int32) -> [String] {
        [
            (1, ["provenance_events"]),
            (2, ["provenance_sessions"]),
            (3, ["provenance_repositories", "provenance_worktrees"]),
            (4, ["provenance_session_relationships", "provenance_session_external_identities"]),
            (5, [
                "provenance_work_items",
                "provenance_work_contributions",
                "provenance_checkpoints",
                "provenance_change_sets",
                "provenance_file_changes",
            ]),
            (6, ["provenance_validation_runs"]),
            (7, ["provenance_storage_repair_attempts"]),
            (8, ["provenance_schema_migrations"]),
            (10, ["provenance_metadata"]),
            (11, ["provenance_workspace_display"]),
            (17, [
                "provenance_coding_agent_threads",
                "provenance_coding_agent_turns",
                "provenance_coding_agent_prompts",
                "provenance_coding_agent_plan_updates",
                "provenance_coding_agent_commands",
                "provenance_coding_agent_reasoning_summaries",
                "provenance_coding_agent_file_change_attributions",
            ]),
            (18, ["provenance_semantic_inferences"]),
            (19, ["provenance_semantic_messages"]),
        ].flatMap { migrationVersion, tableNames in
            migrationVersion <= version ? tableNames : []
        }
    }

    private func incompatibleDatabase(
        _ database: ProvenanceSQLiteDatabase,
        _ message: String
    ) -> ProvenanceSQLiteError {
        ProvenanceSQLiteError.incompatibleDatabase(path: database.url.path, message: message)
    }
}
