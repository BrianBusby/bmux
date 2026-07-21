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

    private static func temporaryDatabaseURL() -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("provenance-engine-sqlite-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        return directory.appendingPathComponent("provenance.sqlite")
    }

    private static func removeTemporaryDatabaseDirectory(for url: URL) {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }
}
