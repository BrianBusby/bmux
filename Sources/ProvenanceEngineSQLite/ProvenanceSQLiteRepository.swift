import Foundation
import ProvenanceEngineContracts

/// Internal repository actor that owns one migrated SQLite database connection.
actor ProvenanceSQLiteRepository {
    private let database: ProvenanceSQLiteDatabase
    private let payloadEncoder: JSONEncoder
    private let payloadDecoder: JSONDecoder

    /// Opens the database and applies the supplied migrations before returning.
    ///
    /// - Parameters:
    ///   - url: SQLite database file URL.
    ///   - migrations: Ordered migration steps supported by this repository.
    ///   - fileManager: Filesystem dependency used by the SQLite connection.
    /// - Throws: ``ProvenanceSQLiteError`` or filesystem errors when opening or migrating fails.
    init(
        url: URL,
        migrations: [ProvenanceSQLiteMigration] = ProvenanceSQLiteRepository.migrations,
        fileManager: FileManager = .default
    ) throws {
        let migrator = try ProvenanceSQLiteMigrator(migrations: migrations)
        let database = try ProvenanceSQLiteDatabase(url: url, fileManager: fileManager)
        try migrator.migrate(database)

        self.database = database
        self.payloadEncoder = JSONEncoder()
        self.payloadDecoder = JSONDecoder()
    }

    /// Current migrated schema version recorded in SQLite `PRAGMA user_version`.
    func schemaVersion() throws -> Int32 {
        try database.userVersion
    }

    /// Appends one immutable provenance event to the internal ledger.
    ///
    /// - Parameter event: Contract event to persist.
    /// - Throws: ``ProvenanceSQLiteError`` when SQLite rejects the write, including duplicate IDs.
    func appendEvent(_ event: ProvenanceEvent) throws {
        try database.execute("BEGIN IMMEDIATE TRANSACTION")
        do {
            try insertEvent(event)
            if let session = event.payload.session {
                try upsertSession(session)
            }
            try database.execute("COMMIT")
        } catch {
            try? database.execute("ROLLBACK")
            throw error
        }
    }

    /// Reads one event from the internal ledger by stable ID.
    ///
    /// - Parameter id: Stable event identifier.
    /// - Returns: The persisted event, or `nil` when the ID is unknown.
    /// - Throws: ``ProvenanceSQLiteError`` when SQLite rejects the read or stored enum data is invalid.
    func event(id: String) throws -> ProvenanceEvent? {
        let query = try database.prepare(
            """
            SELECT
                schema_version,
                event_type,
                timestamp_seconds,
                repository_id,
                worktree_id,
                session_id,
                contribution_id,
                source,
                confidence,
                payload_json
            FROM provenance_events
            WHERE id = ?
            """
        )
        defer { query.finalize() }

        try query.bind(id, at: 1)
        guard try query.step() else { return nil }

        let eventType = ProvenanceEventType(rawValue: query.string(at: 1) ?? "")
        guard let sourceRawValue = query.string(at: 7),
              let source = ProvenanceSource(rawValue: sourceRawValue) else {
            throw ProvenanceSQLiteError.sqlite(message: "stored event has invalid source")
        }
        guard let confidenceRawValue = query.string(at: 8),
              let confidence = ProvenanceConfidence(rawValue: confidenceRawValue) else {
            throw ProvenanceSQLiteError.sqlite(message: "stored event has invalid confidence")
        }
        guard let payloadJSON = query.string(at: 9),
              let payloadData = payloadJSON.data(using: .utf8) else {
            throw ProvenanceSQLiteError.sqlite(message: "stored event has invalid payload")
        }

        let payload = try payloadDecoder.decode(ProvenanceEventPayload.self, from: payloadData)
        return ProvenanceEvent(
            id: id,
            schemaVersion: query.int(at: 0),
            eventType: eventType,
            timestamp: Date(timeIntervalSince1970: query.double(at: 2) ?? 0),
            repositoryID: query.string(at: 3),
            worktreeID: query.string(at: 4),
            sessionID: query.string(at: 5),
            contributionID: query.string(at: 6),
            source: source,
            confidence: confidence,
            payload: payload
        )
    }

    /// Reads one current-state session projection by stable ID.
    ///
    /// - Parameter id: Stable session identifier.
    /// - Returns: The persisted session projection, or `nil` when the ID is unknown.
    /// - Throws: ``ProvenanceSQLiteError`` when SQLite rejects the read.
    func session(id: String) throws -> ProvenanceSessionRecord? {
        let query = try database.prepare(
            """
            SELECT
                agent_kind,
                workspace_id,
                surface_id,
                worktree_id,
                cwd,
                status,
                started_at_seconds,
                updated_at_seconds
            FROM provenance_sessions
            WHERE id = ?
            """
        )
        defer { query.finalize() }

        try query.bind(id, at: 1)
        guard try query.step() else { return nil }

        return ProvenanceSessionRecord(
            id: id,
            agentKind: query.string(at: 0) ?? "",
            workspaceID: query.string(at: 1),
            surfaceID: query.string(at: 2),
            worktreeID: query.string(at: 3),
            cwd: query.string(at: 4),
            status: query.string(at: 5) ?? "",
            startedAt: query.double(at: 6).map { Date(timeIntervalSince1970: $0) },
            updatedAt: Date(timeIntervalSince1970: query.double(at: 7) ?? 0)
        )
    }

    private func insertEvent(_ event: ProvenanceEvent) throws {
        let payloadData = try payloadEncoder.encode(event.payload)
        guard let payloadJSON = String(data: payloadData, encoding: .utf8) else {
            throw ProvenanceSQLiteError.sqlite(message: "failed to encode event payload")
        }

        let insert = try database.prepare(
            """
            INSERT INTO provenance_events (
                id,
                schema_version,
                event_type,
                timestamp_seconds,
                repository_id,
                worktree_id,
                session_id,
                contribution_id,
                source,
                confidence,
                payload_json
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """
        )
        defer { insert.finalize() }

        try insert.bind(event.id, at: 1)
        try insert.bind(event.schemaVersion, at: 2)
        try insert.bind(event.eventType.rawValue, at: 3)
        try insert.bind(event.timestamp.timeIntervalSince1970, at: 4)
        try insert.bind(event.repositoryID, at: 5)
        try insert.bind(event.worktreeID, at: 6)
        try insert.bind(event.sessionID, at: 7)
        try insert.bind(event.contributionID, at: 8)
        try insert.bind(event.source.rawValue, at: 9)
        try insert.bind(event.confidence.rawValue, at: 10)
        try insert.bind(payloadJSON, at: 11)

        _ = try insert.step()
    }

    private func upsertSession(_ session: ProvenanceSessionRecord) throws {
        let upsert = try database.prepare(
            """
            INSERT INTO provenance_sessions (
                id,
                agent_kind,
                workspace_id,
                surface_id,
                worktree_id,
                cwd,
                status,
                started_at_seconds,
                updated_at_seconds
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                agent_kind = excluded.agent_kind,
                workspace_id = excluded.workspace_id,
                surface_id = excluded.surface_id,
                worktree_id = excluded.worktree_id,
                cwd = excluded.cwd,
                status = excluded.status,
                started_at_seconds = excluded.started_at_seconds,
                updated_at_seconds = excluded.updated_at_seconds
            """
        )
        defer { upsert.finalize() }

        try upsert.bind(session.id, at: 1)
        try upsert.bind(session.agentKind, at: 2)
        try upsert.bind(session.workspaceID, at: 3)
        try upsert.bind(session.surfaceID, at: 4)
        try upsert.bind(session.worktreeID, at: 5)
        try upsert.bind(session.cwd, at: 6)
        try upsert.bind(session.status, at: 7)
        try upsert.bind(session.startedAt?.timeIntervalSince1970, at: 8)
        try upsert.bind(session.updatedAt.timeIntervalSince1970, at: 9)

        _ = try upsert.step()
    }

    private static let migrations = [
        ProvenanceSQLiteMigration(
            version: 1,
            statements: [
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
                )
                """,
                """
                CREATE INDEX provenance_events_timestamp_index
                ON provenance_events (timestamp_seconds, sequence)
                """,
                """
                CREATE INDEX provenance_events_session_index
                ON provenance_events (session_id, sequence)
                """,
                """
                CREATE INDEX provenance_events_worktree_index
                ON provenance_events (worktree_id, sequence)
                """,
            ]
        ),
        ProvenanceSQLiteMigration(
            version: 2,
            statements: [
                """
                CREATE TABLE provenance_sessions (
                    id TEXT PRIMARY KEY NOT NULL,
                    agent_kind TEXT NOT NULL,
                    workspace_id TEXT,
                    surface_id TEXT,
                    worktree_id TEXT,
                    cwd TEXT,
                    status TEXT NOT NULL,
                    started_at_seconds REAL,
                    updated_at_seconds REAL NOT NULL
                )
                """,
                """
                CREATE INDEX provenance_sessions_worktree_index
                ON provenance_sessions (worktree_id, updated_at_seconds)
                """,
                """
                CREATE INDEX provenance_sessions_status_index
                ON provenance_sessions (status, updated_at_seconds)
                """,
            ]
        ),
    ]
}
