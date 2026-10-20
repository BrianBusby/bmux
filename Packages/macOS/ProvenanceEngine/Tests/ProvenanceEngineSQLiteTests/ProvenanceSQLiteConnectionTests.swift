import Foundation
@testable import ProvenanceEngineSQLite
import Testing

@Suite struct ProvenanceSQLiteConnectionTests {
    @Test
    func executesStatementsAndReportsUserVersionAndChanges() throws {
        let url = Self.temporaryDatabaseURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
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
    func opensDatabaseAndCreatesParentDirectory() throws {
        let url = Self.temporaryDatabaseURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        _ = try ProvenanceSQLiteDatabase(url: url)

        #expect(FileManager.default.fileExists(atPath: url.path))
    }

    private static func temporaryDatabaseURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("provenance-sqlite-connection-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("provenance.sqlite")
    }
}
