import Foundation

/// Applies ordered SQLite schema migrations using `PRAGMA user_version`.
struct ProvenanceSQLiteMigrator: Sendable {
    private let migrations: [ProvenanceSQLiteMigration]

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

        let pendingMigrations = migrations.filter { $0.version > currentVersion }
        guard !pendingMigrations.isEmpty else { return }

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
}
