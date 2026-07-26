import Foundation
import ProvenanceEngineContracts
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
    func recordsAppliedMigrationsWhenMetadataTableExists() throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let database = try ProvenanceSQLiteDatabase(url: url)
        let migrator = try ProvenanceSQLiteMigrator(migrations: [
            ProvenanceSQLiteMigration(
                version: 1,
                statements: [
                    """
                    CREATE TABLE provenance_schema_migrations (
                        sequence INTEGER PRIMARY KEY AUTOINCREMENT,
                        version INTEGER NOT NULL UNIQUE,
                        applied_at_seconds REAL NOT NULL
                    )
                    """,
                ]
            ),
            ProvenanceSQLiteMigration(
                version: 2,
                statements: [
                    """
                    CREATE TABLE migration_target (
                        id TEXT PRIMARY KEY NOT NULL
                    )
                    """,
                ]
            ),
        ])

        try migrator.migrate(database)

        #expect(try database.userVersion == 2)
        let query = try database.prepare(
            "SELECT version, applied_at_seconds FROM provenance_schema_migrations ORDER BY sequence ASC"
        )
        defer { query.finalize() }

        #expect(try query.step())
        #expect(query.int32(at: 0) == 1)
        #expect((query.double(at: 1) ?? 0) > 0)
        #expect(try query.step())
        #expect(query.int32(at: 0) == 2)
        #expect((query.double(at: 1) ?? 0) > 0)
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

    @Test
    func repositoryDefaultMigrationsBootstrapEventLedgerSchema() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }

        let repository = try ProvenanceSQLiteRepository(url: url)

        #expect(try await repository.schemaVersion() == 10)

        let database = try ProvenanceSQLiteDatabase(url: url)
        #expect(try Self.tableExists("provenance_events", in: database))
        #expect(try Self.tableExists("provenance_sessions", in: database))
        #expect(try Self.tableExists("provenance_repositories", in: database))
        #expect(try Self.tableExists("provenance_worktrees", in: database))
        #expect(try Self.tableExists("provenance_session_relationships", in: database))
        #expect(try Self.tableExists("provenance_session_external_identities", in: database))
        #expect(try Self.tableExists("provenance_work_items", in: database))
        #expect(try Self.tableExists("provenance_work_contributions", in: database))
        #expect(try Self.tableExists("provenance_checkpoints", in: database))
        #expect(try Self.tableExists("provenance_change_sets", in: database))
        #expect(try Self.tableExists("provenance_file_changes", in: database))
        #expect(try Self.tableExists("provenance_validation_runs", in: database))
        #expect(try Self.tableExists("provenance_storage_repair_attempts", in: database))
        #expect(try Self.tableExists("provenance_schema_migrations", in: database))
        #expect(try await repository.schemaMigrationRecords(limit: 10).map(\.version) == [10, 9, 8])
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

        #expect(try await repository.schemaVersion() == 10)
        #expect(FileManager.default.fileExists(atPath: storageLocation.databaseURL.path))
    }

    @Test
    func repositoryAppendsAndReadsEventAfterReopen() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let event = ProvenanceEvent(
            id: "event-1",
            schemaVersion: 1,
            eventType: .progressCheckpoint,
            timestamp: Date(timeIntervalSince1970: 1_800_000_000),
            repositoryID: "repository-1",
            worktreeID: "worktree-1",
            sessionID: "session-1",
            contributionID: "contribution-1",
            source: .observed,
            evidenceOrigin: .codexSession,
            evidenceScope: ProvenanceEvidenceScope(level: .personal, id: "brian"),
            confidence: .high,
            payload: ProvenanceEventPayload(
                checkpoint: ProvenanceCheckpointRecord(
                    id: "checkpoint-1",
                    contributionID: "contribution-1",
                    sequence: 1,
                    summary: "Recorded narrow storage path.",
                    status: "in_progress",
                    semanticConfidence: .high,
                    freshness: "fresh",
                    createdAt: Date(timeIntervalSince1970: 1_800_000_001)
                )
            )
        )

        let writer = try ProvenanceSQLiteRepository(url: url)
        try await writer.appendEvent(event)

        let reader = try ProvenanceSQLiteRepository(url: url)
        let stored = try await reader.event(id: event.id)

        #expect(stored == event)
    }

    @Test
    func repositoryReadsEventLedgerEntriesBySequenceAfterReopen() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let first = ProvenanceEvent(
            id: "event-first",
            eventType: .progressCheckpoint,
            timestamp: Date(timeIntervalSince1970: 1_800_000_030),
            sessionID: "session-1",
            source: .declared,
            confidence: .high,
            payload: ProvenanceEventPayload(
                checkpoint: ProvenanceCheckpointRecord(
                    id: "checkpoint-first",
                    contributionID: "contribution-1",
                    sequence: 1,
                    status: "in_progress",
                    semanticConfidence: .high,
                    freshness: "fresh",
                    createdAt: Date(timeIntervalSince1970: 1_800_000_030)
                )
            )
        )
        let second = ProvenanceEvent(
            id: "event-second",
            eventType: .sessionObserved,
            timestamp: Date(timeIntervalSince1970: 1_800_000_010),
            sessionID: "session-1",
            source: .observed,
            confidence: .medium,
            payload: ProvenanceEventPayload(
                session: ProvenanceSessionRecord(
                    id: "session-1",
                    agentKind: "codex",
                    status: "active",
                    updatedAt: Date(timeIntervalSince1970: 1_800_000_010)
                )
            )
        )
        let third = ProvenanceEvent(
            id: "event-third",
            eventType: .progressCheckpoint,
            timestamp: Date(timeIntervalSince1970: 1_800_000_020),
            sessionID: "session-1",
            source: .declared,
            confidence: .high,
            payload: ProvenanceEventPayload(
                checkpoint: ProvenanceCheckpointRecord(
                    id: "checkpoint-third",
                    contributionID: "contribution-1",
                    sequence: 2,
                    status: "complete",
                    semanticConfidence: .high,
                    freshness: "fresh",
                    createdAt: Date(timeIntervalSince1970: 1_800_000_020)
                )
            )
        )
        let writer = try ProvenanceSQLiteRepository(url: url)

        for event in [first, second, third] {
            try await writer.appendEvent(event)
        }

        let reader = try ProvenanceSQLiteRepository(url: url)
        let allEntries = try await reader.eventLedgerEntries(limit: 10)
        let entriesAfterFirst = try await reader.eventLedgerEntries(
            afterSequence: try #require(allEntries.first?.sequence),
            limit: 10
        )
        let limitedEntries = try await reader.eventLedgerEntries(limit: 2)
        let zeroLimitEntries = try await reader.eventLedgerEntries(limit: -1)

        #expect(allEntries.map(\.sequence) == [1, 2, 3])
        #expect(allEntries.map(\.event) == [first, second, third])
        #expect(entriesAfterFirst.map(\.event.id) == [second.id, third.id])
        #expect(limitedEntries.map(\.event.id) == [first.id, second.id])
        #expect(zeroLimitEntries.isEmpty)
    }

    @Test
    func repositoryValidatesEventLedgerRowsWithBoundedScan() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let first = Self.checkpointEvent(
            id: "event-first",
            checkpointID: "checkpoint-first",
            timestamp: 1_800_000_000
        )
        let second = Self.checkpointEvent(
            id: "event-second",
            checkpointID: "checkpoint-second",
            timestamp: 1_800_000_010
        )
        let repository = try ProvenanceSQLiteRepository(url: url)

        try await repository.appendEvent(first)
        try await repository.appendEvent(second)

        let limitedReport = try await repository.validateEventLedger(limit: 1)
        let fullReport = try await repository.validateEventLedger(limit: 10)
        let zeroLimitReport = try await repository.validateEventLedger(limit: -1)

        #expect(limitedReport.checkedEventCount == 1)
        #expect(limitedReport.invalidEventCount == 0)
        #expect(limitedReport.latestCheckedSequence == 1)
        #expect(limitedReport.firstInvalidIssue == nil)
        #expect(limitedReport.truncated)
        #expect(fullReport.checkedEventCount == 2)
        #expect(fullReport.invalidEventCount == 0)
        #expect(fullReport.latestCheckedSequence == 2)
        #expect(fullReport.firstInvalidIssue == nil)
        #expect(fullReport.truncated == false)
        #expect(zeroLimitReport.checkedEventCount == 0)
        #expect(zeroLimitReport.invalidEventCount == 0)
        #expect(zeroLimitReport.latestCheckedSequence == nil)
        #expect(zeroLimitReport.firstInvalidIssue == nil)
        #expect(zeroLimitReport.truncated)
    }

    @Test
    func repositoryRebuildsProjectionTablesFromAppendOrderEventLedger() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let activeSession = ProvenanceSessionRecord(
            id: "session-1",
            agentKind: "codex",
            status: "active",
            startedAt: Date(timeIntervalSince1970: 1_800_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_800_000_001)
        )
        let completedSession = ProvenanceSessionRecord(
            id: activeSession.id,
            agentKind: activeSession.agentKind,
            status: "completed",
            startedAt: activeSession.startedAt,
            updatedAt: Date(timeIntervalSince1970: 1_800_000_010)
        )
        let firstEvent = ProvenanceEvent(
            id: "event-active-session",
            eventType: .sessionObserved,
            timestamp: activeSession.updatedAt,
            sessionID: activeSession.id,
            source: .observed,
            confidence: .medium,
            payload: ProvenanceEventPayload(session: activeSession)
        )
        let secondEvent = ProvenanceEvent(
            id: "event-completed-session",
            eventType: .sessionObserved,
            timestamp: completedSession.updatedAt,
            sessionID: completedSession.id,
            source: .declared,
            confidence: .high,
            payload: ProvenanceEventPayload(session: completedSession)
        )
        let repository = try ProvenanceSQLiteRepository(url: url)

        try await repository.appendEvent(firstEvent)
        try await repository.appendEvent(secondEvent)

        let database = try ProvenanceSQLiteDatabase(url: url)
        try database.execute(
            """
            UPDATE provenance_sessions
            SET status = 'corrupted',
                updated_at_seconds = 1
            WHERE id = 'session-1'
            """
        )

        #expect(try await repository.session(id: activeSession.id)?.status == "corrupted")

        let replayedCount = try await repository.rebuildProjectionsFromEventLedger(batchSize: 0)
        let reader = try ProvenanceSQLiteRepository(url: url)
        let ledgerEntries = try await reader.eventLedgerEntries(limit: 10)

        #expect(replayedCount == 2)
        #expect(try await reader.session(id: activeSession.id) == completedSession)
        #expect(ledgerEntries.map(\.event) == [firstEvent, secondEvent])
    }

    @Test
    func repositoryRebuildClearsProjectionTablesWithoutLedgerEvents() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)
        let database = try ProvenanceSQLiteDatabase(url: url)
        try database.execute(
            """
            INSERT INTO provenance_sessions (
                id,
                agent_kind,
                status,
                updated_at_seconds
            ) VALUES (
                'session-stale',
                'codex',
                'active',
                1800000000
            )
            """
        )

        #expect(try await repository.session(id: "session-stale") != nil)

        let replayedCount = try await repository.rebuildProjectionsFromEventLedger()

        #expect(replayedCount == 0)
        #expect(try await repository.session(id: "session-stale") == nil)
        #expect(try await repository.eventLedgerEntries(limit: 10).isEmpty)
    }

    @Test
    func repositoryStorageSummaryReportsEmptyLedgerAndProjections() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)

        let summary = try await repository.storageSummary()

        #expect(summary == ProvenanceSQLiteStorageSummary(
            schemaVersion: 10,
            eventCount: 0,
            latestEventSequence: nil,
            repositoryCount: 0,
            worktreeCount: 0,
            sessionCount: 0,
            sessionRelationshipCount: 0,
            externalIdentityCount: 0,
            workItemCount: 0,
            contributionCount: 0,
            checkpointCount: 0,
            changeSetCount: 0,
            fileChangeCount: 0,
            validationRunCount: 0
        ))
    }

    @Test
    func repositoryStorageSummaryReflectsProjectionRepairAfterLedgerReplay() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let timestamp = Date(timeIntervalSince1970: 1_800_000_000)
        let session = ProvenanceSessionRecord(
            id: "session-authoritative",
            agentKind: "codex",
            status: "active",
            updatedAt: timestamp
        )
        let repository = try ProvenanceSQLiteRepository(url: url)

        try await repository.appendEvent(
            ProvenanceEvent(
                id: "event-session",
                eventType: .sessionObserved,
                timestamp: timestamp,
                sessionID: session.id,
                source: .observed,
                confidence: .high,
                payload: ProvenanceEventPayload(session: session)
            )
        )

        let database = try ProvenanceSQLiteDatabase(url: url)
        try database.execute(
            """
            INSERT INTO provenance_sessions (
                id,
                agent_kind,
                status,
                updated_at_seconds
            ) VALUES (
                'session-stale',
                'codex',
                'active',
                1800000010
            )
            """
        )

        let driftedSummary = try await repository.storageSummary()
        let replayedCount = try await repository.rebuildProjectionsFromEventLedger(batchSize: 1)
        let repairedSummary = try await repository.storageSummary()

        #expect(driftedSummary.eventCount == 1)
        #expect(driftedSummary.latestEventSequence == 1)
        #expect(driftedSummary.sessionCount == 2)
        #expect(replayedCount == 1)
        #expect(repairedSummary.eventCount == 1)
        #expect(repairedSummary.latestEventSequence == 1)
        #expect(repairedSummary.sessionCount == 1)
        #expect(try await repository.session(id: session.id) == session)
        #expect(try await repository.session(id: "session-stale") == nil)
    }

    @Test
    func repositoryValidatesProjectionCountsFromCompleteLedgerReplay() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let timestamp = Date(timeIntervalSince1970: 1_800_000_000)
        let repositoryRecord = ProvenanceRepositoryRecord(
            id: "repository-1",
            path: "/repos/project",
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let worktree = ProvenanceWorktreeRecord(
            id: "worktree-1",
            repositoryID: repositoryRecord.id,
            path: repositoryRecord.path,
            isDirty: false,
            status: "active",
            updatedAt: timestamp
        )
        let activeSession = ProvenanceSessionRecord(
            id: "session-1",
            agentKind: "codex",
            worktreeID: worktree.id,
            status: "active",
            startedAt: timestamp,
            updatedAt: timestamp
        )
        let completedSession = ProvenanceSessionRecord(
            id: activeSession.id,
            agentKind: activeSession.agentKind,
            worktreeID: activeSession.worktreeID,
            status: "completed",
            startedAt: activeSession.startedAt,
            updatedAt: Date(timeIntervalSince1970: 1_800_000_010)
        )
        let externalIdentity = ProvenanceExternalIdentityRecord(
            id: "identity-1",
            sessionID: activeSession.id,
            system: "codex",
            kind: "thread",
            externalID: "external-session-1",
            source: .observed,
            confidence: .high,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let repository = try ProvenanceSQLiteRepository(url: url)

        try await repository.appendEvent(
            ProvenanceEvent(
                id: "event-bootstrap",
                eventType: .worktreeObserved,
                timestamp: timestamp,
                repositoryID: repositoryRecord.id,
                worktreeID: worktree.id,
                source: .observed,
                confidence: .high,
                payload: ProvenanceEventPayload(
                    repository: repositoryRecord,
                    worktree: worktree,
                    session: activeSession,
                    externalIdentities: [externalIdentity]
                )
            )
        )
        try await repository.appendEvent(
            ProvenanceEvent(
                id: "event-session-completed",
                eventType: .sessionObserved,
                timestamp: completedSession.updatedAt,
                sessionID: completedSession.id,
                source: .declared,
                confidence: .high,
                payload: ProvenanceEventPayload(session: completedSession)
            )
        )

        let report = try await repository.validateProjectionCounts(limit: 10)

        #expect(report == ProvenanceSQLiteProjectionValidationReport(
            checkedEventCount: 2,
            latestCheckedSequence: 2,
            truncated: false,
            comparedProjectionCounts: true,
            mismatches: []
        ))
    }

    @Test
    func repositoryProjectionCountValidationReportsStaleProjectionRows() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let timestamp = Date(timeIntervalSince1970: 1_800_000_000)
        let session = ProvenanceSessionRecord(
            id: "session-authoritative",
            agentKind: "codex",
            status: "active",
            updatedAt: timestamp
        )
        let repository = try ProvenanceSQLiteRepository(url: url)

        try await repository.appendEvent(
            ProvenanceEvent(
                id: "event-session",
                eventType: .sessionObserved,
                timestamp: timestamp,
                sessionID: session.id,
                source: .observed,
                confidence: .high,
                payload: ProvenanceEventPayload(session: session)
            )
        )

        let database = try ProvenanceSQLiteDatabase(url: url)
        try database.execute(
            """
            INSERT INTO provenance_sessions (
                id,
                agent_kind,
                status,
                updated_at_seconds
            ) VALUES (
                'session-stale',
                'codex',
                'active',
                1800000010
            )
            """
        )

        let report = try await repository.validateProjectionCounts(limit: 10)

        #expect(report == ProvenanceSQLiteProjectionValidationReport(
            checkedEventCount: 1,
            latestCheckedSequence: 1,
            truncated: false,
            comparedProjectionCounts: true,
            mismatches: [
                ProvenanceSQLiteProjectionValidationMismatch(
                    tableName: "provenance_sessions",
                    expectedCount: 1,
                    actualCount: 2
                ),
            ]
        ))
    }

    @Test
    func repositoryProjectionCountValidationSkipsComparisonWhenBoundedScanTruncates() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)

        try await repository.appendEvent(Self.checkpointEvent(
            id: "event-first",
            checkpointID: "checkpoint-first",
            timestamp: 1_800_000_000
        ))
        try await repository.appendEvent(Self.checkpointEvent(
            id: "event-second",
            checkpointID: "checkpoint-second",
            timestamp: 1_800_000_010
        ))

        let truncatedReport = try await repository.validateProjectionCounts(limit: 1)
        let zeroLimitReport = try await repository.validateProjectionCounts(limit: 0)

        #expect(truncatedReport == ProvenanceSQLiteProjectionValidationReport(
            checkedEventCount: 1,
            latestCheckedSequence: 1,
            truncated: true,
            comparedProjectionCounts: false,
            mismatches: []
        ))
        #expect(zeroLimitReport == ProvenanceSQLiteProjectionValidationReport(
            checkedEventCount: 0,
            latestCheckedSequence: nil,
            truncated: true,
            comparedProjectionCounts: false,
            mismatches: []
        ))
    }

    @Test
    func repositoryValidatesProjectionKeysFromCompleteLedgerReplay() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let timestamp = Date(timeIntervalSince1970: 1_800_000_000)
        let repositoryRecord = ProvenanceRepositoryRecord(
            id: "repository-1",
            path: "/repos/project",
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let worktree = ProvenanceWorktreeRecord(
            id: "worktree-1",
            repositoryID: repositoryRecord.id,
            path: repositoryRecord.path,
            isDirty: false,
            status: "active",
            updatedAt: timestamp
        )
        let session = ProvenanceSessionRecord(
            id: "session-1",
            agentKind: "codex",
            worktreeID: worktree.id,
            status: "active",
            updatedAt: timestamp
        )
        let externalIdentity = ProvenanceExternalIdentityRecord(
            id: "identity-1",
            sessionID: session.id,
            system: "codex",
            kind: "thread",
            externalID: "external-session-1",
            source: .observed,
            confidence: .high,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let repository = try ProvenanceSQLiteRepository(url: url)

        try await repository.appendEvent(
            ProvenanceEvent(
                id: "event-bootstrap",
                eventType: .worktreeObserved,
                timestamp: timestamp,
                repositoryID: repositoryRecord.id,
                worktreeID: worktree.id,
                sessionID: session.id,
                source: .observed,
                confidence: .high,
                payload: ProvenanceEventPayload(
                    repository: repositoryRecord,
                    worktree: worktree,
                    session: session,
                    externalIdentities: [externalIdentity]
                )
            )
        )

        let report = try await repository.validateProjectionKeys(limit: 10)

        #expect(report == ProvenanceSQLiteProjectionKeyValidationReport(
            checkedEventCount: 1,
            latestCheckedSequence: 1,
            truncated: false,
            comparedProjectionKeys: true,
            mismatchLimit: 100,
            truncatedMismatches: false,
            mismatches: []
        ))
    }

    @Test
    func repositoryProjectionKeyValidationReportsSameCountStaleRows() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let timestamp = Date(timeIntervalSince1970: 1_800_000_000)
        let session = ProvenanceSessionRecord(
            id: "session-authoritative",
            agentKind: "codex",
            status: "active",
            updatedAt: timestamp
        )
        let repository = try ProvenanceSQLiteRepository(url: url)

        try await repository.appendEvent(
            ProvenanceEvent(
                id: "event-session",
                eventType: .sessionObserved,
                timestamp: timestamp,
                sessionID: session.id,
                source: .observed,
                confidence: .high,
                payload: ProvenanceEventPayload(session: session)
            )
        )

        let database = try ProvenanceSQLiteDatabase(url: url)
        try database.execute(
            """
            DELETE FROM provenance_sessions;
            INSERT INTO provenance_sessions (
                id,
                agent_kind,
                status,
                updated_at_seconds
            ) VALUES (
                'session-stale',
                'codex',
                'active',
                1800000010
            )
            """
        )

        let countReport = try await repository.validateProjectionCounts(limit: 10)
        let keyReport = try await repository.validateProjectionKeys(limit: 10)

        #expect(countReport.mismatches.isEmpty)
        #expect(keyReport == ProvenanceSQLiteProjectionKeyValidationReport(
            checkedEventCount: 1,
            latestCheckedSequence: 1,
            truncated: false,
            comparedProjectionKeys: true,
            mismatchLimit: 100,
            truncatedMismatches: false,
            mismatches: [
                ProvenanceSQLiteProjectionKeyMismatch(
                    tableName: "provenance_sessions",
                    key: "session-authoritative",
                    kind: "missing"
                ),
                ProvenanceSQLiteProjectionKeyMismatch(
                    tableName: "provenance_sessions",
                    key: "session-stale",
                    kind: "unexpected"
                ),
            ]
        ))
    }

    @Test
    func repositoryProjectionKeyValidationSkipsComparisonWhenBoundedScanTruncates() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)

        try await repository.appendEvent(Self.checkpointEvent(
            id: "event-first",
            checkpointID: "checkpoint-first",
            timestamp: 1_800_000_000
        ))
        try await repository.appendEvent(Self.checkpointEvent(
            id: "event-second",
            checkpointID: "checkpoint-second",
            timestamp: 1_800_000_010
        ))

        let truncatedReport = try await repository.validateProjectionKeys(limit: 1)
        let zeroLimitReport = try await repository.validateProjectionKeys(limit: 0)

        #expect(truncatedReport == ProvenanceSQLiteProjectionKeyValidationReport(
            checkedEventCount: 1,
            latestCheckedSequence: 1,
            truncated: true,
            comparedProjectionKeys: false,
            mismatchLimit: 100,
            truncatedMismatches: false,
            mismatches: []
        ))
        #expect(zeroLimitReport == ProvenanceSQLiteProjectionKeyValidationReport(
            checkedEventCount: 0,
            latestCheckedSequence: nil,
            truncated: true,
            comparedProjectionKeys: false,
            mismatchLimit: 100,
            truncatedMismatches: false,
            mismatches: []
        ))
    }

    @Test
    func repositoryProjectionKeyValidationBoundsMismatchRows() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let timestamp = Date(timeIntervalSince1970: 1_800_000_000)
        let repository = try ProvenanceSQLiteRepository(url: url)

        try await repository.appendEvent(
            ProvenanceEvent(
                id: "event-session",
                eventType: .sessionObserved,
                timestamp: timestamp,
                sessionID: "session-authoritative",
                source: .observed,
                confidence: .high,
                payload: ProvenanceEventPayload(
                    session: ProvenanceSessionRecord(
                        id: "session-authoritative",
                        agentKind: "codex",
                        status: "active",
                        updatedAt: timestamp
                    )
                )
            )
        )

        let database = try ProvenanceSQLiteDatabase(url: url)
        try database.execute(
            """
            DELETE FROM provenance_sessions;
            INSERT INTO provenance_sessions (
                id,
                agent_kind,
                status,
                updated_at_seconds
            ) VALUES (
                'session-stale',
                'codex',
                'active',
                1800000010
            )
            """
        )

        let report = try await repository.validateProjectionKeys(limit: 10, mismatchLimit: 1)

        #expect(report == ProvenanceSQLiteProjectionKeyValidationReport(
            checkedEventCount: 1,
            latestCheckedSequence: 1,
            truncated: false,
            comparedProjectionKeys: true,
            mismatchLimit: 1,
            truncatedMismatches: true,
            mismatches: [
                ProvenanceSQLiteProjectionKeyMismatch(
                    tableName: "provenance_sessions",
                    key: "session-authoritative",
                    kind: "missing"
                ),
            ]
        ))
    }

    @Test
    func repositoryProjectionRepairSkipsCleanProjectionTables() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let timestamp = Date(timeIntervalSince1970: 1_800_000_000)
        let session = ProvenanceSessionRecord(
            id: "session-clean",
            agentKind: "codex",
            status: "active",
            updatedAt: timestamp
        )
        let repository = try ProvenanceSQLiteRepository(url: url)

        try await repository.appendEvent(
            ProvenanceEvent(
                id: "event-session",
                eventType: .sessionObserved,
                timestamp: timestamp,
                sessionID: session.id,
                source: .observed,
                confidence: .high,
                payload: ProvenanceEventPayload(session: session)
            )
        )

        let report = try await repository.repairProjectionDrift(validationLimit: 10)

        #expect(report == ProvenanceSQLiteProjectionRepairReport(
            validation: ProvenanceSQLiteProjectionKeyValidationReport(
                checkedEventCount: 1,
                latestCheckedSequence: 1,
                truncated: false,
                comparedProjectionKeys: true,
                mismatchLimit: 100,
                truncatedMismatches: false,
                mismatches: []
            ),
            repaired: false,
            replayedEventCount: 0,
            postRepairValidation: nil
        ))
        #expect(try await repository.session(id: session.id) == session)
    }

    @Test
    func repositoryProjectionRepairRebuildsSameCountStaleProjectionRows() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let timestamp = Date(timeIntervalSince1970: 1_800_000_000)
        let session = ProvenanceSessionRecord(
            id: "session-authoritative",
            agentKind: "codex",
            status: "active",
            updatedAt: timestamp
        )
        let repository = try ProvenanceSQLiteRepository(url: url)

        try await repository.appendEvent(
            ProvenanceEvent(
                id: "event-session",
                eventType: .sessionObserved,
                timestamp: timestamp,
                sessionID: session.id,
                source: .observed,
                confidence: .high,
                payload: ProvenanceEventPayload(session: session)
            )
        )

        let database = try ProvenanceSQLiteDatabase(url: url)
        try database.execute(
            """
            DELETE FROM provenance_sessions;
            INSERT INTO provenance_sessions (
                id,
                agent_kind,
                status,
                updated_at_seconds
            ) VALUES (
                'session-stale',
                'codex',
                'active',
                1800000010
            )
            """
        )

        let report = try await repository.repairProjectionDrift(
            validationLimit: 10,
            mismatchLimit: 1,
            rebuildBatchSize: 1
        )

        #expect(report.validation == ProvenanceSQLiteProjectionKeyValidationReport(
            checkedEventCount: 1,
            latestCheckedSequence: 1,
            truncated: false,
            comparedProjectionKeys: true,
            mismatchLimit: 1,
            truncatedMismatches: true,
            mismatches: [
                ProvenanceSQLiteProjectionKeyMismatch(
                    tableName: "provenance_sessions",
                    key: "session-authoritative",
                    kind: "missing"
                ),
            ]
        ))
        #expect(report.repaired)
        #expect(report.replayedEventCount == 1)
        #expect(report.postRepairValidation == ProvenanceSQLiteProjectionKeyValidationReport(
            checkedEventCount: 1,
            latestCheckedSequence: 1,
            truncated: false,
            comparedProjectionKeys: true,
            mismatchLimit: 1,
            truncatedMismatches: false,
            mismatches: []
        ))
        #expect(try await repository.session(id: session.id) == session)
        #expect(try await repository.session(id: "session-stale") == nil)
    }

    @Test
    func repositoryProjectionRepairSkipsWhenValidationScanTruncates() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)

        try await repository.appendEvent(Self.checkpointEvent(
            id: "event-first",
            checkpointID: "checkpoint-first",
            timestamp: 1_800_000_000
        ))
        try await repository.appendEvent(Self.checkpointEvent(
            id: "event-second",
            checkpointID: "checkpoint-second",
            timestamp: 1_800_000_010
        ))

        let database = try ProvenanceSQLiteDatabase(url: url)
        try database.execute(
            """
            DELETE FROM provenance_checkpoints;
            INSERT INTO provenance_checkpoints (
                id,
                contribution_id,
                sequence,
                status,
                semantic_confidence,
                freshness,
                created_at_seconds
            ) VALUES (
                'checkpoint-stale',
                'contribution-1',
                1,
                'in_progress',
                'high',
                'fresh',
                1800000020
            )
            """
        )

        let report = try await repository.repairProjectionDrift(validationLimit: 1)

        #expect(report == ProvenanceSQLiteProjectionRepairReport(
            validation: ProvenanceSQLiteProjectionKeyValidationReport(
                checkedEventCount: 1,
                latestCheckedSequence: 1,
                truncated: true,
                comparedProjectionKeys: false,
                mismatchLimit: 100,
                truncatedMismatches: false,
                mismatches: []
            ),
            repaired: false,
            replayedEventCount: 0,
            postRepairValidation: nil
        ))
        #expect(try await repository.validateProjectionKeys(limit: 10).mismatches == [
            ProvenanceSQLiteProjectionKeyMismatch(
                tableName: "provenance_checkpoints",
                key: "checkpoint-first",
                kind: "missing"
            ),
            ProvenanceSQLiteProjectionKeyMismatch(
                tableName: "provenance_checkpoints",
                key: "checkpoint-second",
                kind: "missing"
            ),
            ProvenanceSQLiteProjectionKeyMismatch(
                tableName: "provenance_checkpoints",
                key: "checkpoint-stale",
                kind: "unexpected"
            ),
        ])
    }

    @Test
    func repositoryStorageIntegrityReportClassifiesHealthyStorage() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)

        try await repository.appendEvent(Self.checkpointEvent(
            id: "event-checkpoint",
            checkpointID: "checkpoint-1",
            timestamp: 1_800_000_000
        ))

        let report = try await repository.storageIntegrityReport(validationLimit: 10)
        let projectionCountValidation = try #require(report.projectionCountValidation)
        let projectionKeyValidation = try #require(report.projectionKeyValidation)

        #expect(report.status == "healthy")
        #expect(report.repairRecommended == false)
        #expect(report.storageSummary.eventCount == 1)
        #expect(report.storageSummary.latestEventSequence == 1)
        #expect(report.storageSummary.checkpointCount == 1)
        #expect(report.ledgerValidation.checkedEventCount == 1)
        #expect(report.ledgerValidation.invalidEventCount == 0)
        #expect(report.ledgerValidation.truncated == false)
        #expect(projectionCountValidation.comparedProjectionCounts)
        #expect(projectionCountValidation.mismatches.isEmpty)
        #expect(projectionKeyValidation.comparedProjectionKeys)
        #expect(projectionKeyValidation.mismatches.isEmpty)
    }

    @Test
    func repositoryStorageIntegrityReportClassifiesProjectionDrift() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let timestamp = Date(timeIntervalSince1970: 1_800_000_000)
        let session = ProvenanceSessionRecord(
            id: "session-authoritative",
            agentKind: "codex",
            status: "active",
            updatedAt: timestamp
        )
        let repository = try ProvenanceSQLiteRepository(url: url)

        try await repository.appendEvent(
            ProvenanceEvent(
                id: "event-session",
                eventType: .sessionObserved,
                timestamp: timestamp,
                sessionID: session.id,
                source: .observed,
                confidence: .high,
                payload: ProvenanceEventPayload(session: session)
            )
        )

        let database = try ProvenanceSQLiteDatabase(url: url)
        try database.execute(
            """
            DELETE FROM provenance_sessions;
            INSERT INTO provenance_sessions (
                id,
                agent_kind,
                status,
                updated_at_seconds
            ) VALUES (
                'session-stale',
                'codex',
                'active',
                1800000010
            )
            """
        )

        let report = try await repository.storageIntegrityReport(validationLimit: 10)
        let projectionCountValidation = try #require(report.projectionCountValidation)
        let projectionKeyValidation = try #require(report.projectionKeyValidation)

        #expect(report.status == "projection_drift")
        #expect(report.repairRecommended)
        #expect(projectionCountValidation.mismatches.isEmpty)
        #expect(projectionKeyValidation.mismatches == [
            ProvenanceSQLiteProjectionKeyMismatch(
                tableName: "provenance_sessions",
                key: "session-authoritative",
                kind: "missing"
            ),
            ProvenanceSQLiteProjectionKeyMismatch(
                tableName: "provenance_sessions",
                key: "session-stale",
                kind: "unexpected"
            ),
        ])
    }

    @Test
    func repositoryStorageIntegrityReportClassifiesTruncatedValidation() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)

        try await repository.appendEvent(Self.checkpointEvent(
            id: "event-first",
            checkpointID: "checkpoint-first",
            timestamp: 1_800_000_000
        ))
        try await repository.appendEvent(Self.checkpointEvent(
            id: "event-second",
            checkpointID: "checkpoint-second",
            timestamp: 1_800_000_010
        ))

        let report = try await repository.storageIntegrityReport(validationLimit: 1)
        let projectionCountValidation = try #require(report.projectionCountValidation)
        let projectionKeyValidation = try #require(report.projectionKeyValidation)

        #expect(report.status == "validation_truncated")
        #expect(report.repairRecommended == false)
        #expect(report.ledgerValidation.truncated)
        #expect(projectionCountValidation.truncated)
        #expect(projectionCountValidation.comparedProjectionCounts == false)
        #expect(projectionKeyValidation.truncated)
        #expect(projectionKeyValidation.comparedProjectionKeys == false)
    }

    @Test
    func repositoryStorageIntegrityReportSkipsProjectionChecksForInvalidLedger() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)

        try await repository.appendEvent(Self.checkpointEvent(
            id: "event-checkpoint",
            checkpointID: "checkpoint-1",
            timestamp: 1_800_000_000
        ))

        let database = try ProvenanceSQLiteDatabase(url: url)
        try database.execute(
            """
            UPDATE provenance_events
            SET payload_json = '{'
            WHERE id = 'event-checkpoint'
            """
        )

        let report = try await repository.storageIntegrityReport(validationLimit: 10)

        #expect(report.status == "ledger_invalid")
        #expect(report.repairRecommended == false)
        #expect(report.storageSummary.eventCount == 1)
        #expect(report.storageSummary.checkpointCount == 1)
        #expect(report.ledgerValidation.checkedEventCount == 1)
        #expect(report.ledgerValidation.invalidEventCount == 1)
        #expect(report.ledgerValidation.firstInvalidIssue?.eventID == "event-checkpoint")
        #expect(report.projectionCountValidation == nil)
        #expect(report.projectionKeyValidation == nil)
    }

    @Test
    func repositoryStorageIntegrityRepairSkipsHealthyStorage() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)

        try await repository.appendEvent(Self.checkpointEvent(
            id: "event-checkpoint",
            checkpointID: "checkpoint-1",
            timestamp: 1_800_000_000
        ))

        let attemptedAt = Date(timeIntervalSince1970: 1_800_000_030)

        let report = try await repository.repairStorageIntegrity(
            validationLimit: 10,
            attemptedAt: attemptedAt
        )
        let attempts = try await repository.storageRepairAttempts(limit: 10)

        #expect(report.initialIntegrityReport.status == "healthy")
        #expect(report.initialIntegrityReport.repairRecommended == false)
        #expect(report.repairAttempted == false)
        #expect(report.projectionRepairReport == nil)
        #expect(report.postRepairIntegrityReport == nil)
        #expect(attempts == [
            ProvenanceSQLiteStorageRepairAttempt(
                sequence: 1,
                attemptedAt: attemptedAt,
                initialStatus: "healthy",
                repairRecommended: false,
                repairAttempted: false,
                repaired: false,
                replayedEventCount: 0,
                postRepairStatus: nil
            ),
        ])
        #expect(try await repository.validateProjectionKeys(limit: 10).mismatches.isEmpty)
    }

    @Test
    func repositoryStorageIntegrityRepairRebuildsRecommendedProjectionDrift() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let timestamp = Date(timeIntervalSince1970: 1_800_000_000)
        let session = ProvenanceSessionRecord(
            id: "session-authoritative",
            agentKind: "codex",
            status: "active",
            updatedAt: timestamp
        )
        let repository = try ProvenanceSQLiteRepository(url: url)

        try await repository.appendEvent(
            ProvenanceEvent(
                id: "event-session",
                eventType: .sessionObserved,
                timestamp: timestamp,
                sessionID: session.id,
                source: .observed,
                confidence: .high,
                payload: ProvenanceEventPayload(session: session)
            )
        )

        let database = try ProvenanceSQLiteDatabase(url: url)
        try database.execute(
            """
            DELETE FROM provenance_sessions;
            INSERT INTO provenance_sessions (
                id,
                agent_kind,
                status,
                updated_at_seconds
            ) VALUES (
                'session-stale',
                'codex',
                'active',
                1800000010
            )
            """
        )

        let attemptedAt = Date(timeIntervalSince1970: 1_800_000_030)

        let report = try await repository.repairStorageIntegrity(
            validationLimit: 10,
            mismatchLimit: 1,
            rebuildBatchSize: 1,
            attemptedAt: attemptedAt
        )
        let projectionRepairReport = try #require(report.projectionRepairReport)
        let postRepairIntegrityReport = try #require(report.postRepairIntegrityReport)
        let attempts = try await repository.storageRepairAttempts(limit: 10)

        #expect(report.initialIntegrityReport.status == "projection_drift")
        #expect(report.initialIntegrityReport.repairRecommended)
        #expect(report.repairAttempted)
        #expect(projectionRepairReport.repaired)
        #expect(projectionRepairReport.replayedEventCount == 1)
        #expect(projectionRepairReport.validation.truncatedMismatches)
        #expect(projectionRepairReport.postRepairValidation?.mismatches.isEmpty == true)
        #expect(postRepairIntegrityReport.status == "healthy")
        #expect(postRepairIntegrityReport.repairRecommended == false)
        #expect(attempts == [
            ProvenanceSQLiteStorageRepairAttempt(
                sequence: 1,
                attemptedAt: attemptedAt,
                initialStatus: "projection_drift",
                repairRecommended: true,
                repairAttempted: true,
                repaired: true,
                replayedEventCount: 1,
                postRepairStatus: "healthy"
            ),
        ])
        #expect(try await repository.session(id: session.id) == session)
        #expect(try await repository.session(id: "session-stale") == nil)
    }

    @Test
    func repositoryStorageIntegrityRepairSkipsUnsafeInvalidLedger() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)

        try await repository.appendEvent(Self.checkpointEvent(
            id: "event-checkpoint",
            checkpointID: "checkpoint-1",
            timestamp: 1_800_000_000
        ))

        let database = try ProvenanceSQLiteDatabase(url: url)
        try database.execute(
            """
            UPDATE provenance_events
            SET payload_json = '{'
            WHERE id = 'event-checkpoint'
            """
        )

        let attemptedAt = Date(timeIntervalSince1970: 1_800_000_030)

        let report = try await repository.repairStorageIntegrity(
            validationLimit: 10,
            attemptedAt: attemptedAt
        )
        let attempts = try await repository.storageRepairAttempts(limit: 10)

        #expect(report.initialIntegrityReport.status == "ledger_invalid")
        #expect(report.initialIntegrityReport.repairRecommended == false)
        #expect(report.repairAttempted == false)
        #expect(report.projectionRepairReport == nil)
        #expect(report.postRepairIntegrityReport == nil)
        #expect(attempts == [
            ProvenanceSQLiteStorageRepairAttempt(
                sequence: 1,
                attemptedAt: attemptedAt,
                initialStatus: "ledger_invalid",
                repairRecommended: false,
                repairAttempted: false,
                repaired: false,
                replayedEventCount: 0,
                postRepairStatus: nil
            ),
        ])
        #expect(try await repository.storageSummary().checkpointCount == 1)
    }

    @Test
    func repositoryReadsStorageRepairAttemptsNewestFirstWithLimit() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)
        let firstAttemptAt = Date(timeIntervalSince1970: 1_800_000_030)
        let secondAttemptAt = Date(timeIntervalSince1970: 1_800_000_040)

        _ = try await repository.repairStorageIntegrity(
            validationLimit: 10,
            attemptedAt: firstAttemptAt
        )
        _ = try await repository.repairStorageIntegrity(
            validationLimit: 10,
            attemptedAt: secondAttemptAt
        )

        let limitedAttempts = try await repository.storageRepairAttempts(limit: 1)
        let zeroLimitAttempts = try await repository.storageRepairAttempts(limit: -1)

        #expect(limitedAttempts == [
            ProvenanceSQLiteStorageRepairAttempt(
                sequence: 2,
                attemptedAt: secondAttemptAt,
                initialStatus: "healthy",
                repairRecommended: false,
                repairAttempted: false,
                repaired: false,
                replayedEventCount: 0,
                postRepairStatus: nil
            ),
        ])
        #expect(zeroLimitAttempts.isEmpty)
    }

    @Test
    func sqliteRepositorySatisfiesEngineClientContract() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let timestamp = Date(timeIntervalSince1970: 1_800_000_000)
        let repositoryRecord = ProvenanceRepositoryRecord(
            id: "repository-1",
            path: "/repos/project",
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let worktree = ProvenanceWorktreeRecord(
            id: "worktree-1",
            repositoryID: repositoryRecord.id,
            path: repositoryRecord.path,
            isDirty: false,
            status: "active",
            updatedAt: timestamp
        )
        let parentSession = ProvenanceSessionRecord(
            id: "session-parent",
            agentKind: "codex",
            worktreeID: worktree.id,
            status: "active",
            startedAt: timestamp,
            updatedAt: timestamp
        )
        let repository = try ProvenanceSQLiteRepository(url: url)
        let client: any ProvenanceEngineClient = repository

        let health = try await client.health()
        let append = try await client.appendEvent(
            ProvenanceAppendEventRequest(
                event: ProvenanceEvent(
                    id: "event-bootstrap",
                    eventType: .sessionObserved,
                    timestamp: timestamp,
                    repositoryID: repositoryRecord.id,
                    worktreeID: worktree.id,
                    sessionID: parentSession.id,
                    source: .observed,
                    confidence: .high,
                    payload: ProvenanceEventPayload(
                        repository: repositoryRecord,
                        worktree: worktree,
                        session: parentSession
                    )
                )
            )
        )
        let lifecycle = await client.recordSessionLifecycle(
            ProvenanceSessionLifecycleRequest(
                phase: .started,
                parentSessionID: parentSession.id,
                agentKind: "codex",
                workspaceID: "workspace-1",
                surfaceID: "surface-1",
                workingDirectory: repositoryRecord.path,
                externalIdentityKind: "worker",
                externalIdentityValue: "child-1",
                timestamp: Date(timeIntervalSince1970: 1_800_000_010)
            )
        )
        let tree = try await client.sessionTree(
            ProvenanceSessionTreeRequest(rootSessionID: parentSession.id)
        )
        let worktrees = try await client.worktrees(ProvenanceWorktreeListRequest())
        let context = try await client.currentContext(
            ProvenanceCurrentContextRequest(repositoryPath: repositoryRecord.path)
        )
        let summary = try await repository.storageSummary()

        #expect(health == ProvenanceEngineHealth(
            status: .available,
            version: "0.1.0",
            capabilities: ProvenanceEngineCapability.allCases
        ))
        #expect(append == ProvenanceAppendEventResponse(
            eventID: "event-bootstrap",
            eventType: ProvenanceEventType.sessionObserved.rawValue
        ))
        #expect(lifecycle.accepted)
        let childSessionID = try #require(lifecycle.sessionID)
        #expect(tree.sessions.map(\.id) == [
            parentSession.id,
            childSessionID,
        ])
        #expect(worktrees.worktrees == [
            ProvenanceWorktreeListEntry(worktree: worktree, repository: repositoryRecord),
        ])
        #expect(context.found)
        #expect(context.worktree == worktree)
        #expect(context.activeSessions.map(\.session.id).contains(parentSession.id))
        #expect(summary.eventCount == 2)
        #expect(summary.latestEventSequence == 2)
        #expect(summary.repositoryCount == 1)
        #expect(summary.worktreeCount == 1)
        #expect(summary.sessionCount == 2)
        #expect(summary.sessionRelationshipCount == 1)
        #expect(summary.externalIdentityCount == 1)
    }

    @Test
    func repositoryReturnsNilForMissingEvent() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)

        #expect(try await repository.event(id: "missing-event") == nil)
    }

    @Test
    func repositoryUpsertsAndReadsSessionProjectionAfterReopen() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let firstSession = ProvenanceSessionRecord(
            id: "session-1",
            agentKind: "codex",
            workspaceID: "workspace-1",
            surfaceID: "surface-1",
            worktreeID: "worktree-1",
            cwd: "/worktree",
            status: "active",
            startedAt: Date(timeIntervalSince1970: 1_800_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_800_000_001)
        )
        let updatedSession = ProvenanceSessionRecord(
            id: firstSession.id,
            agentKind: firstSession.agentKind,
            workspaceID: firstSession.workspaceID,
            surfaceID: firstSession.surfaceID,
            worktreeID: firstSession.worktreeID,
            cwd: firstSession.cwd,
            status: "completed",
            startedAt: firstSession.startedAt,
            updatedAt: Date(timeIntervalSince1970: 1_800_000_010)
        )

        let writer = try ProvenanceSQLiteRepository(url: url)
        try await writer.appendEvent(
            ProvenanceEvent(
                id: "event-1",
                eventType: .sessionObserved,
                timestamp: Date(timeIntervalSince1970: 1_800_000_001),
                sessionID: firstSession.id,
                source: .observed,
                confidence: .high,
                payload: ProvenanceEventPayload(session: firstSession)
            )
        )
        try await writer.appendEvent(
            ProvenanceEvent(
                id: "event-2",
                eventType: .sessionObserved,
                timestamp: Date(timeIntervalSince1970: 1_800_000_010),
                sessionID: updatedSession.id,
                source: .observed,
                confidence: .high,
                payload: ProvenanceEventPayload(session: updatedSession)
            )
        )

        let reader = try ProvenanceSQLiteRepository(url: url)

        #expect(try await reader.session(id: firstSession.id) == updatedSession)
    }

    @Test
    func repositoryReturnsNilForMissingSessionProjection() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)

        #expect(try await repository.session(id: "missing-session") == nil)
    }

    @Test
    func repositoryProjectsSessionTreeRelationshipsAndExternalIdentitiesAfterReopen() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let timestamp = Date(timeIntervalSince1970: 1_800_000_000)
        let rootSession = ProvenanceSessionRecord(
            id: "session-root",
            agentKind: "codex",
            status: "active",
            startedAt: timestamp,
            updatedAt: timestamp
        )
        let olderChild = ProvenanceSessionRecord(
            id: "session-older-child",
            agentKind: "codex",
            status: "completed",
            startedAt: Date(timeIntervalSince1970: 1_800_000_001),
            updatedAt: Date(timeIntervalSince1970: 1_800_000_003)
        )
        let newerChild = ProvenanceSessionRecord(
            id: "session-newer-child",
            agentKind: "codex",
            status: "active",
            startedAt: Date(timeIntervalSince1970: 1_800_000_002),
            updatedAt: Date(timeIntervalSince1970: 1_800_000_004)
        )
        let grandchild = ProvenanceSessionRecord(
            id: "session-grandchild",
            agentKind: "codex",
            status: "active",
            startedAt: Date(timeIntervalSince1970: 1_800_000_005),
            updatedAt: Date(timeIntervalSince1970: 1_800_000_006)
        )
        let olderRelationship = ProvenanceSessionRelationshipRecord(
            sessionID: olderChild.id,
            parentSessionID: rootSession.id,
            rootSessionID: rootSession.id,
            depth: 1,
            source: .observed,
            confidence: .high,
            createdAt: olderChild.startedAt ?? olderChild.updatedAt,
            updatedAt: olderChild.updatedAt
        )
        let newerRelationship = ProvenanceSessionRelationshipRecord(
            sessionID: newerChild.id,
            parentSessionID: rootSession.id,
            rootSessionID: rootSession.id,
            depth: 1,
            source: .observed,
            confidence: .medium,
            createdAt: newerChild.startedAt ?? newerChild.updatedAt,
            updatedAt: newerChild.updatedAt
        )
        let grandchildRelationship = ProvenanceSessionRelationshipRecord(
            sessionID: grandchild.id,
            parentSessionID: newerChild.id,
            rootSessionID: rootSession.id,
            inboundDelegationID: "delegation-1",
            depth: 2,
            source: .declared,
            confidence: .medium,
            createdAt: grandchild.startedAt ?? grandchild.updatedAt,
            updatedAt: grandchild.updatedAt
        )
        let childIdentity = ProvenanceExternalIdentityRecord(
            id: "identity-child",
            sessionID: newerChild.id,
            system: "codex",
            kind: "worker",
            externalID: "external-child",
            source: .observed,
            confidence: .high,
            createdAt: newerChild.startedAt ?? newerChild.updatedAt,
            updatedAt: newerChild.updatedAt
        )
        let grandchildIdentity = ProvenanceExternalIdentityRecord(
            id: "identity-grandchild",
            sessionID: grandchild.id,
            system: "codex",
            kind: "thread",
            externalID: "external-grandchild",
            source: .declared,
            confidence: .medium,
            createdAt: grandchild.startedAt ?? grandchild.updatedAt,
            updatedAt: grandchild.updatedAt
        )

        let writer = try ProvenanceSQLiteRepository(url: url)
        for session in [rootSession, olderChild, newerChild, grandchild] {
            try await writer.appendEvent(
                ProvenanceEvent(
                    id: "event-\(session.id)",
                    eventType: .sessionObserved,
                    timestamp: session.updatedAt,
                    sessionID: session.id,
                    source: .observed,
                    confidence: .high,
                    payload: ProvenanceEventPayload(session: session)
                )
            )
        }
        try await writer.appendEvent(
            ProvenanceEvent(
                id: "event-older-relationship",
                eventType: .sessionStarted,
                timestamp: olderRelationship.updatedAt,
                sessionID: olderChild.id,
                source: .observed,
                confidence: .high,
                payload: ProvenanceEventPayload(sessionRelationship: olderRelationship)
            )
        )
        try await writer.appendEvent(
            ProvenanceEvent(
                id: "event-newer-relationship",
                eventType: .sessionStarted,
                timestamp: newerRelationship.updatedAt,
                sessionID: newerChild.id,
                source: .observed,
                confidence: .medium,
                payload: ProvenanceEventPayload(
                    sessionRelationship: newerRelationship,
                    externalIdentities: [childIdentity]
                )
            )
        )
        try await writer.appendEvent(
            ProvenanceEvent(
                id: "event-grandchild-relationship",
                eventType: .sessionStarted,
                timestamp: grandchildRelationship.updatedAt,
                sessionID: grandchild.id,
                source: .declared,
                confidence: .medium,
                payload: ProvenanceEventPayload(
                    sessionRelationship: grandchildRelationship,
                    externalIdentities: [grandchildIdentity]
                )
            )
        )

        let reader = try ProvenanceSQLiteRepository(url: url)
        let tree = try await reader.sessionTree(ProvenanceSessionTreeRequest(rootSessionID: rootSession.id))

        #expect(tree.found)
        #expect(tree.reason == nil)
        #expect(tree.sessions.map(\.id) == [
            rootSession.id,
            olderChild.id,
            newerChild.id,
            grandchild.id,
        ])
        #expect(tree.relationships == [
            olderRelationship,
            newerRelationship,
            grandchildRelationship,
        ])
        #expect(tree.externalIdentities == [
            childIdentity,
            grandchildIdentity,
        ])
        #expect(try await reader.parentSession(for: newerChild.id) == newerRelationship)
        #expect(try await reader.childSessions(for: rootSession.id) == [
            olderRelationship,
            newerRelationship,
        ])
        #expect(try await reader.externalIdentities(sessionID: newerChild.id) == [childIdentity])
    }

    @Test
    func repositorySessionTreeReturnsMissingReasonForUnknownRoot() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)

        let tree = try await repository.sessionTree(
            ProvenanceSessionTreeRequest(rootSessionID: "missing-session")
        )

        #expect(tree == ProvenanceSessionTreeResponse(
            rootSessionID: "missing-session",
            found: false,
            reason: "no_session",
            sessions: [],
            relationships: [],
            externalIdentities: []
        ))
    }

    @Test
    func repositorySessionTreeDoesNotResolveDanglingRelationshipsForMissingRoot() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let childSession = ProvenanceSessionRecord(
            id: "session-child",
            agentKind: "codex",
            status: "active",
            updatedAt: Date(timeIntervalSince1970: 1_800_000_001)
        )
        let danglingRelationship = ProvenanceSessionRelationshipRecord(
            sessionID: childSession.id,
            parentSessionID: "missing-root",
            rootSessionID: "missing-root",
            depth: 1,
            source: .observed,
            confidence: .medium,
            createdAt: childSession.updatedAt,
            updatedAt: childSession.updatedAt
        )
        let repository = try ProvenanceSQLiteRepository(url: url)

        try await repository.appendEvent(
            ProvenanceEvent(
                id: "event-dangling-child",
                eventType: .sessionStarted,
                timestamp: childSession.updatedAt,
                sessionID: childSession.id,
                source: .observed,
                confidence: .medium,
                payload: ProvenanceEventPayload(
                    session: childSession,
                    sessionRelationship: danglingRelationship
                )
            )
        )

        let tree = try await repository.sessionTree(
            ProvenanceSessionTreeRequest(rootSessionID: "missing-root")
        )

        #expect(tree == ProvenanceSessionTreeResponse(
            rootSessionID: "missing-root",
            found: false,
            reason: "no_session",
            sessions: [],
            relationships: [],
            externalIdentities: []
        ))
    }

    @Test
    func repositorySessionTreeHonorsNonNegativeLimit() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let rootSession = ProvenanceSessionRecord(
            id: "session-root",
            agentKind: "codex",
            status: "active",
            updatedAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
        let childSession = ProvenanceSessionRecord(
            id: "session-child",
            agentKind: "codex",
            status: "active",
            updatedAt: Date(timeIntervalSince1970: 1_800_000_001)
        )
        let grandchildSession = ProvenanceSessionRecord(
            id: "session-grandchild",
            agentKind: "codex",
            status: "active",
            updatedAt: Date(timeIntervalSince1970: 1_800_000_002)
        )
        let relationship = ProvenanceSessionRelationshipRecord(
            sessionID: childSession.id,
            parentSessionID: rootSession.id,
            rootSessionID: rootSession.id,
            depth: 1,
            source: .observed,
            confidence: .high,
            createdAt: childSession.updatedAt,
            updatedAt: childSession.updatedAt
        )
        let grandchildRelationship = ProvenanceSessionRelationshipRecord(
            sessionID: grandchildSession.id,
            parentSessionID: childSession.id,
            rootSessionID: rootSession.id,
            depth: 2,
            source: .observed,
            confidence: .high,
            createdAt: grandchildSession.updatedAt,
            updatedAt: grandchildSession.updatedAt
        )
        let repository = try ProvenanceSQLiteRepository(url: url)

        try await repository.appendEvent(
            ProvenanceEvent(
                id: "event-root",
                eventType: .sessionObserved,
                timestamp: rootSession.updatedAt,
                sessionID: rootSession.id,
                source: .observed,
                confidence: .high,
                payload: ProvenanceEventPayload(session: rootSession)
            )
        )
        try await repository.appendEvent(
            ProvenanceEvent(
                id: "event-child",
                eventType: .sessionStarted,
                timestamp: childSession.updatedAt,
                sessionID: childSession.id,
                source: .observed,
                confidence: .high,
                payload: ProvenanceEventPayload(
                    session: childSession,
                    sessionRelationship: relationship
                )
            )
        )
        try await repository.appendEvent(
            ProvenanceEvent(
                id: "event-grandchild",
                eventType: .sessionStarted,
                timestamp: grandchildSession.updatedAt,
                sessionID: grandchildSession.id,
                source: .observed,
                confidence: .high,
                payload: ProvenanceEventPayload(
                    session: grandchildSession,
                    sessionRelationship: grandchildRelationship
                )
            )
        )

        let oneRowTree = try await repository.sessionTree(
            ProvenanceSessionTreeRequest(rootSessionID: rootSession.id, limit: 1)
        )
        let threeRowTree = try await repository.sessionTree(
            ProvenanceSessionTreeRequest(rootSessionID: rootSession.id, limit: 3)
        )
        let zeroRowTree = try await repository.sessionTree(
            ProvenanceSessionTreeRequest(rootSessionID: rootSession.id, limit: -1)
        )

        #expect(oneRowTree.sessions == [rootSession])
        #expect(oneRowTree.relationships.isEmpty)
        #expect(threeRowTree.sessions == [rootSession, childSession])
        #expect(threeRowTree.relationships == [relationship])
        #expect(threeRowTree.sessions.count + threeRowTree.relationships.count == 3)
        #expect(zeroRowTree.found == false)
        #expect(zeroRowTree.reason == "no_session")
        #expect(zeroRowTree.sessions.isEmpty)
        #expect(zeroRowTree.relationships.isEmpty)
    }

    @Test
    func repositoryRecordsSessionLifecycleThroughContractAfterReopen() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let rootTimestamp = Date(timeIntervalSince1970: 1_800_000_000)
        let parentTimestamp = Date(timeIntervalSince1970: 1_800_000_001)
        let childTimestamp = Date(timeIntervalSince1970: 1_800_000_002.123456)
        let rootSession = ProvenanceSessionRecord(
            id: "session-root",
            agentKind: "codex",
            status: "active",
            startedAt: rootTimestamp,
            updatedAt: rootTimestamp
        )
        let parentSession = ProvenanceSessionRecord(
            id: "session-parent",
            agentKind: "codex",
            status: "active",
            startedAt: parentTimestamp,
            updatedAt: parentTimestamp
        )
        let parentRelationship = ProvenanceSessionRelationshipRecord(
            sessionID: parentSession.id,
            parentSessionID: rootSession.id,
            rootSessionID: rootSession.id,
            depth: 1,
            source: .observed,
            confidence: .high,
            createdAt: parentTimestamp,
            updatedAt: parentTimestamp
        )
        let request = ProvenanceSessionLifecycleRequest(
            phase: .started,
            parentSessionID: parentSession.id,
            agentKind: "codex",
            workspaceID: "workspace-1",
            surfaceID: "surface-1",
            workingDirectory: "/repos/project",
            externalIdentityKind: "worker",
            externalIdentityValue: "native-child-1",
            displayName: "Child worker",
            timestamp: childTimestamp
        )
        let stableIDFactory = ProvenanceStableIDFactory()
        let expectedChildSessionID = stableIDFactory.subsessionSessionID(
            agentKind: request.agentKind,
            parentSessionID: parentSession.id,
            identityKind: "worker",
            identityValue: "native-child-1"
        )
        let expectedExternalIdentityID = stableIDFactory.externalIdentityID(
            system: request.agentKind,
            kind: "worker",
            externalID: "native-child-1"
        )
        let repository = try ProvenanceSQLiteRepository(url: url)
        try await repository.appendEvent(
            ProvenanceEvent(
                id: "event-root",
                eventType: .sessionObserved,
                timestamp: rootTimestamp,
                sessionID: rootSession.id,
                source: .observed,
                confidence: .high,
                payload: ProvenanceEventPayload(session: rootSession)
            )
        )
        try await repository.appendEvent(
            ProvenanceEvent(
                id: "event-parent",
                eventType: .sessionStarted,
                timestamp: parentTimestamp,
                sessionID: parentSession.id,
                source: .observed,
                confidence: .high,
                payload: ProvenanceEventPayload(
                    session: parentSession,
                    sessionRelationship: parentRelationship
                )
            )
        )

        let builtEvent = try await repository.sessionLifecycleEvent(for: request)
        let response = await repository.recordSessionLifecycle(request)
        let duplicateResponse = await repository.recordSessionLifecycle(request)
        let reader = try ProvenanceSQLiteRepository(url: url)
        let storedEvent = try await reader.event(id: builtEvent.id)
        let tree = try await reader.sessionTree(
            ProvenanceSessionTreeRequest(rootSessionID: rootSession.id)
        )

        #expect(builtEvent.id == stableIDFactory.sessionLifecycleEventID(
            phase: request.phase.rawValue,
            sessionID: expectedChildSessionID,
            timestamp: childTimestamp
        ))
        #expect(builtEvent.eventType == .sessionStarted)
        #expect(builtEvent.sessionID == expectedChildSessionID)
        #expect(builtEvent.payload.session == ProvenanceSessionRecord(
            id: expectedChildSessionID,
            agentKind: "codex",
            workspaceID: "workspace-1",
            surfaceID: "surface-1",
            cwd: "/repos/project",
            status: "active",
            startedAt: childTimestamp,
            updatedAt: childTimestamp
        ))
        #expect(builtEvent.payload.sessionRelationship == ProvenanceSessionRelationshipRecord(
            sessionID: expectedChildSessionID,
            parentSessionID: parentSession.id,
            rootSessionID: rootSession.id,
            depth: 2,
            source: .observed,
            confidence: .high,
            createdAt: childTimestamp,
            updatedAt: childTimestamp
        ))
        #expect(builtEvent.payload.externalIdentities == [
            ProvenanceExternalIdentityRecord(
                id: expectedExternalIdentityID,
                sessionID: expectedChildSessionID,
                system: "codex",
                kind: "worker",
                externalID: "native-child-1",
                source: .observed,
                confidence: .high,
                createdAt: childTimestamp,
                updatedAt: childTimestamp
            ),
        ])
        #expect(response == ProvenanceSessionLifecycleResponse(
            accepted: true,
            eventID: builtEvent.id,
            sessionID: expectedChildSessionID,
            relationshipSessionID: expectedChildSessionID,
            externalIdentityID: expectedExternalIdentityID
        ))
        #expect(duplicateResponse.accepted == false)
        #expect(duplicateResponse.eventID == builtEvent.id)
        #expect(duplicateResponse.sessionID == expectedChildSessionID)
        #expect(duplicateResponse.relationshipSessionID == expectedChildSessionID)
        #expect(duplicateResponse.externalIdentityID == expectedExternalIdentityID)
        #expect(duplicateResponse.errorDescription?.contains("UNIQUE") == true
            || duplicateResponse.errorDescription?.contains("unique") == true)
        #expect(storedEvent == builtEvent)
        #expect(tree.sessions.map(\.id) == [
            rootSession.id,
            parentSession.id,
            expectedChildSessionID,
        ])
        #expect(tree.relationships == [
            parentRelationship,
            builtEvent.payload.sessionRelationship,
        ])
        #expect(tree.externalIdentities == builtEvent.payload.externalIdentities)
    }

    @Test
    func repositoryRecordsSessionStopWithoutClearingStartTime() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let parentTimestamp = Date(timeIntervalSince1970: 1_800_000_000)
        let childStartTimestamp = Date(timeIntervalSince1970: 1_800_000_010)
        let childStopTimestamp = Date(timeIntervalSince1970: 1_800_000_020)
        let parentSession = ProvenanceSessionRecord(
            id: "session-parent",
            agentKind: "codex",
            status: "active",
            startedAt: parentTimestamp,
            updatedAt: parentTimestamp
        )
        let startRequest = ProvenanceSessionLifecycleRequest(
            phase: .started,
            parentSessionID: parentSession.id,
            agentKind: "codex",
            workspaceID: "workspace-1",
            surfaceID: "surface-1",
            workingDirectory: "/repos/project",
            externalIdentityKind: "worker",
            externalIdentityValue: "native-child-1",
            timestamp: childStartTimestamp
        )
        let stopRequest = ProvenanceSessionLifecycleRequest(
            phase: .stopped,
            parentSessionID: parentSession.id,
            agentKind: "codex",
            workspaceID: "workspace-1",
            surfaceID: "surface-1",
            workingDirectory: "/repos/project",
            externalIdentityKind: "worker",
            externalIdentityValue: "native-child-1",
            timestamp: childStopTimestamp
        )
        let stableIDFactory = ProvenanceStableIDFactory()
        let expectedChildSessionID = stableIDFactory.subsessionSessionID(
            agentKind: startRequest.agentKind,
            parentSessionID: parentSession.id,
            identityKind: "worker",
            identityValue: "native-child-1"
        )
        let repository = try ProvenanceSQLiteRepository(url: url)
        try await repository.appendEvent(
            ProvenanceEvent(
                id: "event-parent",
                eventType: .sessionObserved,
                timestamp: parentTimestamp,
                sessionID: parentSession.id,
                source: .observed,
                confidence: .high,
                payload: ProvenanceEventPayload(session: parentSession)
            )
        )

        let startResponse = await repository.recordSessionLifecycle(startRequest)
        let stopEvent = try await repository.sessionLifecycleEvent(for: stopRequest)
        let stopResponse = await repository.recordSessionLifecycle(stopRequest)
        let storedSession = try await repository.session(id: expectedChildSessionID)
        let storedStopEvent = try await repository.event(id: stopEvent.id)

        #expect(startResponse.accepted)
        #expect(stopResponse.accepted)
        #expect(stopResponse.sessionID == expectedChildSessionID)
        #expect(stopEvent.eventType == .sessionStopped)
        #expect(stopEvent.payload.session?.status == "completed")
        #expect(stopEvent.payload.session?.startedAt == childStartTimestamp)
        #expect(storedStopEvent == stopEvent)
        #expect(storedSession == ProvenanceSessionRecord(
            id: expectedChildSessionID,
            agentKind: "codex",
            workspaceID: "workspace-1",
            surfaceID: "surface-1",
            cwd: "/repos/project",
            status: "completed",
            startedAt: childStartTimestamp,
            updatedAt: childStopTimestamp
        ))
    }

    @Test
    func repositoryListsWorktreesNewestFirstWithRepositoryFilterAndLimit() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let firstRepository = ProvenanceRepositoryRecord(
            id: "repository-1",
            path: "/repos/one",
            commonDirectory: "/repos/one/.git",
            remoteSlug: "owner/one",
            createdAt: Date(timeIntervalSince1970: 1_800_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_800_000_001)
        )
        let secondRepository = ProvenanceRepositoryRecord(
            id: "repository-2",
            path: "/repos/two",
            commonDirectory: "/repos/two/.git",
            remoteSlug: "owner/two",
            createdAt: Date(timeIntervalSince1970: 1_800_000_010),
            updatedAt: Date(timeIntervalSince1970: 1_800_000_011)
        )
        let oldestWorktree = ProvenanceWorktreeRecord(
            id: "worktree-oldest",
            repositoryID: firstRepository.id,
            path: "/repos/one/oldest",
            branch: "feature/oldest",
            baseCommit: "base-1",
            currentHEAD: "head-1",
            isDirty: false,
            status: "active",
            lastReconciledAt: Date(timeIntervalSince1970: 1_800_000_002),
            updatedAt: Date(timeIntervalSince1970: 1_800_000_003)
        )
        let newestWorktree = ProvenanceWorktreeRecord(
            id: "worktree-newest",
            repositoryID: firstRepository.id,
            path: "/repos/one/newest",
            branch: "feature/newest",
            baseCommit: "base-2",
            currentHEAD: "head-2",
            isDirty: true,
            status: "active",
            lastReconciledAt: Date(timeIntervalSince1970: 1_800_000_012),
            updatedAt: Date(timeIntervalSince1970: 1_800_000_013)
        )
        let otherRepositoryWorktree = ProvenanceWorktreeRecord(
            id: "worktree-other",
            repositoryID: secondRepository.id,
            path: "/repos/two/other",
            branch: "feature/other",
            baseCommit: "base-3",
            currentHEAD: "head-3",
            isDirty: false,
            status: "paused",
            lastReconciledAt: Date(timeIntervalSince1970: 1_800_000_022),
            updatedAt: Date(timeIntervalSince1970: 1_800_000_023)
        )

        let repository = try ProvenanceSQLiteRepository(url: url)
        try await repository.appendEvent(
            ProvenanceEvent(
                id: "event-repository-1",
                eventType: .repositoryObserved,
                timestamp: firstRepository.updatedAt,
                repositoryID: firstRepository.id,
                source: .observed,
                confidence: .high,
                payload: ProvenanceEventPayload(repository: firstRepository)
            )
        )
        try await repository.appendEvent(
            ProvenanceEvent(
                id: "event-repository-2",
                eventType: .repositoryObserved,
                timestamp: secondRepository.updatedAt,
                repositoryID: secondRepository.id,
                source: .observed,
                confidence: .high,
                payload: ProvenanceEventPayload(repository: secondRepository)
            )
        )
        try await repository.appendEvent(
            ProvenanceEvent(
                id: "event-worktree-oldest",
                eventType: .worktreeObserved,
                timestamp: oldestWorktree.updatedAt,
                repositoryID: oldestWorktree.repositoryID,
                worktreeID: oldestWorktree.id,
                source: .observed,
                confidence: .high,
                payload: ProvenanceEventPayload(worktree: oldestWorktree)
            )
        )
        try await repository.appendEvent(
            ProvenanceEvent(
                id: "event-worktree-newest",
                eventType: .worktreeObserved,
                timestamp: newestWorktree.updatedAt,
                repositoryID: newestWorktree.repositoryID,
                worktreeID: newestWorktree.id,
                source: .observed,
                confidence: .high,
                payload: ProvenanceEventPayload(worktree: newestWorktree)
            )
        )
        try await repository.appendEvent(
            ProvenanceEvent(
                id: "event-worktree-other",
                eventType: .worktreeObserved,
                timestamp: otherRepositoryWorktree.updatedAt,
                repositoryID: otherRepositoryWorktree.repositoryID,
                worktreeID: otherRepositoryWorktree.id,
                source: .observed,
                confidence: .high,
                payload: ProvenanceEventPayload(worktree: otherRepositoryWorktree)
            )
        )

        let allWorktrees = try await repository.worktrees(ProvenanceWorktreeListRequest())
        #expect(allWorktrees.worktrees.map(\.worktree.id) == [
            otherRepositoryWorktree.id,
            newestWorktree.id,
            oldestWorktree.id,
        ])

        let firstRepositoryWorktrees = try await repository.worktrees(
            ProvenanceWorktreeListRequest(repositoryID: firstRepository.id, limit: 1)
        )
        #expect(firstRepositoryWorktrees.worktrees == [
            ProvenanceWorktreeListEntry(worktree: newestWorktree, repository: firstRepository),
        ])

        let zeroLimit = try await repository.worktrees(ProvenanceWorktreeListRequest(limit: -1))
        #expect(zeroLimit.worktrees.isEmpty)
    }

    @Test
    func repositoryListsWorktreesWithoutRepositoryProjectionWhenMissing() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let orphanedWorktree = ProvenanceWorktreeRecord(
            id: "worktree-orphaned",
            repositoryID: "missing-repository",
            path: "/repos/orphaned",
            isDirty: false,
            status: "active",
            updatedAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
        let repository = try ProvenanceSQLiteRepository(url: url)

        try await repository.appendEvent(
            ProvenanceEvent(
                id: "event-worktree-orphaned",
                eventType: .worktreeObserved,
                timestamp: orphanedWorktree.updatedAt,
                repositoryID: orphanedWorktree.repositoryID,
                worktreeID: orphanedWorktree.id,
                source: .observed,
                confidence: .medium,
                payload: ProvenanceEventPayload(worktree: orphanedWorktree)
            )
        )

        let response = try await repository.worktrees(ProvenanceWorktreeListRequest())

        #expect(response.worktrees == [
            ProvenanceWorktreeListEntry(worktree: orphanedWorktree, repository: nil),
        ])
    }

    @Test
    func repositoryExplainsLatestFileChangeWithLinkedProjectionsAfterReopen() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let repositoryRecord = ProvenanceRepositoryRecord(
            id: "repository-1",
            path: "/repos/project",
            commonDirectory: "/repos/project/.git",
            remoteSlug: "owner/project",
            createdAt: Date(timeIntervalSince1970: 1_800_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_800_000_001)
        )
        let worktree = ProvenanceWorktreeRecord(
            id: "worktree-1",
            repositoryID: repositoryRecord.id,
            path: "/repos/project",
            branch: "main",
            currentHEAD: "head-1",
            isDirty: true,
            status: "active",
            updatedAt: Date(timeIntervalSince1970: 1_800_000_002)
        )
        let session = ProvenanceSessionRecord(
            id: "session-1",
            agentKind: "codex",
            worktreeID: worktree.id,
            status: "active",
            startedAt: Date(timeIntervalSince1970: 1_800_000_003),
            updatedAt: Date(timeIntervalSince1970: 1_800_000_004)
        )
        let workItem = ProvenanceWorkItemRecord(
            id: "work-item-1",
            title: "Split provenance engine",
            status: "active",
            createdAt: Date(timeIntervalSince1970: 1_800_000_005),
            updatedAt: Date(timeIntervalSince1970: 1_800_000_006)
        )
        let contribution = ProvenanceContributionRecord(
            id: "contribution-1",
            sessionID: session.id,
            worktreeID: worktree.id,
            workItemID: workItem.id,
            declaredIntent: "Move file explanation storage into the engine.",
            expectedScope: ["Sources/ProvenanceEngineSQLite"],
            status: "active",
            startedAt: Date(timeIntervalSince1970: 1_800_000_007),
            assignmentConfidence: .high,
            updatedAt: Date(timeIntervalSince1970: 1_800_000_008)
        )
        let checkpoint = ProvenanceCheckpointRecord(
            id: "checkpoint-1",
            contributionID: contribution.id,
            sequence: 1,
            gitHEAD: "head-1",
            summary: "Added internal file explanation projections.",
            status: "in_progress",
            semanticConfidence: .medium,
            freshness: "fresh",
            createdAt: Date(timeIntervalSince1970: 1_800_000_009)
        )
        let oldChangeSet = ProvenanceChangeSetRecord(
            id: "change-set-old",
            checkpointID: checkpoint.id,
            worktreeID: worktree.id,
            summary: "Old change set.",
            diffFingerprint: "diff-old",
            createdAt: Date(timeIntervalSince1970: 1_800_000_010)
        )
        let newChangeSet = ProvenanceChangeSetRecord(
            id: "change-set-new",
            checkpointID: checkpoint.id,
            worktreeID: worktree.id,
            summary: "New change set.",
            diffFingerprint: "diff-new",
            createdAt: Date(timeIntervalSince1970: 1_800_000_020)
        )
        let oldFileChange = ProvenanceFileChangeRecord(
            id: "file-change-old",
            changeSetID: oldChangeSet.id,
            repositoryID: repositoryRecord.id,
            worktreeID: worktree.id,
            path: "Sources/ProvenanceSQLiteRepository.swift",
            status: "modified",
            beforeHash: "before-old",
            afterHash: "after-old",
            attributionSource: .observed,
            attributionConfidence: .medium,
            updatedAt: Date(timeIntervalSince1970: 1_800_000_011)
        )
        let newFileChange = ProvenanceFileChangeRecord(
            id: "file-change-new",
            changeSetID: newChangeSet.id,
            repositoryID: repositoryRecord.id,
            worktreeID: worktree.id,
            path: oldFileChange.path,
            status: "modified",
            beforeHash: "before-new",
            afterHash: "after-new",
            attributionSource: .declared,
            attributionConfidence: .high,
            updatedAt: Date(timeIntervalSince1970: 1_800_000_021)
        )

        let writer = try ProvenanceSQLiteRepository(url: url)
        try await writer.appendEvent(
            ProvenanceEvent(
                id: "event-bootstrap",
                eventType: .worktreeObserved,
                timestamp: worktree.updatedAt,
                repositoryID: repositoryRecord.id,
                worktreeID: worktree.id,
                sessionID: session.id,
                source: .observed,
                confidence: .high,
                payload: ProvenanceEventPayload(
                    repository: repositoryRecord,
                    worktree: worktree,
                    session: session,
                    workItem: workItem,
                    contribution: contribution,
                    checkpoint: checkpoint
                )
            )
        )
        try await writer.appendEvent(
            ProvenanceEvent(
                id: "event-old-file",
                eventType: "file_change_observed",
                timestamp: oldFileChange.updatedAt,
                repositoryID: repositoryRecord.id,
                worktreeID: worktree.id,
                source: .observed,
                confidence: .medium,
                payload: ProvenanceEventPayload(
                    changeSet: oldChangeSet,
                    fileChanges: [oldFileChange]
                )
            )
        )
        try await writer.appendEvent(
            ProvenanceEvent(
                id: "event-new-file",
                eventType: "file_change_observed",
                timestamp: newFileChange.updatedAt,
                repositoryID: repositoryRecord.id,
                worktreeID: worktree.id,
                source: .declared,
                confidence: .high,
                payload: ProvenanceEventPayload(
                    changeSet: newChangeSet,
                    fileChanges: [newFileChange]
                )
            )
        )

        let reader = try ProvenanceSQLiteRepository(url: url)
        let response = try await reader.fileExplanation(
            ProvenanceFileExplanationRequest(
                worktreeID: worktree.id,
                path: newFileChange.path
            )
        )

        #expect(response == ProvenanceFileExplanationResponse(
            found: true,
            explanation: ProvenanceFileExplanation(
                fileChange: newFileChange,
                changeSet: newChangeSet,
                checkpoint: checkpoint,
                contribution: contribution,
                session: session,
                workItem: workItem,
                worktree: worktree,
                repository: repositoryRecord
            )
        ))
    }

    @Test
    func repositoryFileExplanationReturnsNoFileReasonForUnknownPath() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)

        let response = try await repository.fileExplanation(
            ProvenanceFileExplanationRequest(
                worktreeID: "worktree-1",
                path: "missing.swift"
            )
        )

        #expect(response == ProvenanceFileExplanationResponse(
            found: false,
            reason: "no_file",
            explanation: nil
        ))
    }

    @Test
    func repositoryCurrentContextReturnsNoWorktreeReasonForUnknownPath() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)

        let response = try await repository.currentContext(
            ProvenanceCurrentContextRequest(repositoryPath: "/repos/missing")
        )

        #expect(response == ProvenanceCurrentContextResponse(
            found: false,
            reason: "no_worktree",
            repositoryPath: "/repos/missing",
            worktree: nil,
            repository: nil,
            activeSessions: [],
            dirtyFiles: [],
            unattributedChanges: [],
            recentCheckpoints: [],
            validationRuns: [],
            conflicts: []
        ))
    }

    @Test
    func repositoryReadsCurrentContextValidationRunsAfterReopen() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let timestamp = Date(timeIntervalSince1970: 1_800_000_000)
        let repositoryRecord = ProvenanceRepositoryRecord(
            id: "repository-1",
            path: "/repos/project",
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let worktree = ProvenanceWorktreeRecord(
            id: "worktree-1",
            repositoryID: repositoryRecord.id,
            path: repositoryRecord.path,
            isDirty: true,
            status: "active",
            updatedAt: timestamp
        )
        let session = ProvenanceSessionRecord(
            id: "session-1",
            agentKind: "codex",
            worktreeID: worktree.id,
            status: "active",
            updatedAt: timestamp
        )
        let workItem = ProvenanceWorkItemRecord(
            id: "work-item-1",
            title: "Split provenance engine",
            status: "active",
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let contribution = ProvenanceContributionRecord(
            id: "contribution-1",
            sessionID: session.id,
            worktreeID: worktree.id,
            workItemID: workItem.id,
            status: "active",
            startedAt: timestamp,
            assignmentConfidence: .high,
            updatedAt: timestamp
        )
        let checkpoint = ProvenanceCheckpointRecord(
            id: "checkpoint-1",
            contributionID: contribution.id,
            sequence: 1,
            status: "in_progress",
            semanticConfidence: .high,
            freshness: "fresh",
            createdAt: timestamp
        )
        let command = "test"
        let validationRunID = "validation-run-1"
        let validationRun = ProvenanceValidationRunRecord(
            id: validationRunID,
            checkpointID: checkpoint.id,
            command: command,
            status: "passed"
        )
        let writer = try ProvenanceSQLiteRepository(url: url)
        try await writer.appendEvent(
            ProvenanceEvent(
                id: "event-bootstrap",
                eventType: .worktreeObserved,
                timestamp: timestamp,
                repositoryID: repositoryRecord.id,
                worktreeID: worktree.id,
                source: .observed,
                confidence: .high,
                payload: ProvenanceEventPayload(repository: repositoryRecord, worktree: worktree)
            )
        )
        try await writer.appendEvent(
            ProvenanceEvent(
                id: "event-validation-run",
                eventType: "validation_run_observed",
                timestamp: timestamp,
                worktreeID: worktree.id,
                contributionID: contribution.id,
                source: .observed,
                confidence: .high,
                payload: ProvenanceEventPayload(
                    session: session,
                    workItem: workItem,
                    contribution: contribution,
                    checkpoint: checkpoint,
                    validationRun: validationRun
                )
            )
        )
        let reader = try ProvenanceSQLiteRepository(url: url)
        let response = try await reader.currentContext(
            ProvenanceCurrentContextRequest(repositoryPath: worktree.path)
        )

        #expect(response.validationRuns == [
            ProvenanceCurrentContextValidationRun(
                validationRun: validationRun,
                checkpoint: checkpoint,
                contribution: contribution
            ),
        ])
    }

    @Test
    func repositoryRejectsDuplicateEventIDWithoutReplacingOriginal() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)
        let originalSession = ProvenanceSessionRecord(
            id: "session-1",
            agentKind: "codex",
            status: "active",
            startedAt: Date(timeIntervalSince1970: 1_800_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
        let duplicateSession = ProvenanceSessionRecord(
            id: originalSession.id,
            agentKind: originalSession.agentKind,
            status: "completed",
            startedAt: originalSession.startedAt,
            updatedAt: Date(timeIntervalSince1970: 1_800_000_010)
        )
        let duplicateFileChange = ProvenanceFileChangeRecord(
            id: "file-change-duplicate",
            changeSetID: "change-set-duplicate",
            repositoryID: "repository-1",
            worktreeID: "worktree-1",
            path: "duplicate.swift",
            status: "modified",
            attributionSource: .declared,
            attributionConfidence: .high,
            updatedAt: duplicateSession.updatedAt
        )
        let original = ProvenanceEvent(
            id: "event-1",
            eventType: .sessionObserved,
            timestamp: Date(timeIntervalSince1970: 1_800_000_000),
            sessionID: "session-1",
            source: .declared,
            confidence: .medium,
            payload: ProvenanceEventPayload(session: originalSession)
        )
        let duplicate = ProvenanceEvent(
            id: original.id,
            eventType: .worktreeObserved,
            timestamp: Date(timeIntervalSince1970: 1_800_000_010),
            worktreeID: "worktree-1",
            source: .observed,
            confidence: .high,
            payload: ProvenanceEventPayload(
                session: duplicateSession,
                fileChanges: [duplicateFileChange]
            )
        )

        try await repository.appendEvent(original)

        do {
            try await repository.appendEvent(duplicate)
            Issue.record("Expected duplicate event ID failure")
        } catch let error as ProvenanceSQLiteError {
            if case let .sqlite(message) = error {
                #expect(message.contains("UNIQUE") || message.contains("unique"))
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        #expect(try await repository.event(id: original.id) == original)
        #expect(try await repository.session(id: originalSession.id) == originalSession)
        #expect(try await repository.fileExplanation(
            ProvenanceFileExplanationRequest(
                worktreeID: duplicateFileChange.worktreeID,
                path: duplicateFileChange.path
            )
        ) == ProvenanceFileExplanationResponse(
            found: false,
            reason: "no_file",
            explanation: nil
        ))
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

    private static func checkpointEvent(
        id: String,
        checkpointID: String,
        timestamp: TimeInterval
    ) -> ProvenanceEvent {
        ProvenanceEvent(
            id: id,
            eventType: .progressCheckpoint,
            timestamp: Date(timeIntervalSince1970: timestamp),
            sessionID: "session-1",
            source: .declared,
            confidence: .high,
            payload: ProvenanceEventPayload(
                checkpoint: ProvenanceCheckpointRecord(
                    id: checkpointID,
                    contributionID: "contribution-1",
                    sequence: 1,
                    status: "in_progress",
                    semanticConfidence: .high,
                    freshness: "fresh",
                    createdAt: Date(timeIntervalSince1970: timestamp)
                )
            )
        )
    }

    private static func removeTemporaryDatabaseDirectory(for url: URL) {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }
}
