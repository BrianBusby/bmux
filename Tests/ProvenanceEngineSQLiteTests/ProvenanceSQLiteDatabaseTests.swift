import Foundation
@testable import ProvenanceEngineSQLite
import Testing

@Suite
struct ProvenanceSQLiteDatabaseTests {
    @Test
    func opensDatabaseAndCreatesParentDirectory() throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }

        _ = try ProvenanceSQLiteDatabase(url: url)

        #expect(FileManager.default.fileExists(atPath: url.path))
    }

    @Test
    func executesStatementsAndReportsUserVersionAndChanges() throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let database = try ProvenanceSQLiteDatabase(url: url)

        try database.execute(
            """
            PRAGMA user_version = 7;
            CREATE TABLE events (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL
            );
            INSERT INTO events (id, name) VALUES ('event-1', 'started');
            """
        )

        #expect(try database.userVersion == 7)
        #expect(database.changes == 1)
    }

    @Test
    func bindsAndReadsTypedValues() throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let database = try ProvenanceSQLiteDatabase(url: url)
        try database.execute(
            """
            CREATE TABLE values_table (
                id INTEGER PRIMARY KEY,
                name TEXT,
                score REAL
            )
            """
        )
        let insert = try database.prepare("INSERT INTO values_table (id, name, score) VALUES (?, ?, ?)")
        defer { insert.finalize() }

        try insert.bind(42, at: 1)
        try insert.bind("checkpoint", at: 2)
        try insert.bind(0.75, at: 3)
        #expect(try insert.step() == false)

        let query = try database.prepare("SELECT id, name, score FROM values_table")
        defer { query.finalize() }

        #expect(try query.step())
        #expect(query.int(at: 0) == 42)
        #expect(query.int32(at: 0) == 42)
        #expect(query.string(at: 1) == "checkpoint")
        #expect(query.double(at: 2) == 0.75)
        #expect(try query.step() == false)
    }

    @Test
    func bindsNullValues() throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let database = try ProvenanceSQLiteDatabase(url: url)
        try database.execute("CREATE TABLE values_table (name TEXT, score REAL)")
        let insert = try database.prepare("INSERT INTO values_table (name, score) VALUES (?, ?)")
        defer { insert.finalize() }

        try insert.bind(nil as String?, at: 1)
        try insert.bind(nil as Double?, at: 2)
        #expect(try insert.step() == false)

        let query = try database.prepare("SELECT name, score FROM values_table")
        defer { query.finalize() }

        #expect(try query.step())
        #expect(query.string(at: 0) == nil)
        #expect(query.double(at: 1) == nil)
    }

    @Test
    func sqliteFailuresUseStorageError() throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let database = try ProvenanceSQLiteDatabase(url: url)

        do {
            try database.execute("SELECT * FROM missing_table")
            Issue.record("Expected SQLite error")
        } catch let error as ProvenanceSQLiteError {
            if case let .sqlite(message) = error {
                #expect(message.contains("missing_table"))
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func appliesMigrationsInOrderAndRecordsUserVersion() throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let database = try ProvenanceSQLiteDatabase(url: url)
        let migrator = try ProvenanceSQLiteMigrator(migrations: [
            ProvenanceSQLiteMigration(
                version: 1,
                statements: [
                    """
                    CREATE TABLE events (
                        id TEXT PRIMARY KEY NOT NULL
                    )
                    """,
                ]
            ),
            ProvenanceSQLiteMigration(
                version: 2,
                statements: [
                    "ALTER TABLE events ADD COLUMN kind TEXT",
                    "INSERT INTO events (id, kind) VALUES ('event-1', 'checkpoint')",
                ]
            ),
        ])

        try migrator.migrate(database)

        #expect(try database.userVersion == 2)
        let query = try database.prepare("SELECT id, kind FROM events")
        defer { query.finalize() }
        #expect(try query.step())
        #expect(query.string(at: 0) == "event-1")
        #expect(query.string(at: 1) == "checkpoint")
        #expect(try query.step() == false)
    }

    @Test
    func skipsMigrationsAtCurrentVersion() throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let database = try ProvenanceSQLiteDatabase(url: url)
        try database.execute(
            """
            CREATE TABLE existing_table (
                id TEXT PRIMARY KEY NOT NULL
            )
            """
        )
        try database.setUserVersion(1)
        let migrator = try ProvenanceSQLiteMigrator(migrations: [
            ProvenanceSQLiteMigration(
                version: 1,
                statements: [
                    """
                    CREATE TABLE existing_table (
                        id TEXT PRIMARY KEY NOT NULL
                    )
                    """,
                ]
            ),
        ])

        try migrator.migrate(database)

        #expect(try database.userVersion == 1)
    }

    @Test
    func rollsBackFailedMigrationBatch() throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let database = try ProvenanceSQLiteDatabase(url: url)
        let migrator = try ProvenanceSQLiteMigrator(migrations: [
            ProvenanceSQLiteMigration(
                version: 1,
                statements: [
                    """
                    CREATE TABLE rolled_back_events (
                        id TEXT PRIMARY KEY NOT NULL
                    )
                    """,
                ]
            ),
            ProvenanceSQLiteMigration(
                version: 2,
                statements: [
                    "INSERT INTO missing_table (id) VALUES ('event-1')",
                ]
            ),
        ])

        do {
            try migrator.migrate(database)
            Issue.record("Expected migration failure")
        } catch let error as ProvenanceSQLiteError {
            if case let .sqlite(message) = error {
                #expect(message.contains("missing_table"))
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        #expect(try database.userVersion == 0)
        #expect(try Self.tableExists("rolled_back_events", in: database) == false)
    }

    @Test
    func rejectsNewerDatabaseSchema() throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let database = try ProvenanceSQLiteDatabase(url: url)
        try database.setUserVersion(99)
        let migrator = try ProvenanceSQLiteMigrator(migrations: [
            ProvenanceSQLiteMigration(version: 1, statements: []),
        ])

        do {
            try migrator.migrate(database)
            Issue.record("Expected unsupported schema failure")
        } catch let error as ProvenanceSQLiteError {
            #expect(error == .unsupportedSchema(found: 99, supported: 1))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func rejectsNonIncreasingMigrationPlan() throws {
        do {
            _ = try ProvenanceSQLiteMigrator(migrations: [
                ProvenanceSQLiteMigration(version: 1, statements: []),
                ProvenanceSQLiteMigration(version: 1, statements: []),
            ])
            Issue.record("Expected migration plan failure")
        } catch let error as ProvenanceSQLiteError {
            if case let .invalidMigrationPlan(message) = error {
                #expect(message.contains("strictly increasing"))
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func repositoryOpensDatabaseAndAppliesMigrationsBeforeReturning() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }

        let repository = try ProvenanceSQLiteRepository(
            url: url,
            migrations: [
                ProvenanceSQLiteMigration(
                    version: 1,
                    statements: [
                        """
                        CREATE TABLE repository_events (
                            id TEXT PRIMARY KEY NOT NULL
                        )
                        """,
                    ]
                ),
                ProvenanceSQLiteMigration(
                    version: 2,
                    statements: [
                        "ALTER TABLE repository_events ADD COLUMN kind TEXT",
                        "INSERT INTO repository_events (id, kind) VALUES ('event-1', 'opened')",
                    ]
                ),
            ]
        )

        #expect(try await repository.schemaVersion() == 2)

        let database = try ProvenanceSQLiteDatabase(url: url)
        #expect(
            try Self.firstString(
                "SELECT kind FROM repository_events WHERE id = 'event-1'",
                in: database
            ) == "opened"
        )
    }

    @Test
    func repositorySkipsAlreadyAppliedMigrations() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let database = try ProvenanceSQLiteDatabase(url: url)
        try database.execute(
            """
            CREATE TABLE existing_repository_table (
                id TEXT PRIMARY KEY NOT NULL
            )
            """
        )
        try database.setUserVersion(1)

        let repository = try ProvenanceSQLiteRepository(
            url: url,
            migrations: [
                ProvenanceSQLiteMigration(
                    version: 1,
                    statements: [
                        """
                        CREATE TABLE existing_repository_table (
                            id TEXT PRIMARY KEY NOT NULL
                        )
                        """,
                    ]
                ),
            ]
        )

        #expect(try await repository.schemaVersion() == 1)
    }

    @Test
    func repositoryRejectsNewerDatabaseSchema() throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let database = try ProvenanceSQLiteDatabase(url: url)
        try database.setUserVersion(5)

        do {
            _ = try ProvenanceSQLiteRepository(
                url: url,
                migrations: [
                    ProvenanceSQLiteMigration(version: 1, statements: []),
                ]
            )
            Issue.record("Expected unsupported schema failure")
        } catch let error as ProvenanceSQLiteError {
            #expect(error == .unsupportedSchema(found: 5, supported: 1))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func repositoryRejectsInvalidMigrationPlanBeforeOpeningDatabase() throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }

        do {
            _ = try ProvenanceSQLiteRepository(
                url: url,
                migrations: [
                    ProvenanceSQLiteMigration(version: 1, statements: []),
                    ProvenanceSQLiteMigration(version: 1, statements: []),
                ]
            )
            Issue.record("Expected migration plan failure")
        } catch let error as ProvenanceSQLiteError {
            if case let .invalidMigrationPlan(message) = error {
                #expect(message.contains("strictly increasing"))
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        #expect(FileManager.default.fileExists(atPath: url.path) == false)
    }

    private static func temporaryDatabaseURL() -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("provenance-engine-sqlite-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        return directory.appendingPathComponent("provenance.sqlite")
    }

    private static func tableExists(_ tableName: String, in database: ProvenanceSQLiteDatabase) throws -> Bool {
        let query = try database.prepare("SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?")
        defer { query.finalize() }
        try query.bind(tableName, at: 1)
        return try query.step()
    }

    private static func firstString(_ sql: String, in database: ProvenanceSQLiteDatabase) throws -> String? {
        let query = try database.prepare(sql)
        defer { query.finalize() }
        guard try query.step() else { return nil }
        return query.string(at: 0)
    }

    private static func removeTemporaryDatabaseDirectory(for url: URL) {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }
}
