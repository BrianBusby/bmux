import Foundation
@testable import ProvenanceEngineSQLite
import Testing

@Suite
struct ArtifactCollisionMigrationTests {
    @Test
    func defaultMigrationsCreateArtifactCollisionTablesAndEmptyCounters() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }

        let repository = try ProvenanceSQLiteRepository(url: url)
        let database = try ProvenanceSQLiteDatabase(url: url)
        let summary = try await repository.storageSummary()

        #expect(try await repository.schemaVersion() == 24)
        #expect(try Self.tableExists("provenance_artifact_collision_revisions", in: database))
        #expect(try Self.tableExists("provenance_artifact_collisions", in: database))
        #expect(summary.artifactCollisionRevisionCount == 0)
        #expect(summary.artifactCollisionCount == 0)
    }

    @Test
    func versionTwentyThreeDatabasesMigrateToArtifactCollisionSchema() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }

        let oldRepository = try ProvenanceSQLiteRepository(
            url: url,
            migrations: Array(ProvenanceSQLiteRepository.migrations.dropLast())
        )
        let oldDatabase = try ProvenanceSQLiteDatabase(url: url)

        #expect(try await oldRepository.schemaVersion() == 23)
        #expect(try Self.tableExists("provenance_related_session_revisions", in: oldDatabase))
        #expect(try Self.tableExists("provenance_artifact_collision_revisions", in: oldDatabase) == false)
        #expect(try Self.tableExists("provenance_artifact_collisions", in: oldDatabase) == false)

        let repository = try ProvenanceSQLiteRepository(url: url)
        let migratedDatabase = try ProvenanceSQLiteDatabase(url: url)

        #expect(try await repository.schemaVersion() == 24)
        #expect(try Self.tableExists("provenance_artifact_collision_revisions", in: migratedDatabase))
        #expect(try Self.tableExists("provenance_artifact_collisions", in: migratedDatabase))
        #expect(try await repository.schemaMigrationRecords(limit: 2).map(\.version) == [24, 23])
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
            .appendingPathComponent("provenance-engine-artifact-collision-migration-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("provenance.sqlite")
    }

    private static func removeTemporaryDatabaseDirectory(for url: URL) {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }
}
