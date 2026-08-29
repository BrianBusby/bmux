import Foundation
import SQLite3
import ProvenanceEngineContracts
import ProvenanceEngineSDK
import Testing

@Suite
struct ProvenanceEngineClientFactoryTests {
    @Test
    func sqliteClientReturnsPublicContractClientBackedByDatabaseURL() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let client = try ProvenanceEngineClientFactory().sqliteClient(databaseURL: url)
        let timestamp = Date(timeIntervalSince1970: 1_800_000_000)

        _ = try await client.appendEvent(
            ProvenanceAppendEventRequest(
                event: ProvenanceEvent(
                    id: "event-1",
                    eventType: .worktreeObserved,
                    timestamp: timestamp,
                    repositoryID: "repository-1",
                    worktreeID: "worktree-1",
                    source: .observed,
                    confidence: .high,
                    payload: ProvenanceEventPayload(
                        repository: ProvenanceRepositoryRecord(
                            id: "repository-1",
                            path: "/tmp/repository",
                            remoteSlug: "owner/repository",
                            createdAt: timestamp,
                            updatedAt: timestamp
                        ),
                        worktree: ProvenanceWorktreeRecord(
                            id: "worktree-1",
                            repositoryID: "repository-1",
                            path: "/tmp/repository",
                            branch: "main",
                            currentHEAD: "abc123",
                            isDirty: false,
                            status: "active",
                            updatedAt: timestamp
                        )
                    )
                )
            )
        )

        let response = try await client.worktrees(ProvenanceWorktreeListRequest(repositoryID: nil, limit: nil))

