import Foundation

/// Actor-owned durable store for work provenance events and projections.
actor WorkProvenanceStore {
    private static let schemaVersion = 3
    private let database: WorkProvenanceSQLiteDatabase
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let retentionPolicy: WorkProvenanceRetentionPolicy
    private var appendCountSincePrune = 0

    /// Creates a provenance store backed by the SQLite file at `databaseURL`.
    ///
    /// - Parameters:
    ///   - databaseURL: SQLite database file to create or open.
    ///   - fileManager: Filesystem dependency used to create the parent directory.
    ///   - retentionPolicy: Policy used for automatic pruning of high-volume observations.
    /// - Throws: ``WorkProvenanceStoreError`` or filesystem errors.
    init(
        databaseURL: URL,
        fileManager: FileManager = .default,
        retentionPolicy: WorkProvenanceRetentionPolicy = .standard
    ) throws {
        try fileManager.createDirectory(
            at: databaseURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        self.database = try WorkProvenanceSQLiteDatabase(url: databaseURL)
        self.retentionPolicy = retentionPolicy
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        self.encoder = encoder
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        self.decoder = decoder
        try Self.migrateIfNeeded(database: database)
    }

    /// Appends an immutable event and updates current-state projections.
    ///
    /// - Parameter event: Event to append.
    /// - Throws: ``WorkProvenanceStoreError`` when persistence fails.
    func append(_ event: WorkProvenanceEvent) throws {
        try database.execute("BEGIN IMMEDIATE TRANSACTION")
        do {
            try insertEvent(event)
            try apply(payload: event.payload)
            appendCountSincePrune += 1
            if appendCountSincePrune >= retentionPolicy.pruneAfterAppendedEvents {
                _ = try pruneExpiredObservedHistoryLocked(now: event.timestamp)
                appendCountSincePrune = 0
            }
            try database.execute("COMMIT")
        } catch {
            try? database.execute("ROLLBACK")
            throw error
        }
    }

    /// Returns events in append order.
    ///
    /// - Throws: ``WorkProvenanceStoreError`` when persistence fails.
    func events() throws -> [WorkProvenanceEvent] {
        let statement = try database.prepare(
            """
            SELECT id, schema_version, event_type, timestamp, repository_id,
                   worktree_id, session_id, contribution_id, source,
                   confidence, payload_json
            FROM events
            ORDER BY rowid ASC
            """
        )
        defer { statement.finalize() }
        var result: [WorkProvenanceEvent] = []
        while try statement.step() {
            guard let event = try event(from: statement) else { continue }
            result.append(event)
        }
        return result
    }

    /// Rebuilds current-state projections by replaying the immutable event table.
    ///
    /// - Throws: ``WorkProvenanceStoreError`` when persistence fails.
    func rebuildProjections() throws {
        let storedEvents = try events()
        try database.execute("BEGIN IMMEDIATE TRANSACTION")
        do {
            try clearProjectionTables()
            for event in storedEvents {
                try apply(payload: event.payload)
            }
            try database.execute("COMMIT")
        } catch {
            try? database.execute("ROLLBACK")
            throw error
        }
    }

    /// Prunes stale high-volume observed history while preserving semantic provenance.
    ///
    /// - Parameter now: Reference time for maximum-age calculations.
    /// - Returns: Number of rows deleted by category.
    /// - Throws: ``WorkProvenanceStoreError`` when persistence fails.
    func pruneExpiredObservedHistory(now: Date = Date()) throws -> WorkProvenancePruneResult {
        try database.execute("BEGIN IMMEDIATE TRANSACTION")
        do {
            let result = try pruneExpiredObservedHistoryLocked(now: now)
            appendCountSincePrune = 0
            try database.execute("COMMIT")
            return result
        } catch {
            try? database.execute("ROLLBACK")
            throw error
        }
    }

    /// Returns the repository projection for `id`.
    ///
    /// - Parameter id: Repository identifier.
    /// - Returns: Repository record or `nil`.
    func repository(id: String) throws -> WorkProvenanceRepositoryRecord? {
        try repositoryRecord(id: id)
    }

    /// Returns the worktree projection for `id`.
    ///
    /// - Parameter id: Worktree identifier.
    /// - Returns: Worktree record or `nil`.
    func worktree(id: String) throws -> WorkProvenanceWorktreeRecord? {
        try worktreeRecord(id: id)
    }

    /// Returns the direct parent relationship for `sessionID`.
    ///
    /// - Parameter sessionID: Child session identifier.
    /// - Returns: Relationship record or `nil`.
    func parentSession(for sessionID: String) throws -> WorkProvenanceSessionRelationshipRecord? {
        try sessionRelationshipRecord(sessionID: sessionID)
    }

    /// Returns direct child relationships for `sessionID`.
    ///
    /// - Parameter sessionID: Parent session identifier.
    /// - Returns: Child relationships sorted by depth, update time, then session id.
    func childSessions(for sessionID: String) throws -> [WorkProvenanceSessionRelationshipRecord] {
        try childSessionRelationshipRecords(parentSessionID: sessionID)
    }

    /// Returns external identities linked to `sessionID`.
    ///
    /// - Parameter sessionID: Provenance session identifier.
    /// - Returns: Identity links sorted by system, kind, then external id.
    func externalIdentities(sessionID: String) throws -> [WorkProvenanceExternalIdentityRecord] {
        try externalIdentityRecords(sessionID: sessionID)
    }

    /// Returns the current session tree rooted at `rootSessionID`.
    ///
    /// - Parameter rootSessionID: Root session identifier.
    /// - Returns: Session tree containing the root when it exists.
    func sessionTree(rootSessionID: String) throws -> WorkProvenanceSessionTree {
        var sessions: [WorkProvenanceSessionRecord] = []
        if let rootSession = try sessionRecord(id: rootSessionID) {
            sessions.append(rootSession)
        }
        let relationships = try sessionRelationshipTreeRecords(rootSessionID: rootSessionID)
        for relationship in relationships {
            if let session = try sessionRecord(id: relationship.sessionID) {
                sessions.append(session)
            }
        }
        return WorkProvenanceSessionTree(
            rootSessionID: rootSessionID,
            sessions: sessions,
            relationships: relationships
        )
    }

    /// Returns focused provenance context for one repository-relative file path.
    ///
    /// - Parameters:
    ///   - worktreeID: Worktree identifier.
    ///   - path: Repository-relative file path.
    /// - Returns: File explanation or `nil` when no file-change projection exists.
    func fileExplanation(
        worktreeID: String,
        path: String
    ) throws -> WorkProvenanceFileExplanation? {
        guard let fileChange = try fileChangeRecord(worktreeID: worktreeID, path: path) else {
            return nil
        }
        let changeSet = try changeSetRecord(id: fileChange.changeSetID)
        let checkpoint: WorkProvenanceCheckpointRecord?
        if let checkpointID = changeSet?.checkpointID {
            checkpoint = try checkpointRecord(id: checkpointID)
        } else {
            checkpoint = nil
        }
        let contributionID = changeSet?.contributionID ?? checkpoint?.contributionID
        let contribution: WorkProvenanceContributionRecord?
        if let contributionID {
            contribution = try contributionRecord(id: contributionID)
        } else {
            contribution = nil
        }
        let session: WorkProvenanceSessionRecord?
        if let contribution {
            session = try sessionRecord(id: contribution.sessionID)
        } else {
            session = nil
        }
        let workItem: WorkProvenanceWorkItemRecord?
        if let contribution {
            workItem = try workItemRecord(id: contribution.workItemID)
        } else {
            workItem = nil
        }
        let worktree = try worktreeRecord(id: fileChange.worktreeID)
        let repositoryID = worktree?.repositoryID ?? fileChange.repositoryID
        let repository = try repositoryRecord(id: repositoryID)
        return WorkProvenanceFileExplanation(
            fileChange: fileChange,
            changeSet: changeSet,
            checkpoint: checkpoint,
            contribution: contribution,
            session: session,
            workItem: workItem,
            worktree: worktree,
            repository: repository
        )
    }

    private static func migrateIfNeeded(database: WorkProvenanceSQLiteDatabase) throws {
        let version = Int(try database.userVersion)
        guard version <= schemaVersion else {
            throw WorkProvenanceStoreError.unsupportedSchema(
                found: Int32(version),
                supported: Int32(schemaVersion)
            )
        }
        if version == 0 {
            try database.execute(schemaSQL)
            try database.execute("PRAGMA user_version = 3")
            return
        }
        if version < 2 {
            try database.execute(schemaV2SQL)
            try database.execute("PRAGMA user_version = 2")
        }
        if version < 3 {
            try database.execute(schemaV3SQL)
            try database.execute("PRAGMA user_version = 3")
        }
    }

    private func insertEvent(_ event: WorkProvenanceEvent) throws {
        let statement = try database.prepare(
            """
            INSERT INTO events (
                id, schema_version, event_type, timestamp, repository_id,
                worktree_id, session_id, contribution_id, source, confidence,
                payload_json
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """
        )
        defer { statement.finalize() }
        try statement.bind(event.id, at: 1)
        try statement.bind(event.schemaVersion, at: 2)
        try statement.bind(event.eventType.rawValue, at: 3)
        try statement.bind(event.timestamp.timeIntervalSince1970, at: 4)
        try statement.bind(event.repositoryID, at: 5)
        try statement.bind(event.worktreeID, at: 6)
        try statement.bind(event.sessionID, at: 7)
        try statement.bind(event.contributionID, at: 8)
        try statement.bind(event.source.rawValue, at: 9)
        try statement.bind(event.confidence.rawValue, at: 10)
        try statement.bind(encoded(event.payload), at: 11)
        _ = try statement.step()
    }

    private func event(from statement: WorkProvenanceSQLiteStatement) throws -> WorkProvenanceEvent? {
        guard let id = statement.string(at: 0),
              let eventType = statement.string(at: 2),
              let source = statement.string(at: 8).flatMap(WorkProvenanceSource.init(rawValue:)),
              let confidence = statement.string(at: 9).flatMap(WorkProvenanceConfidence.init(rawValue:)),
              let payloadJSON = statement.string(at: 10),
              let payloadData = payloadJSON.data(using: .utf8) else {
            return nil
        }
        let payload: WorkProvenanceEventPayload
        do {
            payload = try decoder.decode(WorkProvenanceEventPayload.self, from: payloadData)
        } catch {
            throw WorkProvenanceStoreError.invalidPayload(eventID: id)
        }
        return WorkProvenanceEvent(
            id: id,
            schemaVersion: statement.int(at: 1),
            eventType: WorkProvenanceEventType(rawValue: eventType),
            timestamp: Date(timeIntervalSince1970: statement.double(at: 3) ?? 0),
            repositoryID: statement.string(at: 4),
            worktreeID: statement.string(at: 5),
            sessionID: statement.string(at: 6),
            contributionID: statement.string(at: 7),
            source: source,
            confidence: confidence,
            payload: payload
        )
    }

    private func clearProjectionTables() throws {
        try database.execute(
            """
            DELETE FROM validation_runs;
            DELETE FROM file_changes;
            DELETE FROM change_sets;
            DELETE FROM checkpoints;
            DELETE FROM work_contributions;
            DELETE FROM work_items;
            DELETE FROM session_external_identities;
            DELETE FROM session_relationships;
            DELETE FROM sessions;
            DELETE FROM worktrees;
            DELETE FROM repositories;
            """
        )
    }

    private func pruneExpiredObservedHistoryLocked(now: Date) throws -> WorkProvenancePruneResult {
        let cutoff = now.timeIntervalSince1970 - retentionPolicy.observedEventMaximumAge
        let eventsDeleted = try deleteExpiredObservedEvents(cutoff: cutoff)
        let fileChangesDeleted = try deleteExpiredObservedFileChanges(cutoff: cutoff)
        let changeSetsDeleted = try deleteUnreferencedObservedChangeSets(cutoff: cutoff)
        return WorkProvenancePruneResult(
            eventsDeleted: eventsDeleted,
            fileChangesDeleted: fileChangesDeleted,
            changeSetsDeleted: changeSetsDeleted
        )
    }

    private func deleteExpiredObservedEvents(cutoff: TimeInterval) throws -> Int {
        var deleted = 0
        for worktreeID in try observedEventWorktreeIDs() {
            let statement = try database.prepare(
                """
                DELETE FROM events
                WHERE event_type = ?
                  AND worktree_id = ?
                  AND timestamp < ?
                  AND rowid NOT IN (
                      SELECT rowid FROM (
                          SELECT rowid
                          FROM events
                          WHERE event_type = ?
                            AND worktree_id = ?
                          ORDER BY timestamp DESC, rowid DESC
                          LIMIT ?
                      )
                  )
                """
            )
            defer { statement.finalize() }
            try statement.bind(WorkProvenanceEventType.worktreeObserved.rawValue, at: 1)
            try statement.bind(worktreeID, at: 2)
            try statement.bind(cutoff, at: 3)
            try statement.bind(WorkProvenanceEventType.worktreeObserved.rawValue, at: 4)
            try statement.bind(worktreeID, at: 5)
            try statement.bind(retentionPolicy.minimumObservedEventsPerWorktree, at: 6)
            _ = try statement.step()
            deleted += database.changes
        }

        let nilWorktreeStatement = try database.prepare(
            """
            DELETE FROM events
            WHERE event_type = ?
              AND worktree_id IS NULL
              AND timestamp < ?
            """
        )
        defer { nilWorktreeStatement.finalize() }
        try nilWorktreeStatement.bind(WorkProvenanceEventType.worktreeObserved.rawValue, at: 1)
        try nilWorktreeStatement.bind(cutoff, at: 2)
        _ = try nilWorktreeStatement.step()
        deleted += database.changes
        return deleted
    }

    private func observedEventWorktreeIDs() throws -> [String] {
        let statement = try database.prepare(
            """
            SELECT DISTINCT worktree_id
            FROM events
            WHERE event_type = ?
              AND worktree_id IS NOT NULL
            """
        )
        defer { statement.finalize() }
        try statement.bind(WorkProvenanceEventType.worktreeObserved.rawValue, at: 1)
        var worktreeIDs: [String] = []
        while try statement.step() {
            if let worktreeID = statement.string(at: 0) {
                worktreeIDs.append(worktreeID)
            }
        }
        return worktreeIDs
    }

    private func deleteExpiredObservedFileChanges(cutoff: TimeInterval) throws -> Int {
        let statement = try database.prepare(
            """
            DELETE FROM file_changes
            WHERE attribution_source = ?
              AND updated_at < ?
              AND rowid NOT IN (
                  SELECT newest.rowid
                  FROM file_changes AS newest
                  WHERE newest.worktree_id = file_changes.worktree_id
                    AND newest.path = file_changes.path
                  ORDER BY newest.updated_at DESC, newest.rowid DESC
                  LIMIT 1
              )
            """
        )
        defer { statement.finalize() }
        try statement.bind(WorkProvenanceSource.unattributed.rawValue, at: 1)
        try statement.bind(cutoff, at: 2)
        _ = try statement.step()
        return database.changes
    }

    private func deleteUnreferencedObservedChangeSets(cutoff: TimeInterval) throws -> Int {
        let statement = try database.prepare(
            """
            DELETE FROM change_sets
            WHERE checkpoint_id IS NULL
              AND contribution_id IS NULL
              AND created_at < ?
              AND NOT EXISTS (
                  SELECT 1
                  FROM file_changes
                  WHERE file_changes.change_set_id = change_sets.id
                  LIMIT 1
              )
            """
        )
        defer { statement.finalize() }
        try statement.bind(cutoff, at: 1)
        _ = try statement.step()
        return database.changes
    }

    private func repositoryRecord(id: String) throws -> WorkProvenanceRepositoryRecord? {
        let statement = try database.prepare(
            "SELECT id, path, common_directory, remote_slug, created_at, updated_at FROM repositories WHERE id = ?"
        )
        defer { statement.finalize() }
        try statement.bind(id, at: 1)
        guard try statement.step(),
              let id = statement.string(at: 0),
              let path = statement.string(at: 1) else {
            return nil
        }
        return WorkProvenanceRepositoryRecord(
            id: id,
            path: path,
            commonDirectory: statement.string(at: 2),
            remoteSlug: statement.string(at: 3),
            createdAt: Date(timeIntervalSince1970: statement.double(at: 4) ?? 0),
            updatedAt: Date(timeIntervalSince1970: statement.double(at: 5) ?? 0)
        )
    }

    private func worktreeRecord(id: String) throws -> WorkProvenanceWorktreeRecord? {
        let statement = try database.prepare(
            """
            SELECT id, repository_id, path, branch, base_commit, current_head,
                   is_dirty, status, last_reconciled_at, updated_at
            FROM worktrees WHERE id = ?
            """
        )
        defer { statement.finalize() }
        try statement.bind(id, at: 1)
        guard try statement.step(),
              let id = statement.string(at: 0),
              let repositoryID = statement.string(at: 1),
              let path = statement.string(at: 2),
              let status = statement.string(at: 7) else {
            return nil
        }
        return WorkProvenanceWorktreeRecord(
            id: id,
            repositoryID: repositoryID,
            path: path,
            branch: statement.string(at: 3),
            baseCommit: statement.string(at: 4),
            currentHEAD: statement.string(at: 5),
            isDirty: statement.int(at: 6) != 0,
            status: status,
            lastReconciledAt: statement.double(at: 8).map(Date.init(timeIntervalSince1970:)),
            updatedAt: Date(timeIntervalSince1970: statement.double(at: 9) ?? 0)
        )
    }

    private func sessionRecord(id: String) throws -> WorkProvenanceSessionRecord? {
        let statement = try database.prepare(
            """
            SELECT id, agent_kind, workspace_id, surface_id, worktree_id,
                   cwd, status, started_at, updated_at
            FROM sessions WHERE id = ?
            """
        )
        defer { statement.finalize() }
        try statement.bind(id, at: 1)
        guard try statement.step(),
              let id = statement.string(at: 0),
              let agentKind = statement.string(at: 1),
              let status = statement.string(at: 6) else {
            return nil
        }
        return WorkProvenanceSessionRecord(
            id: id,
            agentKind: agentKind,
            workspaceID: statement.string(at: 2),
            surfaceID: statement.string(at: 3),
            worktreeID: statement.string(at: 4),
            cwd: statement.string(at: 5),
            status: status,
            startedAt: statement.double(at: 7).map(Date.init(timeIntervalSince1970:)),
            updatedAt: Date(timeIntervalSince1970: statement.double(at: 8) ?? 0)
        )
    }

    private func sessionRelationshipRecord(
        sessionID: String
    ) throws -> WorkProvenanceSessionRelationshipRecord? {
        let statement = try database.prepare(
            """
            SELECT session_id, parent_session_id, root_session_id,
                   inbound_delegation_id, depth, source, confidence,
                   created_at, updated_at
            FROM session_relationships
            WHERE session_id = ?
            """
        )
        defer { statement.finalize() }
        try statement.bind(sessionID, at: 1)
        guard try statement.step() else { return nil }
        return sessionRelationshipRecord(from: statement)
    }

    private func childSessionRelationshipRecords(
        parentSessionID: String
    ) throws -> [WorkProvenanceSessionRelationshipRecord] {
        let statement = try database.prepare(
            """
            SELECT session_id, parent_session_id, root_session_id,
                   inbound_delegation_id, depth, source, confidence,
                   created_at, updated_at
            FROM session_relationships
            WHERE parent_session_id = ?
            ORDER BY depth ASC, updated_at ASC, session_id ASC
            """
        )
        defer { statement.finalize() }
        try statement.bind(parentSessionID, at: 1)
        var records: [WorkProvenanceSessionRelationshipRecord] = []
        while try statement.step() {
            if let record = sessionRelationshipRecord(from: statement) {
                records.append(record)
            }
        }
        return records
    }

    private func sessionRelationshipTreeRecords(
        rootSessionID: String
    ) throws -> [WorkProvenanceSessionRelationshipRecord] {
        let statement = try database.prepare(
            """
            SELECT session_id, parent_session_id, root_session_id,
                   inbound_delegation_id, depth, source, confidence,
                   created_at, updated_at
            FROM session_relationships
            WHERE root_session_id = ?
            ORDER BY depth ASC, updated_at ASC, session_id ASC
            """
        )
        defer { statement.finalize() }
        try statement.bind(rootSessionID, at: 1)
        var records: [WorkProvenanceSessionRelationshipRecord] = []
        while try statement.step() {
            if let record = sessionRelationshipRecord(from: statement) {
                records.append(record)
            }
        }
        return records
    }

    private func sessionRelationshipRecord(
        from statement: WorkProvenanceSQLiteStatement
    ) -> WorkProvenanceSessionRelationshipRecord? {
        guard let sessionID = statement.string(at: 0),
              let parentSessionID = statement.string(at: 1),
              let rootSessionID = statement.string(at: 2),
              let source = statement.string(at: 5).flatMap(WorkProvenanceSource.init(rawValue:)),
              let confidence = statement.string(at: 6).flatMap(WorkProvenanceConfidence.init(rawValue:)) else {
            return nil
        }
        return WorkProvenanceSessionRelationshipRecord(
            sessionID: sessionID,
            parentSessionID: parentSessionID,
            rootSessionID: rootSessionID,
            inboundDelegationID: statement.string(at: 3),
            depth: statement.int(at: 4),
            source: source,
            confidence: confidence,
            createdAt: Date(timeIntervalSince1970: statement.double(at: 7) ?? 0),
            updatedAt: Date(timeIntervalSince1970: statement.double(at: 8) ?? 0)
        )
    }

    private func externalIdentityRecords(
        sessionID: String
    ) throws -> [WorkProvenanceExternalIdentityRecord] {
        let statement = try database.prepare(
            """
            SELECT id, session_id, system, kind, external_id, source,
                   confidence, created_at, updated_at
            FROM session_external_identities
            WHERE session_id = ?
            ORDER BY system ASC, kind ASC, external_id ASC
            """
        )
        defer { statement.finalize() }
        try statement.bind(sessionID, at: 1)
        var records: [WorkProvenanceExternalIdentityRecord] = []
        while try statement.step() {
            guard let id = statement.string(at: 0),
                  let sessionID = statement.string(at: 1),
                  let system = statement.string(at: 2),
                  let kind = statement.string(at: 3),
                  let externalID = statement.string(at: 4),
                  let source = statement.string(at: 5).flatMap(WorkProvenanceSource.init(rawValue:)),
                  let confidence = statement.string(at: 6).flatMap(WorkProvenanceConfidence.init(rawValue:)) else {
                continue
            }
            records.append(WorkProvenanceExternalIdentityRecord(
                id: id,
                sessionID: sessionID,
                system: system,
                kind: kind,
                externalID: externalID,
                source: source,
                confidence: confidence,
                createdAt: Date(timeIntervalSince1970: statement.double(at: 7) ?? 0),
                updatedAt: Date(timeIntervalSince1970: statement.double(at: 8) ?? 0)
            ))
        }
        return records
    }

    private func workItemRecord(id: String) throws -> WorkProvenanceWorkItemRecord? {
        let statement = try database.prepare(
            "SELECT id, title, status, created_at, updated_at FROM work_items WHERE id = ?"
        )
        defer { statement.finalize() }
        try statement.bind(id, at: 1)
        guard try statement.step(),
              let id = statement.string(at: 0),
              let title = statement.string(at: 1),
              let status = statement.string(at: 2) else {
            return nil
        }
        return WorkProvenanceWorkItemRecord(
            id: id,
            title: title,
            status: status,
            createdAt: Date(timeIntervalSince1970: statement.double(at: 3) ?? 0),
            updatedAt: Date(timeIntervalSince1970: statement.double(at: 4) ?? 0)
        )
    }

    private func contributionRecord(id: String) throws -> WorkProvenanceContributionRecord? {
        let statement = try database.prepare(
            """
            SELECT id, session_id, worktree_id, work_item_id, declared_intent,
                   expected_scope_json, status, started_at, ended_at,
                   assignment_confidence, updated_at
            FROM work_contributions WHERE id = ?
            """
        )
        defer { statement.finalize() }
        try statement.bind(id, at: 1)
        guard try statement.step(),
              let id = statement.string(at: 0),
              let sessionID = statement.string(at: 1),
              let worktreeID = statement.string(at: 2),
              let workItemID = statement.string(at: 3),
              let expectedScopeJSON = statement.string(at: 5),
              let expectedScopeData = expectedScopeJSON.data(using: .utf8),
              let status = statement.string(at: 6),
              let confidence = statement.string(at: 9).flatMap(WorkProvenanceConfidence.init(rawValue:)) else {
            return nil
        }
        let expectedScope = (try? decoder.decode([String].self, from: expectedScopeData)) ?? []
        return WorkProvenanceContributionRecord(
            id: id,
            sessionID: sessionID,
            worktreeID: worktreeID,
            workItemID: workItemID,
            declaredIntent: statement.string(at: 4),
            expectedScope: expectedScope,
            status: status,
            startedAt: Date(timeIntervalSince1970: statement.double(at: 7) ?? 0),
            endedAt: statement.double(at: 8).map(Date.init(timeIntervalSince1970:)),
            assignmentConfidence: confidence,
            updatedAt: Date(timeIntervalSince1970: statement.double(at: 10) ?? 0)
        )
    }

    private func checkpointRecord(id: String) throws -> WorkProvenanceCheckpointRecord? {
        let statement = try database.prepare(
            """
            SELECT id, contribution_id, sequence, git_head, diff_fingerprint,
                   summary, status, validation_state, semantic_confidence,
                   freshness, created_at
            FROM checkpoints WHERE id = ?
            """
        )
        defer { statement.finalize() }
        try statement.bind(id, at: 1)
        guard try statement.step(),
              let id = statement.string(at: 0),
              let contributionID = statement.string(at: 1),
              let status = statement.string(at: 6),
              let confidence = statement.string(at: 8).flatMap(WorkProvenanceConfidence.init(rawValue:)),
              let freshness = statement.string(at: 9) else {
            return nil
        }
        return WorkProvenanceCheckpointRecord(
            id: id,
            contributionID: contributionID,
            sequence: statement.int(at: 2),
            gitHEAD: statement.string(at: 3),
            diffFingerprint: statement.string(at: 4),
            summary: statement.string(at: 5),
            status: status,
            validationState: statement.string(at: 7),
            semanticConfidence: confidence,
            freshness: freshness,
            createdAt: Date(timeIntervalSince1970: statement.double(at: 10) ?? 0)
        )
    }

    private func changeSetRecord(id: String) throws -> WorkProvenanceChangeSetRecord? {
        let statement = try database.prepare(
            """
            SELECT id, checkpoint_id, contribution_id, worktree_id,
                   summary, diff_fingerprint, created_at
            FROM change_sets WHERE id = ?
            """
        )
        defer { statement.finalize() }
        try statement.bind(id, at: 1)
        guard try statement.step(),
              let id = statement.string(at: 0),
              let worktreeID = statement.string(at: 3) else {
            return nil
        }
        return WorkProvenanceChangeSetRecord(
            id: id,
            checkpointID: statement.string(at: 1),
            contributionID: statement.string(at: 2),
            worktreeID: worktreeID,
            summary: statement.string(at: 4),
            diffFingerprint: statement.string(at: 5),
            createdAt: Date(timeIntervalSince1970: statement.double(at: 6) ?? 0)
        )
    }

    private func fileChangeRecord(worktreeID: String, path: String) throws -> WorkProvenanceFileChangeRecord? {
        let statement = try database.prepare(
            """
            SELECT id, change_set_id, repository_id, worktree_id, path, status,
                   before_hash, after_hash, attribution_source,
                   attribution_confidence, updated_at
            FROM file_changes
            WHERE worktree_id = ? AND path = ?
            ORDER BY updated_at DESC, rowid DESC
            LIMIT 1
            """
        )
        defer { statement.finalize() }
        try statement.bind(worktreeID, at: 1)
        try statement.bind(path, at: 2)
        guard try statement.step() else { return nil }
        return fileChangeRecord(from: statement)
    }

    private func fileChangeRecord(from statement: WorkProvenanceSQLiteStatement) -> WorkProvenanceFileChangeRecord? {
        guard let id = statement.string(at: 0),
              let changeSetID = statement.string(at: 1),
              let repositoryID = statement.string(at: 2),
              let worktreeID = statement.string(at: 3),
              let path = statement.string(at: 4),
              let status = statement.string(at: 5),
              let source = statement.string(at: 8).flatMap(WorkProvenanceSource.init(rawValue:)),
              let confidence = statement.string(at: 9).flatMap(WorkProvenanceConfidence.init(rawValue:)) else {
            return nil
        }
        return WorkProvenanceFileChangeRecord(
            id: id,
            changeSetID: changeSetID,
            repositoryID: repositoryID,
            worktreeID: worktreeID,
            path: path,
            status: status,
            beforeHash: statement.string(at: 6),
            afterHash: statement.string(at: 7),
            attributionSource: source,
            attributionConfidence: confidence,
            updatedAt: Date(timeIntervalSince1970: statement.double(at: 10) ?? 0)
        )
    }

    private func encoded<Value: Encodable>(_ value: Value) throws -> String {
        let data = try encoder.encode(value)
        guard let text = String(data: data, encoding: .utf8) else {
            throw WorkProvenanceStoreError.sqlite(message: "failed to encode JSON payload")
        }
        return text
    }

    private func apply(payload: WorkProvenanceEventPayload) throws {
        if let repository = payload.repository {
            try upsert(repository)
        }
        if let worktree = payload.worktree {
            try upsert(worktree)
        }
        if let session = payload.session {
            try upsert(session)
        }
        if let sessionRelationship = payload.sessionRelationship {
            try upsert(sessionRelationship)
        }
        for externalIdentity in payload.externalIdentities {
            try upsert(externalIdentity)
        }
        if let workItem = payload.workItem {
            try upsert(workItem)
        }
        if let contribution = payload.contribution {
            try upsert(contribution)
        }
        if let checkpoint = payload.checkpoint {
            try upsert(checkpoint)
        }
        if let changeSet = payload.changeSet {
            try upsert(changeSet)
        }
        for fileChange in payload.fileChanges {
            try upsert(fileChange)
        }
        if let validationRun = payload.validationRun {
            try upsert(validationRun)
        }
    }

    private func upsert(_ record: WorkProvenanceRepositoryRecord) throws {
        let statement = try database.prepare(
            """
            INSERT INTO repositories (id, path, common_directory, remote_slug, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                path = excluded.path,
                common_directory = excluded.common_directory,
                remote_slug = excluded.remote_slug,
                updated_at = excluded.updated_at
            """
        )
        defer { statement.finalize() }
        try statement.bind(record.id, at: 1)
        try statement.bind(record.path, at: 2)
        try statement.bind(record.commonDirectory, at: 3)
        try statement.bind(record.remoteSlug, at: 4)
        try statement.bind(record.createdAt.timeIntervalSince1970, at: 5)
        try statement.bind(record.updatedAt.timeIntervalSince1970, at: 6)
        _ = try statement.step()
    }

    private func upsert(_ record: WorkProvenanceWorktreeRecord) throws {
        let statement = try database.prepare(
            """
            INSERT INTO worktrees (
                id, repository_id, path, branch, base_commit, current_head,
                is_dirty, status, last_reconciled_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                repository_id = excluded.repository_id,
                path = excluded.path,
                branch = excluded.branch,
                base_commit = excluded.base_commit,
                current_head = excluded.current_head,
                is_dirty = excluded.is_dirty,
                status = excluded.status,
                last_reconciled_at = excluded.last_reconciled_at,
                updated_at = excluded.updated_at
            """
        )
        defer { statement.finalize() }
        try statement.bind(record.id, at: 1)
        try statement.bind(record.repositoryID, at: 2)
        try statement.bind(record.path, at: 3)
        try statement.bind(record.branch, at: 4)
        try statement.bind(record.baseCommit, at: 5)
        try statement.bind(record.currentHEAD, at: 6)
        try statement.bind(record.isDirty ? 1 : 0, at: 7)
        try statement.bind(record.status, at: 8)
        try statement.bind(record.lastReconciledAt?.timeIntervalSince1970, at: 9)
        try statement.bind(record.updatedAt.timeIntervalSince1970, at: 10)
        _ = try statement.step()
    }

    private func upsert(_ record: WorkProvenanceSessionRecord) throws {
        let statement = try database.prepare(
            """
            INSERT INTO sessions (
                id, agent_kind, workspace_id, surface_id, worktree_id,
                cwd, status, started_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                agent_kind = excluded.agent_kind,
                workspace_id = excluded.workspace_id,
                surface_id = excluded.surface_id,
                worktree_id = excluded.worktree_id,
                cwd = excluded.cwd,
                status = excluded.status,
                updated_at = excluded.updated_at
            """
        )
        defer { statement.finalize() }
        try statement.bind(record.id, at: 1)
        try statement.bind(record.agentKind, at: 2)
        try statement.bind(record.workspaceID, at: 3)
        try statement.bind(record.surfaceID, at: 4)
        try statement.bind(record.worktreeID, at: 5)
        try statement.bind(record.cwd, at: 6)
        try statement.bind(record.status, at: 7)
        try statement.bind(record.startedAt?.timeIntervalSince1970, at: 8)
        try statement.bind(record.updatedAt.timeIntervalSince1970, at: 9)
        _ = try statement.step()
    }

    private func upsert(_ record: WorkProvenanceSessionRelationshipRecord) throws {
        let statement = try database.prepare(
            """
            INSERT INTO session_relationships (
                session_id, parent_session_id, root_session_id,
                inbound_delegation_id, depth, source, confidence,
                created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(session_id) DO UPDATE SET
                parent_session_id = excluded.parent_session_id,
                root_session_id = excluded.root_session_id,
                inbound_delegation_id = excluded.inbound_delegation_id,
                depth = excluded.depth,
                source = excluded.source,
                confidence = excluded.confidence,
                updated_at = excluded.updated_at
            """
        )
        defer { statement.finalize() }
        try statement.bind(record.sessionID, at: 1)
        try statement.bind(record.parentSessionID, at: 2)
        try statement.bind(record.rootSessionID, at: 3)
        try statement.bind(record.inboundDelegationID, at: 4)
        try statement.bind(record.depth, at: 5)
        try statement.bind(record.source.rawValue, at: 6)
        try statement.bind(record.confidence.rawValue, at: 7)
        try statement.bind(record.createdAt.timeIntervalSince1970, at: 8)
        try statement.bind(record.updatedAt.timeIntervalSince1970, at: 9)
        _ = try statement.step()
    }

    private func upsert(_ record: WorkProvenanceExternalIdentityRecord) throws {
        let statement = try database.prepare(
            """
            INSERT INTO session_external_identities (
                id, session_id, system, kind, external_id, source,
                confidence, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(system, kind, external_id) DO UPDATE SET
                session_id = excluded.session_id,
                source = excluded.source,
                confidence = excluded.confidence,
                updated_at = excluded.updated_at
            """
        )
        defer { statement.finalize() }
        try statement.bind(record.id, at: 1)
        try statement.bind(record.sessionID, at: 2)
        try statement.bind(record.system, at: 3)
        try statement.bind(record.kind, at: 4)
        try statement.bind(record.externalID, at: 5)
        try statement.bind(record.source.rawValue, at: 6)
        try statement.bind(record.confidence.rawValue, at: 7)
        try statement.bind(record.createdAt.timeIntervalSince1970, at: 8)
        try statement.bind(record.updatedAt.timeIntervalSince1970, at: 9)
        _ = try statement.step()
    }

    private func upsert(_ record: WorkProvenanceWorkItemRecord) throws {
        let statement = try database.prepare(
            """
            INSERT INTO work_items (id, title, status, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                title = excluded.title,
                status = excluded.status,
                updated_at = excluded.updated_at
            """
        )
        defer { statement.finalize() }
        try statement.bind(record.id, at: 1)
        try statement.bind(record.title, at: 2)
        try statement.bind(record.status, at: 3)
        try statement.bind(record.createdAt.timeIntervalSince1970, at: 4)
        try statement.bind(record.updatedAt.timeIntervalSince1970, at: 5)
        _ = try statement.step()
    }

    private func upsert(_ record: WorkProvenanceContributionRecord) throws {
        let statement = try database.prepare(
            """
            INSERT INTO work_contributions (
                id, session_id, worktree_id, work_item_id, declared_intent,
                expected_scope_json, status, started_at, ended_at,
                assignment_confidence, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                session_id = excluded.session_id,
                worktree_id = excluded.worktree_id,
                work_item_id = excluded.work_item_id,
                declared_intent = excluded.declared_intent,
                expected_scope_json = excluded.expected_scope_json,
                status = excluded.status,
                ended_at = excluded.ended_at,
                assignment_confidence = excluded.assignment_confidence,
                updated_at = excluded.updated_at
            """
        )
        defer { statement.finalize() }
        try statement.bind(record.id, at: 1)
        try statement.bind(record.sessionID, at: 2)
        try statement.bind(record.worktreeID, at: 3)
        try statement.bind(record.workItemID, at: 4)
        try statement.bind(record.declaredIntent, at: 5)
        try statement.bind(encoded(record.expectedScope), at: 6)
        try statement.bind(record.status, at: 7)
        try statement.bind(record.startedAt.timeIntervalSince1970, at: 8)
        try statement.bind(record.endedAt?.timeIntervalSince1970, at: 9)
        try statement.bind(record.assignmentConfidence.rawValue, at: 10)
        try statement.bind(record.updatedAt.timeIntervalSince1970, at: 11)
        _ = try statement.step()
    }

    private func upsert(_ record: WorkProvenanceCheckpointRecord) throws {
        let statement = try database.prepare(
            """
            INSERT INTO checkpoints (
                id, contribution_id, sequence, git_head, diff_fingerprint,
                summary, status, validation_state, semantic_confidence,
                freshness, created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                contribution_id = excluded.contribution_id,
                sequence = excluded.sequence,
                git_head = excluded.git_head,
                diff_fingerprint = excluded.diff_fingerprint,
                summary = excluded.summary,
                status = excluded.status,
                validation_state = excluded.validation_state,
                semantic_confidence = excluded.semantic_confidence,
                freshness = excluded.freshness,
                created_at = excluded.created_at
            """
        )
        defer { statement.finalize() }
        try statement.bind(record.id, at: 1)
        try statement.bind(record.contributionID, at: 2)
        try statement.bind(record.sequence, at: 3)
        try statement.bind(record.gitHEAD, at: 4)
        try statement.bind(record.diffFingerprint, at: 5)
        try statement.bind(record.summary, at: 6)
        try statement.bind(record.status, at: 7)
        try statement.bind(record.validationState, at: 8)
        try statement.bind(record.semanticConfidence.rawValue, at: 9)
        try statement.bind(record.freshness, at: 10)
        try statement.bind(record.createdAt.timeIntervalSince1970, at: 11)
        _ = try statement.step()
    }

    private func upsert(_ record: WorkProvenanceChangeSetRecord) throws {
        let statement = try database.prepare(
            """
            INSERT INTO change_sets (
                id, checkpoint_id, contribution_id, worktree_id,
                summary, diff_fingerprint, created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                checkpoint_id = excluded.checkpoint_id,
                contribution_id = excluded.contribution_id,
                worktree_id = excluded.worktree_id,
                summary = excluded.summary,
                diff_fingerprint = excluded.diff_fingerprint,
                created_at = excluded.created_at
            """
        )
        defer { statement.finalize() }
        try statement.bind(record.id, at: 1)
        try statement.bind(record.checkpointID, at: 2)
        try statement.bind(record.contributionID, at: 3)
        try statement.bind(record.worktreeID, at: 4)
        try statement.bind(record.summary, at: 5)
        try statement.bind(record.diffFingerprint, at: 6)
        try statement.bind(record.createdAt.timeIntervalSince1970, at: 7)
        _ = try statement.step()
    }

    private func upsert(_ record: WorkProvenanceFileChangeRecord) throws {
        let statement = try database.prepare(
            """
            INSERT INTO file_changes (
                id, change_set_id, repository_id, worktree_id, path, status,
                before_hash, after_hash, attribution_source,
                attribution_confidence, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                change_set_id = excluded.change_set_id,
                repository_id = excluded.repository_id,
                worktree_id = excluded.worktree_id,
                path = excluded.path,
                status = excluded.status,
                before_hash = excluded.before_hash,
                after_hash = excluded.after_hash,
                attribution_source = excluded.attribution_source,
                attribution_confidence = excluded.attribution_confidence,
                updated_at = excluded.updated_at
            """
        )
        defer { statement.finalize() }
        try statement.bind(record.id, at: 1)
        try statement.bind(record.changeSetID, at: 2)
        try statement.bind(record.repositoryID, at: 3)
        try statement.bind(record.worktreeID, at: 4)
        try statement.bind(record.path, at: 5)
        try statement.bind(record.status, at: 6)
        try statement.bind(record.beforeHash, at: 7)
        try statement.bind(record.afterHash, at: 8)
        try statement.bind(record.attributionSource.rawValue, at: 9)
        try statement.bind(record.attributionConfidence.rawValue, at: 10)
        try statement.bind(record.updatedAt.timeIntervalSince1970, at: 11)
        _ = try statement.step()
    }

    private func upsert(_ record: WorkProvenanceValidationRunRecord) throws {
        let statement = try database.prepare(
            """
            INSERT INTO validation_runs (
                id, checkpoint_id, contribution_id, command, status,
                summary, started_at, ended_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                checkpoint_id = excluded.checkpoint_id,
                contribution_id = excluded.contribution_id,
                command = excluded.command,
                status = excluded.status,
                summary = excluded.summary,
                started_at = excluded.started_at,
                ended_at = excluded.ended_at
            """
        )
        defer { statement.finalize() }
        try statement.bind(record.id, at: 1)
        try statement.bind(record.checkpointID, at: 2)
        try statement.bind(record.contributionID, at: 3)
        try statement.bind(record.command, at: 4)
        try statement.bind(record.status, at: 5)
        try statement.bind(record.summary, at: 6)
        try statement.bind(record.startedAt?.timeIntervalSince1970, at: 7)
        try statement.bind(record.endedAt?.timeIntervalSince1970, at: 8)
        _ = try statement.step()
    }

    private static var schemaSQL: String {
        """
        CREATE TABLE IF NOT EXISTS events (
            id TEXT PRIMARY KEY NOT NULL,
            schema_version INTEGER NOT NULL,
            event_type TEXT NOT NULL,
            timestamp REAL NOT NULL,
            repository_id TEXT,
            worktree_id TEXT,
            session_id TEXT,
            contribution_id TEXT,
            source TEXT NOT NULL,
            confidence TEXT NOT NULL,
            payload_json TEXT NOT NULL
        );

        CREATE INDEX IF NOT EXISTS events_worktree_idx ON events(worktree_id);
        CREATE INDEX IF NOT EXISTS events_contribution_idx ON events(contribution_id);
        CREATE INDEX IF NOT EXISTS events_type_timestamp_idx
            ON events(event_type, timestamp);
        CREATE INDEX IF NOT EXISTS events_worktree_type_timestamp_idx
            ON events(worktree_id, event_type, timestamp);

        CREATE TABLE IF NOT EXISTS repositories (
            id TEXT PRIMARY KEY NOT NULL,
            path TEXT NOT NULL,
            common_directory TEXT,
            remote_slug TEXT,
            created_at REAL NOT NULL,
            updated_at REAL NOT NULL
        );

        CREATE TABLE IF NOT EXISTS worktrees (
            id TEXT PRIMARY KEY NOT NULL,
            repository_id TEXT NOT NULL,
            path TEXT NOT NULL,
            branch TEXT,
            base_commit TEXT,
            current_head TEXT,
            is_dirty INTEGER NOT NULL,
            status TEXT NOT NULL,
            last_reconciled_at REAL,
            updated_at REAL NOT NULL
        );

        CREATE TABLE IF NOT EXISTS sessions (
            id TEXT PRIMARY KEY NOT NULL,
            agent_kind TEXT NOT NULL,
            workspace_id TEXT,
            surface_id TEXT,
            worktree_id TEXT,
            cwd TEXT,
            status TEXT NOT NULL,
            started_at REAL,
            updated_at REAL NOT NULL
        );

        CREATE TABLE IF NOT EXISTS session_relationships (
            session_id TEXT PRIMARY KEY NOT NULL,
            parent_session_id TEXT NOT NULL,
            root_session_id TEXT NOT NULL,
            inbound_delegation_id TEXT,
            depth INTEGER NOT NULL,
            source TEXT NOT NULL,
            confidence TEXT NOT NULL,
            created_at REAL NOT NULL,
            updated_at REAL NOT NULL
        );
        CREATE INDEX IF NOT EXISTS session_relationships_parent_idx
            ON session_relationships(parent_session_id, depth, updated_at);
        CREATE INDEX IF NOT EXISTS session_relationships_root_idx
            ON session_relationships(root_session_id, depth, updated_at);

        CREATE TABLE IF NOT EXISTS session_external_identities (
            id TEXT PRIMARY KEY NOT NULL,
            session_id TEXT NOT NULL,
            system TEXT NOT NULL,
            kind TEXT NOT NULL,
            external_id TEXT NOT NULL,
            source TEXT NOT NULL,
            confidence TEXT NOT NULL,
            created_at REAL NOT NULL,
            updated_at REAL NOT NULL
        );
        CREATE UNIQUE INDEX IF NOT EXISTS session_external_identities_unique_idx
            ON session_external_identities(system, kind, external_id);
        CREATE INDEX IF NOT EXISTS session_external_identities_session_idx
            ON session_external_identities(session_id, system, kind);

        CREATE TABLE IF NOT EXISTS work_items (
            id TEXT PRIMARY KEY NOT NULL,
            title TEXT NOT NULL,
            status TEXT NOT NULL,
            created_at REAL NOT NULL,
            updated_at REAL NOT NULL
        );

        CREATE TABLE IF NOT EXISTS work_contributions (
            id TEXT PRIMARY KEY NOT NULL,
            session_id TEXT NOT NULL,
            worktree_id TEXT NOT NULL,
            work_item_id TEXT NOT NULL,
            declared_intent TEXT,
            expected_scope_json TEXT NOT NULL,
            status TEXT NOT NULL,
            started_at REAL NOT NULL,
            ended_at REAL,
            assignment_confidence TEXT NOT NULL,
            updated_at REAL NOT NULL
        );

        CREATE TABLE IF NOT EXISTS checkpoints (
            id TEXT PRIMARY KEY NOT NULL,
            contribution_id TEXT NOT NULL,
            sequence INTEGER NOT NULL,
            git_head TEXT,
            diff_fingerprint TEXT,
            summary TEXT,
            status TEXT NOT NULL,
            validation_state TEXT,
            semantic_confidence TEXT NOT NULL,
            freshness TEXT NOT NULL,
            created_at REAL NOT NULL
        );

        CREATE TABLE IF NOT EXISTS change_sets (
            id TEXT PRIMARY KEY NOT NULL,
            checkpoint_id TEXT,
            contribution_id TEXT,
            worktree_id TEXT NOT NULL,
            summary TEXT,
            diff_fingerprint TEXT,
            created_at REAL NOT NULL
        );
        CREATE INDEX IF NOT EXISTS change_sets_worktree_created_idx
            ON change_sets(worktree_id, created_at);

        CREATE TABLE IF NOT EXISTS file_changes (
            id TEXT PRIMARY KEY NOT NULL,
            change_set_id TEXT NOT NULL,
            repository_id TEXT NOT NULL,
            worktree_id TEXT NOT NULL,
            path TEXT NOT NULL,
            status TEXT NOT NULL,
            before_hash TEXT,
            after_hash TEXT,
            attribution_source TEXT NOT NULL,
            attribution_confidence TEXT NOT NULL,
            updated_at REAL NOT NULL
        );

        CREATE INDEX IF NOT EXISTS file_changes_worktree_path_idx
            ON file_changes(worktree_id, path, updated_at);
        CREATE INDEX IF NOT EXISTS file_changes_source_updated_idx
            ON file_changes(attribution_source, updated_at);

        CREATE TABLE IF NOT EXISTS validation_runs (
            id TEXT PRIMARY KEY NOT NULL,
            checkpoint_id TEXT,
            contribution_id TEXT,
            command TEXT NOT NULL,
            status TEXT NOT NULL,
            summary TEXT,
            started_at REAL,
            ended_at REAL
        );
        """
    }

    private static var schemaV2SQL: String {
        """
        CREATE INDEX IF NOT EXISTS events_type_timestamp_idx
            ON events(event_type, timestamp);
        CREATE INDEX IF NOT EXISTS events_worktree_type_timestamp_idx
            ON events(worktree_id, event_type, timestamp);
        CREATE INDEX IF NOT EXISTS change_sets_worktree_created_idx
            ON change_sets(worktree_id, created_at);
        CREATE INDEX IF NOT EXISTS file_changes_source_updated_idx
            ON file_changes(attribution_source, updated_at);
        """
    }

    private static var schemaV3SQL: String {
        """
        CREATE TABLE IF NOT EXISTS session_relationships (
            session_id TEXT PRIMARY KEY NOT NULL,
            parent_session_id TEXT NOT NULL,
            root_session_id TEXT NOT NULL,
            inbound_delegation_id TEXT,
            depth INTEGER NOT NULL,
            source TEXT NOT NULL,
            confidence TEXT NOT NULL,
            created_at REAL NOT NULL,
            updated_at REAL NOT NULL
        );
        CREATE INDEX IF NOT EXISTS session_relationships_parent_idx
            ON session_relationships(parent_session_id, depth, updated_at);
        CREATE INDEX IF NOT EXISTS session_relationships_root_idx
            ON session_relationships(root_session_id, depth, updated_at);

        CREATE TABLE IF NOT EXISTS session_external_identities (
            id TEXT PRIMARY KEY NOT NULL,
            session_id TEXT NOT NULL,
            system TEXT NOT NULL,
            kind TEXT NOT NULL,
            external_id TEXT NOT NULL,
            source TEXT NOT NULL,
            confidence TEXT NOT NULL,
            created_at REAL NOT NULL,
            updated_at REAL NOT NULL
        );
        CREATE UNIQUE INDEX IF NOT EXISTS session_external_identities_unique_idx
            ON session_external_identities(system, kind, external_id);
        CREATE INDEX IF NOT EXISTS session_external_identities_session_idx
            ON session_external_identities(session_id, system, kind);
        """
    }
}
