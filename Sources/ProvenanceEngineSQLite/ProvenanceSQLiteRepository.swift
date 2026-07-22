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
            if let repository = event.payload.repository {
                try upsertRepository(repository)
            }
            if let worktree = event.payload.worktree {
                try upsertWorktree(worktree)
            }
            if let session = event.payload.session {
                try upsertSession(session)
            }
            if let sessionRelationship = event.payload.sessionRelationship {
                try upsertSessionRelationship(sessionRelationship)
            }
            for externalIdentity in event.payload.externalIdentities {
                try upsertExternalIdentity(externalIdentity)
            }
            if let workItem = event.payload.workItem {
                try upsertWorkItem(workItem)
            }
            if let contribution = event.payload.contribution {
                try upsertContribution(contribution)
            }
            if let checkpoint = event.payload.checkpoint {
                try upsertCheckpoint(checkpoint)
            }
            if let changeSet = event.payload.changeSet {
                try upsertChangeSet(changeSet)
            }
            for fileChange in event.payload.fileChanges {
                try upsertFileChange(fileChange)
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

    /// Reads one current-state repository projection by stable ID.
    ///
    /// - Parameter id: Stable repository identifier.
    /// - Returns: The persisted repository projection, or `nil` when the ID is unknown.
    /// - Throws: ``ProvenanceSQLiteError`` when SQLite rejects the read.
    func repository(id: String) throws -> ProvenanceRepositoryRecord? {
        let query = try database.prepare(
            """
            SELECT
                path,
                common_directory,
                remote_slug,
                created_at_seconds,
                updated_at_seconds
            FROM provenance_repositories
            WHERE id = ?
            """
        )
        defer { query.finalize() }

        try query.bind(id, at: 1)
        guard try query.step() else { return nil }

        return ProvenanceRepositoryRecord(
            id: id,
            path: query.string(at: 0) ?? "",
            commonDirectory: query.string(at: 1),
            remoteSlug: query.string(at: 2),
            createdAt: Date(timeIntervalSince1970: query.double(at: 3) ?? 0),
            updatedAt: Date(timeIntervalSince1970: query.double(at: 4) ?? 0)
        )
    }

    /// Reads one current-state worktree projection by stable ID.
    ///
    /// - Parameter id: Stable worktree identifier.
    /// - Returns: The persisted worktree projection, or `nil` when the ID is unknown.
    /// - Throws: ``ProvenanceSQLiteError`` when SQLite rejects the read.
    func worktree(id: String) throws -> ProvenanceWorktreeRecord? {
        let query = try database.prepare(
            """
            SELECT
                repository_id,
                path,
                branch,
                base_commit,
                current_head,
                is_dirty,
                status,
                last_reconciled_at_seconds,
                updated_at_seconds
            FROM provenance_worktrees
            WHERE id = ?
            """
        )
        defer { query.finalize() }

        try query.bind(id, at: 1)
        guard try query.step() else { return nil }

        return ProvenanceWorktreeRecord(
            id: id,
            repositoryID: query.string(at: 0) ?? "",
            path: query.string(at: 1) ?? "",
            branch: query.string(at: 2),
            baseCommit: query.string(at: 3),
            currentHEAD: query.string(at: 4),
            isDirty: query.int(at: 5) != 0,
            status: query.string(at: 6) ?? "",
            lastReconciledAt: query.double(at: 7).map { Date(timeIntervalSince1970: $0) },
            updatedAt: Date(timeIntervalSince1970: query.double(at: 8) ?? 0)
        )
    }

    /// Lists current-state worktree projections with linked repository projections when available.
    ///
    /// - Parameter request: Worktree-list query parameters.
    /// - Returns: Worktrees sorted by newest update first.
    /// - Throws: ``ProvenanceSQLiteError`` when SQLite rejects the read.
    func worktrees(_ request: ProvenanceWorktreeListRequest) throws -> ProvenanceWorktreeListResponse {
        let rowLimit = request.limit.map { max(0, $0) }
        var sql = """
            SELECT
                id,
                repository_id,
                path,
                branch,
                base_commit,
                current_head,
                is_dirty,
                status,
                last_reconciled_at_seconds,
                updated_at_seconds
            FROM provenance_worktrees
            """
        if request.repositoryID != nil {
            sql += "\nWHERE repository_id = ?"
        }
        sql += "\nORDER BY updated_at_seconds DESC, rowid DESC"
        if rowLimit != nil {
            sql += "\nLIMIT ?"
        }

        let query = try database.prepare(sql)
        defer { query.finalize() }

        var bindIndex: Int32 = 1
        if let repositoryID = request.repositoryID {
            try query.bind(repositoryID, at: bindIndex)
            bindIndex += 1
        }
        if let rowLimit {
            try query.bind(rowLimit, at: bindIndex)
        }

        var entries: [ProvenanceWorktreeListEntry] = []
        while try query.step() {
            guard let worktree = worktree(from: query) else { continue }
            entries.append(
                ProvenanceWorktreeListEntry(
                    worktree: worktree,
                    repository: try repository(id: worktree.repositoryID)
                )
            )
        }

        return ProvenanceWorktreeListResponse(worktrees: entries)
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

    /// Reads the direct parent relationship for one session projection.
    ///
    /// - Parameter sessionID: Stable child session identifier.
    /// - Returns: The parent relationship projection, or `nil` when the session has no known parent.
    /// - Throws: ``ProvenanceSQLiteError`` when SQLite rejects the read.
    func parentSession(for sessionID: String) throws -> ProvenanceSessionRelationshipRecord? {
        try sessionRelationship(sessionID: sessionID)
    }

    /// Reads direct child relationship projections for one parent session.
    ///
    /// - Parameter sessionID: Stable parent session identifier.
    /// - Returns: Child relationships sorted by depth, update time, then child session ID.
    /// - Throws: ``ProvenanceSQLiteError`` when SQLite rejects the read.
    func childSessions(for sessionID: String) throws -> [ProvenanceSessionRelationshipRecord] {
        try childSessionRelationships(parentSessionID: sessionID)
    }

    /// Reads external identities linked to one session projection.
    ///
    /// - Parameter sessionID: Stable session identifier.
    /// - Returns: Identity links sorted by system, kind, then external identifier.
    /// - Throws: ``ProvenanceSQLiteError`` when SQLite rejects the read.
    func externalIdentities(sessionID: String) throws -> [ProvenanceExternalIdentityRecord] {
        try externalIdentityRecords(sessionID: sessionID)
    }

    /// Reads the bounded current session tree rooted at the requested session.
    ///
    /// - Parameter request: Session-tree query parameters.
    /// - Returns: Depth-first tree response with linked external identities.
    /// - Throws: ``ProvenanceSQLiteError`` when SQLite rejects the read.
    func sessionTree(_ request: ProvenanceSessionTreeRequest) throws -> ProvenanceSessionTreeResponse {
        let rowLimit = request.limit.map { max(0, $0) }
        var sessions: [ProvenanceSessionRecord] = []
        var relationships: [ProvenanceSessionRelationshipRecord] = []
        var visitedSessionIDs = Set<String>()

        func hasSessionCapacity() -> Bool {
            rowLimit.map { sessions.count < $0 } ?? true
        }

        func hasRelationshipCapacity() -> Bool {
            rowLimit.map { relationships.count < $0 } ?? true
        }

        func appendSessionIfPresent(_ sessionID: String) throws {
            guard hasSessionCapacity(), let session = try session(id: sessionID) else { return }
            sessions.append(session)
        }

        func visit(_ sessionID: String, treeDepth: Int) throws {
            guard treeDepth <= 50, !visitedSessionIDs.contains(sessionID) else { return }
            visitedSessionIDs.insert(sessionID)
            try appendSessionIfPresent(sessionID)
            guard treeDepth < 50 else { return }
            for relationship in try childSessionRelationships(parentSessionID: sessionID) {
                guard !visitedSessionIDs.contains(relationship.sessionID) else { continue }
                if hasRelationshipCapacity() {
                    relationships.append(relationship)
                }
                try visit(relationship.sessionID, treeDepth: treeDepth + 1)
            }
        }

        try visit(request.rootSessionID, treeDepth: 0)
        let includedSessionIDs = Set(sessions.map(\.id))
        let includedRelationships = relationships.filter { includedSessionIDs.contains($0.sessionID) }
        let identities = try sessions.flatMap { try externalIdentityRecords(sessionID: $0.id) }
        let found = !sessions.isEmpty || !includedRelationships.isEmpty

        return ProvenanceSessionTreeResponse(
            rootSessionID: request.rootSessionID,
            found: found,
            reason: found ? nil : "no_session",
            sessions: sessions,
            relationships: includedRelationships,
            externalIdentities: identities
        )
    }

    /// Reads focused provenance context for one repository-relative file path.
    ///
    /// - Parameter request: File-explanation query parameters.
    /// - Returns: Found response with linked projections, or `no_file` when no file-change projection matches.
    /// - Throws: ``ProvenanceSQLiteError`` when SQLite rejects the read.
    func fileExplanation(_ request: ProvenanceFileExplanationRequest) throws -> ProvenanceFileExplanationResponse {
        guard let fileChange = try fileChange(worktreeID: request.worktreeID, path: request.path) else {
            return ProvenanceFileExplanationResponse(
                found: false,
                reason: "no_file",
                explanation: nil
            )
        }

        let changeSet = try changeSet(id: fileChange.changeSetID)
        let checkpoint: ProvenanceCheckpointRecord?
        if let checkpointID = changeSet?.checkpointID {
            checkpoint = try checkpointRecord(id: checkpointID)
        } else {
            checkpoint = nil
        }

        let contributionID = changeSet?.contributionID ?? checkpoint?.contributionID
        let contribution: ProvenanceContributionRecord?
        if let contributionID {
            contribution = try contributionRecord(id: contributionID)
        } else {
            contribution = nil
        }

        let session: ProvenanceSessionRecord?
        if let contribution {
            session = try self.session(id: contribution.sessionID)
        } else {
            session = nil
        }

        let workItem: ProvenanceWorkItemRecord?
        if let contribution {
            workItem = try workItemRecord(id: contribution.workItemID)
        } else {
            workItem = nil
        }

        let worktree = try self.worktree(id: fileChange.worktreeID)
        let repositoryID = worktree?.repositoryID ?? fileChange.repositoryID
        let repository = try self.repository(id: repositoryID)

        return ProvenanceFileExplanationResponse(
            found: true,
            explanation: ProvenanceFileExplanation(
                fileChange: fileChange,
                changeSet: changeSet,
                checkpoint: checkpoint,
                contribution: contribution,
                session: session,
                workItem: workItem,
                worktree: worktree,
                repository: repository
            )
        )
    }

    private func worktree(from query: ProvenanceSQLiteStatement) -> ProvenanceWorktreeRecord? {
        guard let id = query.string(at: 0),
              let repositoryID = query.string(at: 1),
              let path = query.string(at: 2),
              let status = query.string(at: 7) else {
            return nil
        }

        return ProvenanceWorktreeRecord(
            id: id,
            repositoryID: repositoryID,
            path: path,
            branch: query.string(at: 3),
            baseCommit: query.string(at: 4),
            currentHEAD: query.string(at: 5),
            isDirty: query.int(at: 6) != 0,
            status: status,
            lastReconciledAt: query.double(at: 8).map { Date(timeIntervalSince1970: $0) },
            updatedAt: Date(timeIntervalSince1970: query.double(at: 9) ?? 0)
        )
    }

    private func sessionRelationship(
        sessionID: String
    ) throws -> ProvenanceSessionRelationshipRecord? {
        let query = try database.prepare(
            """
            SELECT
                session_id,
                parent_session_id,
                root_session_id,
                inbound_delegation_id,
                depth,
                source,
                confidence,
                created_at_seconds,
                updated_at_seconds
            FROM provenance_session_relationships
            WHERE session_id = ?
            """
        )
        defer { query.finalize() }

        try query.bind(sessionID, at: 1)
        guard try query.step() else { return nil }
        return sessionRelationship(from: query)
    }

    private func childSessionRelationships(
        parentSessionID: String
    ) throws -> [ProvenanceSessionRelationshipRecord] {
        let query = try database.prepare(
            """
            SELECT
                session_id,
                parent_session_id,
                root_session_id,
                inbound_delegation_id,
                depth,
                source,
                confidence,
                created_at_seconds,
                updated_at_seconds
            FROM provenance_session_relationships
            WHERE parent_session_id = ?
            ORDER BY depth ASC, updated_at_seconds ASC, session_id ASC
            """
        )
        defer { query.finalize() }

        try query.bind(parentSessionID, at: 1)
        var records: [ProvenanceSessionRelationshipRecord] = []
        while try query.step() {
            if let record = sessionRelationship(from: query) {
                records.append(record)
            }
        }
        return records
    }

    private func sessionRelationship(
        from query: ProvenanceSQLiteStatement
    ) -> ProvenanceSessionRelationshipRecord? {
        guard let sessionID = query.string(at: 0),
              let parentSessionID = query.string(at: 1),
              let rootSessionID = query.string(at: 2),
              let sourceRawValue = query.string(at: 5),
              let source = ProvenanceSource(rawValue: sourceRawValue),
              let confidenceRawValue = query.string(at: 6),
              let confidence = ProvenanceConfidence(rawValue: confidenceRawValue) else {
            return nil
        }

        return ProvenanceSessionRelationshipRecord(
            sessionID: sessionID,
            parentSessionID: parentSessionID,
            rootSessionID: rootSessionID,
            inboundDelegationID: query.string(at: 3),
            depth: query.int(at: 4),
            source: source,
            confidence: confidence,
            createdAt: Date(timeIntervalSince1970: query.double(at: 7) ?? 0),
            updatedAt: Date(timeIntervalSince1970: query.double(at: 8) ?? 0)
        )
    }

    private func externalIdentityRecords(
        sessionID: String
    ) throws -> [ProvenanceExternalIdentityRecord] {
        let query = try database.prepare(
            """
            SELECT
                id,
                session_id,
                system,
                kind,
                external_id,
                source,
                confidence,
                created_at_seconds,
                updated_at_seconds
            FROM provenance_session_external_identities
            WHERE session_id = ?
            ORDER BY system ASC, kind ASC, external_id ASC
            """
        )
        defer { query.finalize() }

        try query.bind(sessionID, at: 1)
        var records: [ProvenanceExternalIdentityRecord] = []
        while try query.step() {
            guard let id = query.string(at: 0),
                  let sessionID = query.string(at: 1),
                  let system = query.string(at: 2),
                  let kind = query.string(at: 3),
                  let externalID = query.string(at: 4),
                  let sourceRawValue = query.string(at: 5),
                  let source = ProvenanceSource(rawValue: sourceRawValue),
                  let confidenceRawValue = query.string(at: 6),
                  let confidence = ProvenanceConfidence(rawValue: confidenceRawValue) else {
                continue
            }
            records.append(
                ProvenanceExternalIdentityRecord(
                    id: id,
                    sessionID: sessionID,
                    system: system,
                    kind: kind,
                    externalID: externalID,
                    source: source,
                    confidence: confidence,
                    createdAt: Date(timeIntervalSince1970: query.double(at: 7) ?? 0),
                    updatedAt: Date(timeIntervalSince1970: query.double(at: 8) ?? 0)
                )
            )
        }
        return records
    }

    private func workItemRecord(id: String) throws -> ProvenanceWorkItemRecord? {
        let query = try database.prepare(
            """
            SELECT title, status, created_at_seconds, updated_at_seconds
            FROM provenance_work_items
            WHERE id = ?
            """
        )
        defer { query.finalize() }

        try query.bind(id, at: 1)
        guard try query.step(),
              let title = query.string(at: 0),
              let status = query.string(at: 1) else {
            return nil
        }

        return ProvenanceWorkItemRecord(
            id: id,
            title: title,
            status: status,
            createdAt: Date(timeIntervalSince1970: query.double(at: 2) ?? 0),
            updatedAt: Date(timeIntervalSince1970: query.double(at: 3) ?? 0)
        )
    }

    private func contributionRecord(id: String) throws -> ProvenanceContributionRecord? {
        let query = try database.prepare(
            """
            SELECT
                session_id,
                worktree_id,
                work_item_id,
                declared_intent,
                expected_scope_json,
                status,
                started_at_seconds,
                ended_at_seconds,
                assignment_confidence,
                updated_at_seconds
            FROM provenance_work_contributions
            WHERE id = ?
            """
        )
        defer { query.finalize() }

        try query.bind(id, at: 1)
        guard try query.step(),
              let sessionID = query.string(at: 0),
              let worktreeID = query.string(at: 1),
              let workItemID = query.string(at: 2),
              let expectedScopeJSON = query.string(at: 4),
              let expectedScopeData = expectedScopeJSON.data(using: .utf8),
              let status = query.string(at: 5),
              let confidenceRawValue = query.string(at: 8),
              let confidence = ProvenanceConfidence(rawValue: confidenceRawValue) else {
            return nil
        }

        let expectedScope = (try? payloadDecoder.decode([String].self, from: expectedScopeData)) ?? []
        return ProvenanceContributionRecord(
            id: id,
            sessionID: sessionID,
            worktreeID: worktreeID,
            workItemID: workItemID,
            declaredIntent: query.string(at: 3),
            expectedScope: expectedScope,
            status: status,
            startedAt: Date(timeIntervalSince1970: query.double(at: 6) ?? 0),
            endedAt: query.double(at: 7).map { Date(timeIntervalSince1970: $0) },
            assignmentConfidence: confidence,
            updatedAt: Date(timeIntervalSince1970: query.double(at: 9) ?? 0)
        )
    }

    private func checkpointRecord(id: String) throws -> ProvenanceCheckpointRecord? {
        let query = try database.prepare(
            """
            SELECT
                contribution_id,
                sequence,
                git_head,
                diff_fingerprint,
                summary,
                status,
                validation_state,
                semantic_confidence,
                freshness,
                created_at_seconds
            FROM provenance_checkpoints
            WHERE id = ?
            """
        )
        defer { query.finalize() }

        try query.bind(id, at: 1)
        guard try query.step(),
              let contributionID = query.string(at: 0),
              let status = query.string(at: 5),
              let confidenceRawValue = query.string(at: 7),
              let confidence = ProvenanceConfidence(rawValue: confidenceRawValue),
              let freshness = query.string(at: 8) else {
            return nil
        }

        return ProvenanceCheckpointRecord(
            id: id,
            contributionID: contributionID,
            sequence: query.int(at: 1),
            gitHEAD: query.string(at: 2),
            diffFingerprint: query.string(at: 3),
            summary: query.string(at: 4),
            status: status,
            validationState: query.string(at: 6),
            semanticConfidence: confidence,
            freshness: freshness,
            createdAt: Date(timeIntervalSince1970: query.double(at: 9) ?? 0)
        )
    }

    private func changeSet(id: String) throws -> ProvenanceChangeSetRecord? {
        let query = try database.prepare(
            """
            SELECT
                checkpoint_id,
                contribution_id,
                worktree_id,
                summary,
                diff_fingerprint,
                created_at_seconds
            FROM provenance_change_sets
            WHERE id = ?
            """
        )
        defer { query.finalize() }

        try query.bind(id, at: 1)
        guard try query.step(), let worktreeID = query.string(at: 2) else {
            return nil
        }

        return ProvenanceChangeSetRecord(
            id: id,
            checkpointID: query.string(at: 0),
            contributionID: query.string(at: 1),
            worktreeID: worktreeID,
            summary: query.string(at: 3),
            diffFingerprint: query.string(at: 4),
            createdAt: Date(timeIntervalSince1970: query.double(at: 5) ?? 0)
        )
    }

    private func fileChange(worktreeID: String, path: String) throws -> ProvenanceFileChangeRecord? {
        let query = try database.prepare(
            """
            SELECT
                id,
                change_set_id,
                repository_id,
                worktree_id,
                path,
                status,
                before_hash,
                after_hash,
                attribution_source,
                attribution_confidence,
                updated_at_seconds
            FROM provenance_file_changes
            WHERE worktree_id = ? AND path = ?
            ORDER BY updated_at_seconds DESC, rowid DESC
            LIMIT 1
            """
        )
        defer { query.finalize() }

        try query.bind(worktreeID, at: 1)
        try query.bind(path, at: 2)
        guard try query.step() else { return nil }
        return fileChange(from: query)
    }

    private func fileChange(from query: ProvenanceSQLiteStatement) -> ProvenanceFileChangeRecord? {
        guard let id = query.string(at: 0),
              let changeSetID = query.string(at: 1),
              let repositoryID = query.string(at: 2),
              let worktreeID = query.string(at: 3),
              let path = query.string(at: 4),
              let status = query.string(at: 5),
              let sourceRawValue = query.string(at: 8),
              let source = ProvenanceSource(rawValue: sourceRawValue),
              let confidenceRawValue = query.string(at: 9),
              let confidence = ProvenanceConfidence(rawValue: confidenceRawValue) else {
            return nil
        }

        return ProvenanceFileChangeRecord(
            id: id,
            changeSetID: changeSetID,
            repositoryID: repositoryID,
            worktreeID: worktreeID,
            path: path,
            status: status,
            beforeHash: query.string(at: 6),
            afterHash: query.string(at: 7),
            attributionSource: source,
            attributionConfidence: confidence,
            updatedAt: Date(timeIntervalSince1970: query.double(at: 10) ?? 0)
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

    private func upsertRepository(_ repository: ProvenanceRepositoryRecord) throws {
        let upsert = try database.prepare(
            """
            INSERT INTO provenance_repositories (
                id,
                path,
                common_directory,
                remote_slug,
                created_at_seconds,
                updated_at_seconds
            ) VALUES (?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                path = excluded.path,
                common_directory = excluded.common_directory,
                remote_slug = excluded.remote_slug,
                updated_at_seconds = excluded.updated_at_seconds
            """
        )
        defer { upsert.finalize() }

        try upsert.bind(repository.id, at: 1)
        try upsert.bind(repository.path, at: 2)
        try upsert.bind(repository.commonDirectory, at: 3)
        try upsert.bind(repository.remoteSlug, at: 4)
        try upsert.bind(repository.createdAt.timeIntervalSince1970, at: 5)
        try upsert.bind(repository.updatedAt.timeIntervalSince1970, at: 6)

        _ = try upsert.step()
    }

    private func upsertWorktree(_ worktree: ProvenanceWorktreeRecord) throws {
        let upsert = try database.prepare(
            """
            INSERT INTO provenance_worktrees (
                id,
                repository_id,
                path,
                branch,
                base_commit,
                current_head,
                is_dirty,
                status,
                last_reconciled_at_seconds,
                updated_at_seconds
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                repository_id = excluded.repository_id,
                path = excluded.path,
                branch = excluded.branch,
                base_commit = excluded.base_commit,
                current_head = excluded.current_head,
                is_dirty = excluded.is_dirty,
                status = excluded.status,
                last_reconciled_at_seconds = excluded.last_reconciled_at_seconds,
                updated_at_seconds = excluded.updated_at_seconds
            """
        )
        defer { upsert.finalize() }

        try upsert.bind(worktree.id, at: 1)
        try upsert.bind(worktree.repositoryID, at: 2)
        try upsert.bind(worktree.path, at: 3)
        try upsert.bind(worktree.branch, at: 4)
        try upsert.bind(worktree.baseCommit, at: 5)
        try upsert.bind(worktree.currentHEAD, at: 6)
        try upsert.bind(worktree.isDirty ? 1 : 0, at: 7)
        try upsert.bind(worktree.status, at: 8)
        try upsert.bind(worktree.lastReconciledAt?.timeIntervalSince1970, at: 9)
        try upsert.bind(worktree.updatedAt.timeIntervalSince1970, at: 10)

        _ = try upsert.step()
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

    private func upsertSessionRelationship(_ relationship: ProvenanceSessionRelationshipRecord) throws {
        let upsert = try database.prepare(
            """
            INSERT INTO provenance_session_relationships (
                session_id,
                parent_session_id,
                root_session_id,
                inbound_delegation_id,
                depth,
                source,
                confidence,
                created_at_seconds,
                updated_at_seconds
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(session_id) DO UPDATE SET
                parent_session_id = excluded.parent_session_id,
                root_session_id = excluded.root_session_id,
                inbound_delegation_id = excluded.inbound_delegation_id,
                depth = excluded.depth,
                source = excluded.source,
                confidence = excluded.confidence,
                updated_at_seconds = excluded.updated_at_seconds
            """
        )
        defer { upsert.finalize() }

        try upsert.bind(relationship.sessionID, at: 1)
        try upsert.bind(relationship.parentSessionID, at: 2)
        try upsert.bind(relationship.rootSessionID, at: 3)
        try upsert.bind(relationship.inboundDelegationID, at: 4)
        try upsert.bind(relationship.depth, at: 5)
        try upsert.bind(relationship.source.rawValue, at: 6)
        try upsert.bind(relationship.confidence.rawValue, at: 7)
        try upsert.bind(relationship.createdAt.timeIntervalSince1970, at: 8)
        try upsert.bind(relationship.updatedAt.timeIntervalSince1970, at: 9)

        _ = try upsert.step()
    }

    private func upsertExternalIdentity(_ identity: ProvenanceExternalIdentityRecord) throws {
        let upsert = try database.prepare(
            """
            INSERT INTO provenance_session_external_identities (
                id,
                session_id,
                system,
                kind,
                external_id,
                source,
                confidence,
                created_at_seconds,
                updated_at_seconds
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(system, kind, external_id) DO UPDATE SET
                session_id = excluded.session_id,
                source = excluded.source,
                confidence = excluded.confidence,
                updated_at_seconds = excluded.updated_at_seconds
            """
        )
        defer { upsert.finalize() }

        try upsert.bind(identity.id, at: 1)
        try upsert.bind(identity.sessionID, at: 2)
        try upsert.bind(identity.system, at: 3)
        try upsert.bind(identity.kind, at: 4)
        try upsert.bind(identity.externalID, at: 5)
        try upsert.bind(identity.source.rawValue, at: 6)
        try upsert.bind(identity.confidence.rawValue, at: 7)
        try upsert.bind(identity.createdAt.timeIntervalSince1970, at: 8)
        try upsert.bind(identity.updatedAt.timeIntervalSince1970, at: 9)

        _ = try upsert.step()
    }

    private func upsertWorkItem(_ workItem: ProvenanceWorkItemRecord) throws {
        let upsert = try database.prepare(
            """
            INSERT INTO provenance_work_items (
                id,
                title,
                status,
                created_at_seconds,
                updated_at_seconds
            ) VALUES (?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                title = excluded.title,
                status = excluded.status,
                updated_at_seconds = excluded.updated_at_seconds
            """
        )
        defer { upsert.finalize() }

        try upsert.bind(workItem.id, at: 1)
        try upsert.bind(workItem.title, at: 2)
        try upsert.bind(workItem.status, at: 3)
        try upsert.bind(workItem.createdAt.timeIntervalSince1970, at: 4)
        try upsert.bind(workItem.updatedAt.timeIntervalSince1970, at: 5)

        _ = try upsert.step()
    }

    private func upsertContribution(_ contribution: ProvenanceContributionRecord) throws {
        let expectedScopeData = try payloadEncoder.encode(contribution.expectedScope)
        guard let expectedScopeJSON = String(data: expectedScopeData, encoding: .utf8) else {
            throw ProvenanceSQLiteError.sqlite(message: "failed to encode contribution expected scope")
        }

        let upsert = try database.prepare(
            """
            INSERT INTO provenance_work_contributions (
                id,
                session_id,
                worktree_id,
                work_item_id,
                declared_intent,
                expected_scope_json,
                status,
                started_at_seconds,
                ended_at_seconds,
                assignment_confidence,
                updated_at_seconds
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                session_id = excluded.session_id,
                worktree_id = excluded.worktree_id,
                work_item_id = excluded.work_item_id,
                declared_intent = excluded.declared_intent,
                expected_scope_json = excluded.expected_scope_json,
                status = excluded.status,
                ended_at_seconds = excluded.ended_at_seconds,
                assignment_confidence = excluded.assignment_confidence,
                updated_at_seconds = excluded.updated_at_seconds
            """
        )
        defer { upsert.finalize() }

        try upsert.bind(contribution.id, at: 1)
        try upsert.bind(contribution.sessionID, at: 2)
        try upsert.bind(contribution.worktreeID, at: 3)
        try upsert.bind(contribution.workItemID, at: 4)
        try upsert.bind(contribution.declaredIntent, at: 5)
        try upsert.bind(expectedScopeJSON, at: 6)
        try upsert.bind(contribution.status, at: 7)
        try upsert.bind(contribution.startedAt.timeIntervalSince1970, at: 8)
        try upsert.bind(contribution.endedAt?.timeIntervalSince1970, at: 9)
        try upsert.bind(contribution.assignmentConfidence.rawValue, at: 10)
        try upsert.bind(contribution.updatedAt.timeIntervalSince1970, at: 11)

        _ = try upsert.step()
    }

    private func upsertCheckpoint(_ checkpoint: ProvenanceCheckpointRecord) throws {
        let upsert = try database.prepare(
            """
            INSERT INTO provenance_checkpoints (
                id,
                contribution_id,
                sequence,
                git_head,
                diff_fingerprint,
                summary,
                status,
                validation_state,
                semantic_confidence,
                freshness,
                created_at_seconds
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
                freshness = excluded.freshness
            """
        )
        defer { upsert.finalize() }

        try upsert.bind(checkpoint.id, at: 1)
        try upsert.bind(checkpoint.contributionID, at: 2)
        try upsert.bind(checkpoint.sequence, at: 3)
        try upsert.bind(checkpoint.gitHEAD, at: 4)
        try upsert.bind(checkpoint.diffFingerprint, at: 5)
        try upsert.bind(checkpoint.summary, at: 6)
        try upsert.bind(checkpoint.status, at: 7)
        try upsert.bind(checkpoint.validationState, at: 8)
        try upsert.bind(checkpoint.semanticConfidence.rawValue, at: 9)
        try upsert.bind(checkpoint.freshness, at: 10)
        try upsert.bind(checkpoint.createdAt.timeIntervalSince1970, at: 11)

        _ = try upsert.step()
    }

    private func upsertChangeSet(_ changeSet: ProvenanceChangeSetRecord) throws {
        let upsert = try database.prepare(
            """
            INSERT INTO provenance_change_sets (
                id,
                checkpoint_id,
                contribution_id,
                worktree_id,
                summary,
                diff_fingerprint,
                created_at_seconds
            ) VALUES (?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                checkpoint_id = excluded.checkpoint_id,
                contribution_id = excluded.contribution_id,
                worktree_id = excluded.worktree_id,
                summary = excluded.summary,
                diff_fingerprint = excluded.diff_fingerprint
            """
        )
        defer { upsert.finalize() }

        try upsert.bind(changeSet.id, at: 1)
        try upsert.bind(changeSet.checkpointID, at: 2)
        try upsert.bind(changeSet.contributionID, at: 3)
        try upsert.bind(changeSet.worktreeID, at: 4)
        try upsert.bind(changeSet.summary, at: 5)
        try upsert.bind(changeSet.diffFingerprint, at: 6)
        try upsert.bind(changeSet.createdAt.timeIntervalSince1970, at: 7)

        _ = try upsert.step()
    }

    private func upsertFileChange(_ fileChange: ProvenanceFileChangeRecord) throws {
        let upsert = try database.prepare(
            """
            INSERT INTO provenance_file_changes (
                id,
                change_set_id,
                repository_id,
                worktree_id,
                path,
                status,
                before_hash,
                after_hash,
                attribution_source,
                attribution_confidence,
                updated_at_seconds
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
                updated_at_seconds = excluded.updated_at_seconds
            """
        )
        defer { upsert.finalize() }

        try upsert.bind(fileChange.id, at: 1)
        try upsert.bind(fileChange.changeSetID, at: 2)
        try upsert.bind(fileChange.repositoryID, at: 3)
        try upsert.bind(fileChange.worktreeID, at: 4)
        try upsert.bind(fileChange.path, at: 5)
        try upsert.bind(fileChange.status, at: 6)
        try upsert.bind(fileChange.beforeHash, at: 7)
        try upsert.bind(fileChange.afterHash, at: 8)
        try upsert.bind(fileChange.attributionSource.rawValue, at: 9)
        try upsert.bind(fileChange.attributionConfidence.rawValue, at: 10)
        try upsert.bind(fileChange.updatedAt.timeIntervalSince1970, at: 11)

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
        ProvenanceSQLiteMigration(
            version: 3,
            statements: [
                """
                CREATE TABLE provenance_repositories (
                    id TEXT PRIMARY KEY NOT NULL,
                    path TEXT NOT NULL,
                    common_directory TEXT,
                    remote_slug TEXT,
                    created_at_seconds REAL NOT NULL,
                    updated_at_seconds REAL NOT NULL
                )
                """,
                """
                CREATE INDEX provenance_repositories_path_index
                ON provenance_repositories (path)
                """,
                """
                CREATE INDEX provenance_repositories_remote_slug_index
                ON provenance_repositories (remote_slug)
                """,
                """
                CREATE TABLE provenance_worktrees (
                    id TEXT PRIMARY KEY NOT NULL,
                    repository_id TEXT NOT NULL,
                    path TEXT NOT NULL,
                    branch TEXT,
                    base_commit TEXT,
                    current_head TEXT,
                    is_dirty INTEGER NOT NULL,
                    status TEXT NOT NULL,
                    last_reconciled_at_seconds REAL,
                    updated_at_seconds REAL NOT NULL
                )
                """,
                """
                CREATE INDEX provenance_worktrees_repository_index
                ON provenance_worktrees (repository_id, updated_at_seconds)
                """,
                """
                CREATE INDEX provenance_worktrees_path_index
                ON provenance_worktrees (path, updated_at_seconds)
                """,
            ]
        ),
        ProvenanceSQLiteMigration(
            version: 4,
            statements: [
                """
                CREATE TABLE provenance_session_relationships (
                    session_id TEXT PRIMARY KEY NOT NULL,
                    parent_session_id TEXT NOT NULL,
                    root_session_id TEXT NOT NULL,
                    inbound_delegation_id TEXT,
                    depth INTEGER NOT NULL,
                    source TEXT NOT NULL,
                    confidence TEXT NOT NULL,
                    created_at_seconds REAL NOT NULL,
                    updated_at_seconds REAL NOT NULL
                )
                """,
                """
                CREATE INDEX provenance_session_relationships_parent_index
                ON provenance_session_relationships (parent_session_id, depth, updated_at_seconds)
                """,
                """
                CREATE INDEX provenance_session_relationships_root_index
                ON provenance_session_relationships (root_session_id, depth, updated_at_seconds)
                """,
                """
                CREATE TABLE provenance_session_external_identities (
                    id TEXT PRIMARY KEY NOT NULL,
                    session_id TEXT NOT NULL,
                    system TEXT NOT NULL,
                    kind TEXT NOT NULL,
                    external_id TEXT NOT NULL,
                    source TEXT NOT NULL,
                    confidence TEXT NOT NULL,
                    created_at_seconds REAL NOT NULL,
                    updated_at_seconds REAL NOT NULL
                )
                """,
                """
                CREATE UNIQUE INDEX provenance_session_external_identities_unique_index
                ON provenance_session_external_identities (system, kind, external_id)
                """,
                """
                CREATE INDEX provenance_session_external_identities_session_index
                ON provenance_session_external_identities (session_id, system, kind)
                """,
            ]
        ),
        ProvenanceSQLiteMigration(
            version: 5,
            statements: [
                """
                CREATE TABLE provenance_work_items (
                    id TEXT PRIMARY KEY NOT NULL,
                    title TEXT NOT NULL,
                    status TEXT NOT NULL,
                    created_at_seconds REAL NOT NULL,
                    updated_at_seconds REAL NOT NULL
                )
                """,
                """
                CREATE INDEX provenance_work_items_status_index
                ON provenance_work_items (status, updated_at_seconds)
                """,
                """
                CREATE TABLE provenance_work_contributions (
                    id TEXT PRIMARY KEY NOT NULL,
                    session_id TEXT NOT NULL,
                    worktree_id TEXT NOT NULL,
                    work_item_id TEXT NOT NULL,
                    declared_intent TEXT,
                    expected_scope_json TEXT NOT NULL,
                    status TEXT NOT NULL,
                    started_at_seconds REAL NOT NULL,
                    ended_at_seconds REAL,
                    assignment_confidence TEXT NOT NULL,
                    updated_at_seconds REAL NOT NULL
                )
                """,
                """
                CREATE INDEX provenance_work_contributions_session_index
                ON provenance_work_contributions (session_id, worktree_id, updated_at_seconds)
                """,
                """
                CREATE INDEX provenance_work_contributions_work_item_index
                ON provenance_work_contributions (work_item_id, updated_at_seconds)
                """,
                """
                CREATE TABLE provenance_checkpoints (
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
                    created_at_seconds REAL NOT NULL
                )
                """,
                """
                CREATE INDEX provenance_checkpoints_contribution_index
                ON provenance_checkpoints (contribution_id, sequence)
                """,
                """
                CREATE TABLE provenance_change_sets (
                    id TEXT PRIMARY KEY NOT NULL,
                    checkpoint_id TEXT,
                    contribution_id TEXT,
                    worktree_id TEXT NOT NULL,
                    summary TEXT,
                    diff_fingerprint TEXT,
                    created_at_seconds REAL NOT NULL
                )
                """,
                """
                CREATE INDEX provenance_change_sets_worktree_index
                ON provenance_change_sets (worktree_id, created_at_seconds)
                """,
                """
                CREATE INDEX provenance_change_sets_checkpoint_index
                ON provenance_change_sets (checkpoint_id)
                """,
                """
                CREATE TABLE provenance_file_changes (
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
                    updated_at_seconds REAL NOT NULL
                )
                """,
                """
                CREATE INDEX provenance_file_changes_worktree_path_index
                ON provenance_file_changes (worktree_id, path, updated_at_seconds)
                """,
                """
                CREATE INDEX provenance_file_changes_change_set_index
                ON provenance_file_changes (change_set_id)
                """,
            ]
        ),
    ]
}