        #expect(response.worktrees.map(\.worktree.id) == ["worktree-1"])
        #expect(response.worktrees.first?.repository?.remoteSlug == "owner/repository")
        #expect(FileManager.default.fileExists(atPath: url.path))
    }

    @Test
    func sqliteClientReadsSessionTreeThroughPublicContract() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let client = try ProvenanceEngineClientFactory().sqliteClient(databaseURL: url)
        let timestamp = Date(timeIntervalSince1970: 1_800_000_000)
        let rootSession = ProvenanceSessionRecord(
            id: "session-root",
            agentKind: "codex",
            workspaceID: "workspace-1",
            surfaceID: "surface-1",
            status: "active",
            startedAt: timestamp,
            updatedAt: timestamp
        )
        let childSession = ProvenanceSessionRecord(
            id: "session-child",
            agentKind: "codex",
            workspaceID: "workspace-1",
            surfaceID: "surface-2",
            status: "completed",
            startedAt: Date(timeIntervalSince1970: 1_800_000_010),
            updatedAt: Date(timeIntervalSince1970: 1_800_000_020)
        )
        let relationship = ProvenanceSessionRelationshipRecord(
            sessionID: childSession.id,
            parentSessionID: rootSession.id,
            rootSessionID: rootSession.id,
            inboundDelegationID: "delegation-1",
            depth: 1,
            source: .observed,
            confidence: .high,
            createdAt: childSession.startedAt ?? childSession.updatedAt,
            updatedAt: childSession.updatedAt
        )
        let externalIdentity = ProvenanceExternalIdentityRecord(
            id: "identity-child",
            sessionID: childSession.id,
            system: "codex",
            kind: "worker",
            externalID: "child-1",
            source: .observed,
            confidence: .high,
            createdAt: childSession.startedAt ?? childSession.updatedAt,
            updatedAt: childSession.updatedAt
        )

        for session in [rootSession, childSession] {
            _ = try await client.appendEvent(
                ProvenanceAppendEventRequest(
                    event: ProvenanceEvent(
                        id: "event-\(session.id)",
                        eventType: .sessionObserved,
                        timestamp: session.updatedAt,
                        sessionID: session.id,
                        source: .observed,
                        confidence: .high,
                        payload: ProvenanceEventPayload(session: session)
                    )
                )
            )
        }
        _ = try await client.appendEvent(
            ProvenanceAppendEventRequest(
                event: ProvenanceEvent(
                    id: "event-relationship",
                    eventType: .sessionStarted,
                    timestamp: relationship.updatedAt,
                    sessionID: childSession.id,
                    source: .observed,
                    confidence: .high,
                    payload: ProvenanceEventPayload(
                        sessionRelationship: relationship,
                        externalIdentities: [externalIdentity]
                    )
                )
            )
        )

        let tree = try await client.sessionTree(
            ProvenanceSessionTreeRequest(rootSessionID: rootSession.id)
        )

        #expect(tree.found)
        #expect(tree.reason == nil)
        #expect(tree.rootSessionID == rootSession.id)
        #expect(tree.sessions == [rootSession, childSession])
        #expect(tree.relationships == [relationship])
        #expect(tree.externalIdentities == [externalIdentity])
    }

    @Test
    func defaultSQLiteClientUsesEngineOwnedStatePathUnderHomeDirectory() async throws {
        let homeDirectory = Self.temporaryHomeDirectory()
        defer { try? FileManager.default.removeItem(at: homeDirectory) }
        let client = try ProvenanceEngineClientFactory().defaultSQLiteClient(homeDirectory: homeDirectory)

        _ = try await client.health()

        let expectedDatabaseURL = homeDirectory
            .appendingPathComponent(".local", isDirectory: true)
            .appendingPathComponent("state", isDirectory: true)
            .appendingPathComponent("provenance-engine", isDirectory: true)
            .appendingPathComponent("provenance.sqlite")
        #expect(FileManager.default.fileExists(atPath: expectedDatabaseURL.path))
    }


    @Test
    func defaultSQLiteClientBootstrapsSchemaIdentityAndPersistsEvents() async throws {
        let homeDirectory = Self.temporaryHomeDirectory()
        defer { try? FileManager.default.removeItem(at: homeDirectory) }
        let expectedDatabaseURL = Self.defaultDatabaseURL(homeDirectory: homeDirectory)
        #expect(!FileManager.default.fileExists(atPath: expectedDatabaseURL.path))

        let writer = try ProvenanceEngineClientFactory().defaultSQLiteClient(homeDirectory: homeDirectory)
        let timestamp = Date(timeIntervalSince1970: 1_800_000_100)
        let repository = ProvenanceRepositoryRecord(
            id: "repository-default-bootstrap",
            path: "/repos/default-bootstrap",
            remoteSlug: "owner/default-bootstrap",
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let worktree = ProvenanceWorktreeRecord(
            id: "worktree-default-bootstrap",
            repositoryID: repository.id,
            path: repository.path,
            branch: "main",
            currentHEAD: "bootstrap-head",
            isDirty: false,
            status: "active",
            updatedAt: timestamp
        )

        _ = try await writer.appendEvent(ProvenanceAppendEventRequest(event: ProvenanceEvent(
            id: "event-default-bootstrap",
            eventType: .worktreeObserved,
            timestamp: timestamp,
            repositoryID: repository.id,
            worktreeID: worktree.id,
            source: .observed,
            confidence: .high,
            payload: ProvenanceEventPayload(repository: repository, worktree: worktree)
        )))

        #expect(FileManager.default.fileExists(atPath: expectedDatabaseURL.path))
        #expect(try Self.tableNames(in: expectedDatabaseURL).contains("provenance_events"))
        #expect(try Self.metadata(in: expectedDatabaseURL) == [
            "schema_family": "provenance-engine",
            "schema_identity_version": "1",
            "schema_version": "22",
        ])

        let reader = try ProvenanceEngineClientFactory().defaultSQLiteClient(homeDirectory: homeDirectory)
        let worktrees = try await reader.worktrees(ProvenanceWorktreeListRequest())
        #expect(worktrees.worktrees == [ProvenanceWorktreeListEntry(worktree: worktree, repository: repository)])
    }

    @Test
    func sqliteClientMigratesValidOlderEngineStoreAndAddsSchemaIdentity() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        try Self.createVersionOneEngineStore(at: url)

        let client = try ProvenanceEngineClientFactory().sqliteClient(databaseURL: url)
        _ = try await client.health()

        #expect(try Self.userVersion(in: url) == 22)
        #expect(try Self.metadata(in: url)["schema_family"] == "provenance-engine")
        #expect(try Self.tableNames(in: url).contains("provenance_metadata"))
    }

    @Test
    func sqliteClientRejectsForeignDatabaseBeforeQueriesWithoutDestructiveChanges() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        try Self.createForeignStore(at: url)
        let beforeTables = try Self.tableNames(in: url)
        let beforeUserVersion = try Self.userVersion(in: url)

        do {
            _ = try ProvenanceEngineClientFactory().sqliteClient(databaseURL: url)
            Issue.record("Expected incompatible database to throw")
        } catch {
            let description = String(describing: error)
            #expect(description.contains(url.path))
            #expect(description.contains("not a compatible Provenance Engine store"))
            #expect(description.contains("Automatic conversion was not performed"))
            #expect(description.contains("provenance_events"))
        }

        #expect(try Self.tableNames(in: url) == beforeTables)
        #expect(try Self.userVersion(in: url) == beforeUserVersion)
        #expect(!Self.fileContainsTable(url: url, tableName: "provenance_metadata"))
    }

    private static func temporaryDatabaseURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("provenance-engine-sdk-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("provenance.sqlite")
    }

    private static func temporaryHomeDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("provenance-engine-sdk-home-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    private static func removeTemporaryDatabaseDirectory(for url: URL) {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }


    private static func defaultDatabaseURL(homeDirectory: URL) -> URL {
        homeDirectory
            .appendingPathComponent(".local", isDirectory: true)
            .appendingPathComponent("state", isDirectory: true)
            .appendingPathComponent("provenance-engine", isDirectory: true)
            .appendingPathComponent("provenance.sqlite")
    }

    private static func createVersionOneEngineStore(at url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try withSQLiteDatabase(at: url) { database in
            try execute(
                database,
                """
                CREATE TABLE provenance_events (
                    sequence INTEGER PRIMARY KEY AUTOINCREMENT,
                    id TEXT NOT NULL UNIQUE,
                    schema_version INTEGER NOT NULL,
                    event_type TEXT NOT NULL,
                    timestamp_seconds REAL NOT NULL,
                    repository_id TEXT,
                    worktree_id TEXT,
                    session_id TEXT,
                    contribution_id TEXT,
                    source TEXT NOT NULL,
                    confidence TEXT NOT NULL,
                    payload_json TEXT NOT NULL
                );
                PRAGMA user_version = 1;
                """
            )
        }
    }

    private static func createForeignStore(at url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try withSQLiteDatabase(at: url) { database in
            try execute(
                database,
                """
                CREATE TABLE events (
                    id TEXT PRIMARY KEY NOT NULL,
                    payload TEXT NOT NULL
                );
                CREATE TABLE sessions (
                    id TEXT PRIMARY KEY NOT NULL
                );
                PRAGMA user_version = 3;
                """
            )
        }
    }

    private static func metadata(in url: URL) throws -> [String: String] {
        try withSQLiteDatabase(at: url) { database in
            let statement = try prepare(database, "SELECT key, value FROM provenance_metadata")
            defer { sqlite3_finalize(statement) }
            var values: [String: String] = [:]
            while sqlite3_step(statement) == SQLITE_ROW {
                guard let keyPointer = sqlite3_column_text(statement, 0),
                      let valuePointer = sqlite3_column_text(statement, 1) else {
                    continue
                }
                values[String(cString: keyPointer)] = String(cString: valuePointer)
            }
            return values
        }
    }

    private static func tableNames(in url: URL) throws -> [String] {
        try withSQLiteDatabase(at: url) { database in
            let statement = try prepare(
                database,
                """
                SELECT name
                FROM sqlite_master
                WHERE type = 'table'
                  AND name NOT LIKE 'sqlite_%'
                ORDER BY name
                """
            )
            defer { sqlite3_finalize(statement) }
            var names: [String] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                if let pointer = sqlite3_column_text(statement, 0) {
                    names.append(String(cString: pointer))
                }
            }
            return names
        }
    }

    private static func userVersion(in url: URL) throws -> Int32 {
        try withSQLiteDatabase(at: url) { database in
            let statement = try prepare(database, "PRAGMA user_version")
            defer { sqlite3_finalize(statement) }
            guard sqlite3_step(statement) == SQLITE_ROW else { return 0 }
            return sqlite3_column_int(statement, 0)
        }
    }

    private static func fileContainsTable(url: URL, tableName: String) -> Bool {
        (try? tableNames(in: url).contains(tableName)) ?? false
    }

    private static func withSQLiteDatabase<T>(at url: URL, _ body: (OpaquePointer) throws -> T) throws -> T {
        var database: OpaquePointer?
        guard sqlite3_open_v2(url.path, &database, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE, nil) == SQLITE_OK,
              let opened = database else {
            let message = database.flatMap { sqlite3_errmsg($0) }.map { String(cString: $0) } ?? "open failed"
            if let database {
                sqlite3_close(database)
            }
            throw SQLiteTestError.message(message)
        }
        defer { sqlite3_close(opened) }
        return try body(opened)
    }

    private static func execute(_ database: OpaquePointer, _ sql: String) throws {
        var errorMessage: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(database, sql, nil, nil, &errorMessage) == SQLITE_OK else {
            let message = errorMessage.map { String(cString: $0) } ?? "sqlite exec failed"
            sqlite3_free(errorMessage)
            throw SQLiteTestError.message(message)
        }
    }

    private static func prepare(_ database: OpaquePointer, _ sql: String) throws -> OpaquePointer {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement else {
            throw SQLiteTestError.message(String(cString: sqlite3_errmsg(database)))
        }
        return statement
    }

    private enum SQLiteTestError: Error {
        case message(String)
    }
}
