import Foundation
@testable import ProvenanceEngineSQLite
import Testing

@Suite
struct RelatedSessionMigrationTests {
    @Test
    func defaultMigrationsCreateRelatedSessionTablesAndEmptyCounters() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }

        let repository = try ProvenanceSQLiteRepository(url: url)
        let database = try ProvenanceSQLiteDatabase(url: url)
        let summary = try await repository.storageSummary()

        #expect(try await repository.schemaVersion() == 23)
        #expect(try Self.tableExists("provenance_related_session_revisions", in: database))
        #expect(try Self.tableExists("provenance_related_sessions", in: database))
        #expect(summary.relatedSessionRevisionCount == 0)
        #expect(summary.relatedSessionCount == 0)
    }

    @Test
    func versionTwentyTwoDatabasesMigrateToRelatedSessionSchema() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }

        let oldRepository = try ProvenanceSQLiteRepository(
            url: url,
            migrations: Array(ProvenanceSQLiteRepository.migrations.dropLast())
        )
        let oldDatabase = try ProvenanceSQLiteDatabase(url: url)

        #expect(try await oldRepository.schemaVersion() == 22)
        #expect(try Self.tableExists("provenance_related_session_revisions", in: oldDatabase) == false)
        #expect(try Self.tableExists("provenance_related_sessions", in: oldDatabase) == false)

        let repository = try ProvenanceSQLiteRepository(url: url)
        let migratedDatabase = try ProvenanceSQLiteDatabase(url: url)

        #expect(try await repository.schemaVersion() == 23)
        #expect(try Self.tableExists("provenance_related_session_revisions", in: migratedDatabase))
        #expect(try Self.tableExists("provenance_related_sessions", in: migratedDatabase))
        #expect(try await repository.schemaMigrationRecords(limit: 2).map(\.version) == [23, 22])
    }

    private static func tableExists(_ name: String, in database: ProvenanceSQLiteDatabase) throws -> Bool {
        let query = try database.prepare(
            """
            SELECT name FROM sqlite_master
            WHERE type = 'table' AND name = ?
            """
        )
        defer { query.finalize() }

        try query.bind(name, at: 1)
        return try query.step()
    }

    private static func temporaryDatabaseURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("provenance-engine-related-session-migration-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("provenance.sqlite")
    }

    private static func removeTemporaryDatabaseDirectory(for url: URL) {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }
}
