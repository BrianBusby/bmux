import Foundation
import ProvenanceEngineContracts

/// Internal repository actor that owns one migrated SQLite database connection.
actor ProvenanceSQLiteRepository {
    private let database: ProvenanceSQLiteDatabase
    private let payloadEncoder: JSONEncoder
    private let payloadDecoder: JSONDecoder
    private let stableIDFactory: ProvenanceStableIDFactory

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
        self.stableIDFactory = ProvenanceStableIDFactory()
    }

    /// Opens the database at an engine-owned storage location and applies migrations.
    ///
    /// - Parameters:
    ///   - storageLocation: Engine-owned SQLite storage location.
    ///   - migrations: Ordered migration steps supported by this repository.
    ///   - fileManager: Filesystem dependency used by the SQLite connection.
    /// - Throws: ``ProvenanceSQLiteError`` or filesystem errors when opening or migrating fails.
    init(
        storageLocation: ProvenanceSQLiteStorageLocation = ProvenanceSQLiteStorageLocation(),
        migrations: [ProvenanceSQLiteMigration] = ProvenanceSQLiteRepository.migrations,
        fileManager: FileManager = .default
    ) throws {
        try self.init(
            url: storageLocation.databaseURL,
            migrations: migrations,
            fileManager: fileManager
        )
    }

    /// Current migrated schema version recorded in SQLite `PRAGMA user_version`.
    func schemaVersion() throws -> Int32 {
        try database.userVersion
    }

    /// Reads internal storage counts for the event ledger and current-state projection tables.
    ///
    /// - Returns: A bounded summary of repository-owned SQLite storage state.
    /// - Throws: ``ProvenanceSQLiteError`` when SQLite rejects one of the reads.
    func storageSummary() throws -> ProvenanceSQLiteStorageSummary {
        let ledgerSummary = try eventLedgerSummary()
        return ProvenanceSQLiteStorageSummary(
            schemaVersion: try schemaVersion(),
            eventCount: ledgerSummary.count,
            latestEventSequence: ledgerSummary.latestSequence,
            repositoryCount: try countRows(in: "provenance_repositories"),
            worktreeCount: try countRows(in: "provenance_worktrees"),
            sessionCount: try countRows(in: "provenance_sessions"),
            sessionRelationshipCount: try countRows(in: "provenance_session_relationships"),
            externalIdentityCount: try countRows(in: "provenance_session_external_identities"),
            workItemCount: try countRows(in: "provenance_work_items"),
            contributionCount: try countRows(in: "provenance_work_contributions"),
            checkpointCount: try countRows(in: "provenance_checkpoints"),
            changeSetCount: try countRows(in: "provenance_change_sets"),
            fileChangeCount: try countRows(in: "provenance_file_changes"),
            validationRunCount: try countRows(in: "provenance_validation_runs")
        )
    }

    /// Appends one immutable provenance event to the internal ledger.
    ///
    /// - Parameter event: Contract event to persist.
    /// - Throws: ``ProvenanceSQLiteError`` when SQLite rejects the write, including duplicate IDs.
    func appendEvent(_ event: ProvenanceEvent) throws {
        try database.execute("BEGIN IMMEDIATE TRANSACTION")
        do {
            try insertEvent(event)
            try applyProjectionUpdates(from: event.payload)
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

        return try event(from: query, id: id)
    }

    /// Reads bounded event-ledger entries after an optional append sequence cursor.
    ///
    /// - Parameters:
    ///   - afterSequence: Exclusive SQLite append sequence cursor, or `nil` to read from the beginning.
    ///   - limit: Maximum number of ledger entries to return.
    /// - Returns: Ledger entries in append order.
    /// - Throws: ``ProvenanceSQLiteError`` when SQLite rejects the read or stored enum data is invalid.
    func eventLedgerEntries(afterSequence: Int? = nil, limit: Int) throws -> [ProvenanceEventLedgerEntry] {
        let rowLimit = max(0, limit)
        var sql = """
            SELECT
                sequence,
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
            FROM provenance_events
            """
        if afterSequence != nil {
            sql += "\nWHERE sequence > ?"
        }
        sql += "\nORDER BY sequence ASC\nLIMIT ?"

        let query = try database.prepare(sql)
        defer { query.finalize() }

        var bindIndex: Int32 = 1
        if let afterSequence {
            try query.bind(afterSequence, at: bindIndex)
            bindIndex += 1
        }
        try query.bind(rowLimit, at: bindIndex)

        var entries: [ProvenanceEventLedgerEntry] = []
        while try query.step() {
            guard let id = query.string(at: 1) else {
                throw ProvenanceSQLiteError.sqlite(message: "stored event has invalid id")
            }
            entries.append(
                ProvenanceEventLedgerEntry(
                    sequence: query.int(at: 0),
                    event: try event(from: query, id: id, offset: 2)
                )
            )
        }
        return entries
    }

    /// Validates bounded event-ledger rows through the same decoder used by ledger reads.
    ///
    /// - Parameter limit: Maximum number of append-order ledger rows to validate.
    /// - Returns: Validation counts and the first invalid row, if any.
    /// - Throws: ``ProvenanceSQLiteError`` when SQLite rejects the bounded ledger scan.
    func validateEventLedger(limit: Int = 1_000) throws -> ProvenanceSQLiteLedgerValidationReport {
        let rowLimit = max(0, limit)
        let ledgerSummary = try eventLedgerSummary()
        let query = try database.prepare(
            """
            SELECT
                sequence,
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
            FROM provenance_events
            ORDER BY sequence ASC
            LIMIT ?
            """
        )
        defer { query.finalize() }

        try query.bind(rowLimit, at: 1)
        var checkedEventCount = 0
        var invalidEventCount = 0
        var latestCheckedSequence: Int?
        var firstInvalidIssue: ProvenanceSQLiteLedgerValidationIssue?

        while try query.step() {
            let sequence = query.int(at: 0)
            let id = query.string(at: 1)
            checkedEventCount += 1
            latestCheckedSequence = sequence

            guard let id else {
                invalidEventCount += 1
                if firstInvalidIssue == nil {
                    firstInvalidIssue = ProvenanceSQLiteLedgerValidationIssue(
                        sequence: sequence,
                        eventID: nil,
                        errorDescription: "stored event has invalid id"
                    )
                }
                continue
            }

            do {
                _ = try event(from: query, id: id, offset: 2)
            } catch {
                invalidEventCount += 1
                if firstInvalidIssue == nil {
                    firstInvalidIssue = ProvenanceSQLiteLedgerValidationIssue(
                        sequence: sequence,
                        eventID: id,
                        errorDescription: boundedErrorSummary(error)
                    )
                }
            }
        }

        return ProvenanceSQLiteLedgerValidationReport(
            checkedEventCount: checkedEventCount,
            invalidEventCount: invalidEventCount,
            latestCheckedSequence: latestCheckedSequence,
            firstInvalidIssue: firstInvalidIssue,
            truncated: ledgerSummary.count > rowLimit
        )
    }

    /// Validates current-state projection counts against bounded append-order ledger replay.
    ///
    /// - Parameter limit: Maximum number of append-order ledger rows to decode.
    /// - Returns: Checked ledger row metadata and projection count mismatches when the scan is complete.
    /// - Throws: ``ProvenanceSQLiteError`` when SQLite rejects a read or stored enum data is invalid.
    func validateProjectionCounts(limit: Int = 1_000) throws -> ProvenanceSQLiteProjectionValidationReport {
        let rowLimit = max(0, limit)
        let ledgerSummary = try eventLedgerSummary()
        let entries = try eventLedgerEntries(limit: rowLimit)
        let truncated = ledgerSummary.count > rowLimit

        guard !truncated else {
            return ProvenanceSQLiteProjectionValidationReport(
                checkedEventCount: entries.count,
                latestCheckedSequence: entries.last?.sequence,
                truncated: true,
                comparedProjectionCounts: false,
                mismatches: []
            )
        }

        let expectedCounts = projectionCounts(from: entries.map(\.event.payload))
        return ProvenanceSQLiteProjectionValidationReport(
            checkedEventCount: entries.count,
            latestCheckedSequence: entries.last?.sequence,
            truncated: false,
            comparedProjectionCounts: true,
            mismatches: try projectionCountMismatches(expected: expectedCounts)
        )
    }

    /// Rebuilds current-state projections by replaying the immutable event ledger in append order.
    ///
    /// - Parameter batchSize: Maximum number of ledger entries decoded per cursor read.
    /// - Returns: Number of ledger events replayed into projection tables.
    /// - Throws: ``ProvenanceSQLiteError`` when SQLite rejects the rebuild or stored enum data is invalid.
    func rebuildProjectionsFromEventLedger(batchSize: Int = 1_000) throws -> Int {
        let rowLimit = max(1, batchSize)
        var afterSequence: Int?
        var replayedCount = 0

        try database.execute("BEGIN IMMEDIATE TRANSACTION")
        do {
            try clearProjectionTables()
            while true {
                let entries = try eventLedgerEntries(afterSequence: afterSequence, limit: rowLimit)
                guard !entries.isEmpty else { break }

                for entry in entries {
                    try applyProjectionUpdates(from: entry.event.payload)
                    afterSequence = entry.sequence
                    replayedCount += 1
                }

                guard entries.count == rowLimit else { break }
            }
            try database.execute("COMMIT")
        } catch {
            try? database.execute("ROLLBACK")
            throw error
        }

        return replayedCount
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

        func hasCapacity(for additionalRows: Int = 1) -> Bool {
            rowLimit.map { sessions.count + relationships.count + additionalRows <= $0 } ?? true
        }

        func visit(_ sessionID: String, treeDepth: Int) throws {
            guard treeDepth <= 50, !visitedSessionIDs.contains(sessionID) else { return }
            guard hasCapacity(), let session = try session(id: sessionID) else { return }
            visitedSessionIDs.insert(sessionID)
            sessions.append(session)
            guard treeDepth < 50 else { return }

            for relationship in try childSessionRelationships(parentSessionID: sessionID) {
                guard !visitedSessionIDs.contains(relationship.sessionID) else { continue }
                guard hasCapacity(for: 2) else { break }

                let relationshipIndex = relationships.count
                let sessionCountBeforeVisit = sessions.count
                relationships.append(relationship)
                try visit(relationship.sessionID, treeDepth: treeDepth + 1)
                if sessions.count == sessionCountBeforeVisit {
                    relationships.remove(at: relationshipIndex)
                }
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

    /// Reads bounded current provenance context for one worktree path.
    ///
    /// - Parameter request: Current-context query parameters.
    /// - Returns: Found response with bounded linked projections, or `no_worktree` when no worktree matches.
    /// - Throws: ``ProvenanceSQLiteError`` when SQLite rejects the read.
    func currentContext(_ request: ProvenanceCurrentContextRequest) throws -> ProvenanceCurrentContextResponse {
        guard let worktree = try worktree(path: request.repositoryPath) else {
            return ProvenanceCurrentContextResponse(
                found: false,
                reason: "no_worktree",
                repositoryPath: request.repositoryPath,
                worktree: nil,
                repository: nil,
                activeSessions: [],
                dirtyFiles: [],
                unattributedChanges: [],
                recentCheckpoints: [],
                validationRuns: [],
                conflicts: []
            )
        }

        return ProvenanceCurrentContextResponse(
            found: true,
            repositoryPath: request.repositoryPath,
            worktree: worktree,
            repository: try repository(id: worktree.repositoryID),
            activeSessions: try currentContextActiveSessions(
                worktreeID: worktree.id,
                limit: request.activeSessionLimit
            ),
            dirtyFiles: try currentContextFileChanges(
                worktreeID: worktree.id,
                unattributedOnly: false,
                limit: request.dirtyFileLimit
            ),
            unattributedChanges: try currentContextFileChanges(
                worktreeID: worktree.id,
                unattributedOnly: true,
                limit: request.unattributedChangeLimit
            ),
            recentCheckpoints: try currentContextCheckpoints(
                worktreeID: worktree.id,
                limit: request.recentCheckpointLimit
            ),
            validationRuns: try currentContextValidationRuns(
                worktreeID: worktree.id,
                limit: request.validationRunLimit
            ),
            conflicts: try currentContextConflicts(
                worktreeID: worktree.id,
                limit: request.conflictLimit
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

    private func eventLedgerSummary() throws -> (count: Int, latestSequence: Int?) {
        let query = try database.prepare("SELECT COUNT(*), MAX(sequence) FROM provenance_events")
        defer { query.finalize() }
        guard try query.step() else { return (0, nil) }
        let latestSequence = query.double(at: 1).map(Int.init)
        return (query.int(at: 0), latestSequence)
    }

    private func projectionCounts(from payloads: [ProvenanceEventPayload]) -> [String: Int] {
        var repositories = Set<String>()
        var worktrees = Set<String>()
        var sessions = Set<String>()
        var sessionRelationships = Set<String>()
        var externalIdentities = Set<String>()
        var workItems = Set<String>()
        var contributions = Set<String>()
        var checkpoints = Set<String>()
        var changeSets = Set<String>()
        var fileChanges = Set<String>()
        var validationRuns = Set<String>()

        for payload in payloads {
            if let repository = payload.repository {
                repositories.insert(repository.id)
            }
            if let worktree = payload.worktree {
                worktrees.insert(worktree.id)
            }
            if let session = payload.session {
                sessions.insert(session.id)
            }
            if let relationship = payload.sessionRelationship {
                sessionRelationships.insert(relationship.sessionID)
            }
            for identity in payload.externalIdentities {
                externalIdentities.insert("\(identity.system)\u{0}\(identity.kind)\u{0}\(identity.externalID)")
            }
            if let workItem = payload.workItem {
                workItems.insert(workItem.id)
            }
            if let contribution = payload.contribution {
                contributions.insert(contribution.id)
            }
            if let checkpoint = payload.checkpoint {
                checkpoints.insert(checkpoint.id)
            }
            if let changeSet = payload.changeSet {
                changeSets.insert(changeSet.id)
            }
            for fileChange in payload.fileChanges {
                fileChanges.insert(fileChange.id)
            }
            if let validationRun = payload.validationRun {
                validationRuns.insert(validationRun.id)
            }
        }

        return [
            "provenance_repositories": repositories.count,
            "provenance_worktrees": worktrees.count,
            "provenance_sessions": sessions.count,
            "provenance_session_relationships": sessionRelationships.count,
            "provenance_session_external_identities": externalIdentities.count,
            "provenance_work_items": workItems.count,
            "provenance_work_contributions": contributions.count,
            "provenance_checkpoints": checkpoints.count,
            "provenance_change_sets": changeSets.count,
            "provenance_file_changes": fileChanges.count,
            "provenance_validation_runs": validationRuns.count,
        ]
    }

    private func projectionCountMismatches(
        expected: [String: Int]
    ) throws -> [ProvenanceSQLiteProjectionValidationMismatch] {
        var mismatches: [ProvenanceSQLiteProjectionValidationMismatch] = []
        for tableName in [
            "provenance_repositories",
            "provenance_worktrees",
            "provenance_sessions",
            "provenance_session_relationships",
            "provenance_session_external_identities",
            "provenance_work_items",
            "provenance_work_contributions",
            "provenance_checkpoints",
            "provenance_change_sets",
            "provenance_file_changes",
            "provenance_validation_runs",
        ] {
            let expectedCount = expected[tableName] ?? 0
            let actualCount = try countRows(in: tableName)
            if expectedCount != actualCount {
                mismatches.append(
                    ProvenanceSQLiteProjectionValidationMismatch(
                        tableName: tableName,
                        expectedCount: expectedCount,
                        actualCount: actualCount
                    )
                )
            }
        }
        return mismatches
    }

    private func countRows(in tableName: String) throws -> Int {
        let query = try database.prepare("SELECT COUNT(*) FROM \(tableName)")
        defer { query.finalize() }
        guard try query.step() else { return 0 }
        return query.int(at: 0)
    }

    private func event(
        from query: ProvenanceSQLiteStatement,
        id: String,
        offset: Int32 = 0
    ) throws -> ProvenanceEvent {
        let eventType = ProvenanceEventType(rawValue: query.string(at: offset + 1) ?? "")
        guard let sourceRawValue = query.string(at: offset + 7),
              let source = ProvenanceSource(rawValue: sourceRawValue) else {
            throw ProvenanceSQLiteError.sqlite(message: "stored event has invalid source")
        }
        guard let confidenceRawValue = query.string(at: offset + 8),
              let confidence = ProvenanceConfidence(rawValue: confidenceRawValue) else {
            throw ProvenanceSQLiteError.sqlite(message: "stored event has invalid confidence")
        }
        guard let payloadJSON = query.string(at: offset + 9),
              let payloadData = payloadJSON.data(using: .utf8) else {
            throw ProvenanceSQLiteError.sqlite(message: "stored event has invalid payload")
        }

        let payload = try payloadDecoder.decode(ProvenanceEventPayload.self, from: payloadData)
        return ProvenanceEvent(
            id: id,
            schemaVersion: query.int(at: offset),
            eventType: eventType,
            timestamp: Date(timeIntervalSince1970: query.double(at: offset + 2) ?? 0),
            repositoryID: query.string(at: offset + 3),
            worktreeID: query.string(at: offset + 4),
            sessionID: query.string(at: offset + 5),
            contributionID: query.string(at: offset + 6),
            source: source,
            confidence: confidence,
            payload: payload
        )
    }

    private func worktree(path: String) throws -> ProvenanceWorktreeRecord? {
        let query = try database.prepare(
            """
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
            WHERE path = ?
            ORDER BY updated_at_seconds DESC, rowid DESC
            LIMIT 1
            """
        )
        defer { query.finalize() }

        try query.bind(path, at: 1)
        guard try query.step() else { return nil }
        return worktree(from: query)
    }

    private func currentContextFileChanges(
        worktreeID: String,
        unattributedOnly: Bool,
        limit: Int
    ) throws -> [ProvenanceCurrentContextFileChange] {
        let sourceFilter = unattributedOnly ? "AND fc.attribution_source = 'unattributed'" : ""
        let query = try database.prepare(
            """
            SELECT
                fc.id,
                fc.change_set_id,
                fc.repository_id,
                fc.worktree_id,
                fc.path,
                fc.status,
                fc.before_hash,
                fc.after_hash,
                fc.attribution_source,
                fc.attribution_confidence,
                fc.updated_at_seconds,
                cs.id,
                cs.checkpoint_id,
                cs.contribution_id,
                cs.worktree_id,
                cs.summary,
                cs.diff_fingerprint,
                cs.created_at_seconds,
                wc.id,
                wc.session_id,
                wc.worktree_id,
                wc.work_item_id,
                wc.declared_intent,
                wc.expected_scope_json,
                wc.status,
                wc.started_at_seconds,
                wc.ended_at_seconds,
                wc.assignment_confidence,
                wc.updated_at_seconds,
                s.id,
                s.agent_kind,
                s.workspace_id,
                s.surface_id,
                s.worktree_id,
                s.cwd,
                s.status,
                s.started_at_seconds,
                s.updated_at_seconds
            FROM provenance_file_changes fc
            LEFT JOIN provenance_change_sets cs ON cs.id = fc.change_set_id
            LEFT JOIN provenance_checkpoints cp ON cp.id = cs.checkpoint_id
            LEFT JOIN provenance_work_contributions wc ON wc.id = COALESCE(cs.contribution_id, cp.contribution_id)
            LEFT JOIN provenance_sessions s ON s.id = wc.session_id
            WHERE fc.worktree_id = ?
              \(sourceFilter)
              AND fc.rowid = (
                  SELECT newest.rowid
                  FROM provenance_file_changes newest
                  WHERE newest.worktree_id = fc.worktree_id
                    AND newest.path = fc.path
                  ORDER BY newest.updated_at_seconds DESC, newest.rowid DESC
                  LIMIT 1
              )
            ORDER BY fc.updated_at_seconds DESC, fc.rowid DESC
            LIMIT ?
            """
        )
        defer { query.finalize() }

        try query.bind(worktreeID, at: 1)
        try query.bind(max(0, limit), at: 2)

        var rows: [ProvenanceCurrentContextFileChange] = []
        while try query.step() {
            guard let fileChange = fileChange(from: query, offset: 0) else { continue }
            rows.append(
                ProvenanceCurrentContextFileChange(
                    fileChange: fileChange,
                    changeSet: changeSet(from: query, offset: 11),
                    contribution: contribution(from: query, offset: 18),
                    session: session(from: query, offset: 29)
                )
            )
        }
        return rows
    }

    private func currentContextActiveSessions(
        worktreeID: String,
        limit: Int
    ) throws -> [ProvenanceCurrentContextSession] {
        let query = try database.prepare(
            """
            SELECT
                s.id,
                s.agent_kind,
                s.workspace_id,
                s.surface_id,
                s.worktree_id,
                s.cwd,
                s.status,
                s.started_at_seconds,
                s.updated_at_seconds,
                wc.id,
                wc.session_id,
                wc.worktree_id,
                wc.work_item_id,
                wc.declared_intent,
                wc.expected_scope_json,
                wc.status,
                wc.started_at_seconds,
                wc.ended_at_seconds,
                wc.assignment_confidence,
                wc.updated_at_seconds,
                wi.id,
                wi.title,
                wi.status,
                wi.created_at_seconds,
                wi.updated_at_seconds
            FROM provenance_sessions s
            LEFT JOIN provenance_work_contributions wc
              ON wc.session_id = s.id
             AND wc.worktree_id = s.worktree_id
             AND LOWER(COALESCE(wc.status, '')) NOT IN (
                'complete', 'completed', 'finished', 'interrupted', 'cancelled', 'canceled', 'closed', 'stopped'
             )
            LEFT JOIN provenance_work_items wi ON wi.id = wc.work_item_id
            WHERE s.worktree_id = ?
              AND LOWER(COALESCE(s.status, '')) NOT IN (
                'complete', 'completed', 'finished', 'interrupted', 'cancelled', 'canceled', 'closed', 'stopped'
              )
            ORDER BY s.updated_at_seconds DESC, s.rowid DESC
            LIMIT ?
            """
        )
        defer { query.finalize() }

        try query.bind(worktreeID, at: 1)
        try query.bind(max(0, limit), at: 2)

        var rows: [ProvenanceCurrentContextSession] = []
        while try query.step() {
            guard let session = session(from: query, offset: 0) else { continue }
            rows.append(
                ProvenanceCurrentContextSession(
                    session: session,
                    contribution: contribution(from: query, offset: 9),
                    workItem: workItem(from: query, offset: 20)
                )
            )
        }
        return rows
    }

    private func currentContextCheckpoints(
        worktreeID: String,
        limit: Int
    ) throws -> [ProvenanceCurrentContextCheckpoint] {
        let query = try database.prepare(
            """
            SELECT
                cp.id,
                cp.contribution_id,
                cp.sequence,
                cp.git_head,
                cp.diff_fingerprint,
                cp.summary,
                cp.status,
                cp.validation_state,
                cp.semantic_confidence,
                cp.freshness,
                cp.created_at_seconds,
                wc.id,
                wc.session_id,
                wc.worktree_id,
                wc.work_item_id,
                wc.declared_intent,
                wc.expected_scope_json,
                wc.status,
                wc.started_at_seconds,
                wc.ended_at_seconds,
                wc.assignment_confidence,
                wc.updated_at_seconds,
                s.id,
                s.agent_kind,
                s.workspace_id,
                s.surface_id,
                s.worktree_id,
                s.cwd,
                s.status,
                s.started_at_seconds,
                s.updated_at_seconds,
                wi.id,
                wi.title,
                wi.status,
                wi.created_at_seconds,
                wi.updated_at_seconds
            FROM provenance_checkpoints cp
            JOIN provenance_work_contributions wc ON wc.id = cp.contribution_id
            LEFT JOIN provenance_sessions s ON s.id = wc.session_id
            LEFT JOIN provenance_work_items wi ON wi.id = wc.work_item_id
            WHERE wc.worktree_id = ?
            ORDER BY cp.created_at_seconds DESC, cp.rowid DESC
            LIMIT ?
            """
        )
        defer { query.finalize() }

        try query.bind(worktreeID, at: 1)
        try query.bind(max(0, limit), at: 2)

        var rows: [ProvenanceCurrentContextCheckpoint] = []
        while try query.step() {
            guard let checkpoint = checkpoint(from: query, offset: 0),
                  let contribution = contribution(from: query, offset: 11) else {
                continue
            }
            rows.append(
                ProvenanceCurrentContextCheckpoint(
                    checkpoint: checkpoint,
                    contribution: contribution,
                    session: session(from: query, offset: 22),
                    workItem: workItem(from: query, offset: 31)
                )
            )
        }
        return rows
    }

    private func currentContextValidationRuns(
        worktreeID: String,
        limit: Int
    ) throws -> [ProvenanceCurrentContextValidationRun] {
        let query = try database.prepare(
            """
            SELECT
                vr.id,
                vr.checkpoint_id,
                vr.contribution_id,
                vr.command,
                vr.status,
                vr.summary,
                vr.started_at_seconds,
                vr.ended_at_seconds,
                cp.id,
                cp.contribution_id,
                cp.sequence,
                cp.git_head,
                cp.diff_fingerprint,
                cp.summary,
                cp.status,
                cp.validation_state,
                cp.semantic_confidence,
                cp.freshness,
                cp.created_at_seconds,
                wc.id,
                wc.session_id,
                wc.worktree_id,
                wc.work_item_id,
                wc.declared_intent,
                wc.expected_scope_json,
                wc.status,
                wc.started_at_seconds,
                wc.ended_at_seconds,
                wc.assignment_confidence,
                wc.updated_at_seconds
            FROM provenance_validation_runs vr
            LEFT JOIN provenance_checkpoints cp ON cp.id = vr.checkpoint_id
            LEFT JOIN provenance_work_contributions wc ON wc.id = COALESCE(vr.contribution_id, cp.contribution_id)
            WHERE wc.worktree_id = ?
            ORDER BY COALESCE(vr.ended_at_seconds, vr.started_at_seconds, 0) DESC, vr.rowid DESC
            LIMIT ?
            """
        )
        defer { query.finalize() }

        try query.bind(worktreeID, at: 1)
        try query.bind(max(0, limit), at: 2)

        var rows: [ProvenanceCurrentContextValidationRun] = []
        while try query.step() {
            guard let validationRun = validationRun(from: query, offset: 0) else { continue }
            rows.append(
                ProvenanceCurrentContextValidationRun(
                    validationRun: validationRun,
                    checkpoint: checkpoint(from: query, offset: 8),
                    contribution: contribution(from: query, offset: 19)
                )
            )
        }
        return rows
    }

    private func currentContextConflicts(
        worktreeID: String,
        limit: Int
    ) throws -> [ProvenanceCurrentContextConflict] {
        let query = try database.prepare(
            """
            SELECT
                fc.path,
                COUNT(DISTINCT wc.id),
                GROUP_CONCAT(DISTINCT wc.id),
                MAX(fc.updated_at_seconds)
            FROM provenance_file_changes fc
            LEFT JOIN provenance_change_sets cs ON cs.id = fc.change_set_id
            LEFT JOIN provenance_checkpoints cp ON cp.id = cs.checkpoint_id
            JOIN provenance_work_contributions wc ON wc.id = COALESCE(cs.contribution_id, cp.contribution_id)
            WHERE fc.worktree_id = ?
              AND LOWER(COALESCE(wc.status, '')) NOT IN (
                'complete', 'completed', 'finished', 'interrupted', 'cancelled', 'canceled', 'closed', 'stopped'
              )
            GROUP BY fc.path
            HAVING COUNT(DISTINCT wc.id) > 1
            ORDER BY MAX(fc.updated_at_seconds) DESC
            LIMIT ?
            """
        )
        defer { query.finalize() }

        try query.bind(worktreeID, at: 1)
        try query.bind(max(0, limit), at: 2)

        var rows: [ProvenanceCurrentContextConflict] = []
        while try query.step() {
            guard let path = query.string(at: 0) else { continue }
            rows.append(
                ProvenanceCurrentContextConflict(
                    path: path,
                    activeContributionCount: query.int(at: 1),
                    contributionIDs: query.string(at: 2),
                    updatedAt: Date(timeIntervalSince1970: query.double(at: 3) ?? 0)
                )
            )
        }
        return rows
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
        parentSessionID: String,
        limit: Int? = nil
    ) throws -> [ProvenanceSessionRelationshipRecord] {
        var sql = """
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
        if limit != nil {
            sql += "\nLIMIT ?"
        }

        let query = try database.prepare(sql)
        defer { query.finalize() }

        try query.bind(parentSessionID, at: 1)
        if let limit {
            try query.bind(max(0, limit), at: 2)
        }
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

    private func session(
        from query: ProvenanceSQLiteStatement,
        offset: Int32
    ) -> ProvenanceSessionRecord? {
        guard let id = query.string(at: offset),
              let agentKind = query.string(at: offset + 1),
              let status = query.string(at: offset + 6) else {
            return nil
        }

        return ProvenanceSessionRecord(
            id: id,
            agentKind: agentKind,
            workspaceID: query.string(at: offset + 2),
            surfaceID: query.string(at: offset + 3),
            worktreeID: query.string(at: offset + 4),
            cwd: query.string(at: offset + 5),
            status: status,
            startedAt: query.double(at: offset + 7).map { Date(timeIntervalSince1970: $0) },
            updatedAt: Date(timeIntervalSince1970: query.double(at: offset + 8) ?? 0)
        )
    }

    private func contribution(
        from query: ProvenanceSQLiteStatement,
        offset: Int32
    ) -> ProvenanceContributionRecord? {
        guard let id = query.string(at: offset),
              let sessionID = query.string(at: offset + 1),
              let worktreeID = query.string(at: offset + 2),
              let workItemID = query.string(at: offset + 3),
              let expectedScopeJSON = query.string(at: offset + 5),
              let expectedScopeData = expectedScopeJSON.data(using: .utf8),
              let status = query.string(at: offset + 6),
              let confidenceRawValue = query.string(at: offset + 9),
              let confidence = ProvenanceConfidence(rawValue: confidenceRawValue) else {
            return nil
        }

        let expectedScope = (try? payloadDecoder.decode([String].self, from: expectedScopeData)) ?? []
        return ProvenanceContributionRecord(
            id: id,
            sessionID: sessionID,
            worktreeID: worktreeID,
            workItemID: workItemID,
            declaredIntent: query.string(at: offset + 4),
            expectedScope: expectedScope,
            status: status,
            startedAt: Date(timeIntervalSince1970: query.double(at: offset + 7) ?? 0),
            endedAt: query.double(at: offset + 8).map { Date(timeIntervalSince1970: $0) },
            assignmentConfidence: confidence,
            updatedAt: Date(timeIntervalSince1970: query.double(at: offset + 10) ?? 0)
        )
    }

    private func workItem(
        from query: ProvenanceSQLiteStatement,
        offset: Int32
    ) -> ProvenanceWorkItemRecord? {
        guard let id = query.string(at: offset),
              let title = query.string(at: offset + 1),
              let status = query.string(at: offset + 2) else {
            return nil
        }

        return ProvenanceWorkItemRecord(
            id: id,
            title: title,
            status: status,
            createdAt: Date(timeIntervalSince1970: query.double(at: offset + 3) ?? 0),
            updatedAt: Date(timeIntervalSince1970: query.double(at: offset + 4) ?? 0)
        )
    }

    private func changeSet(
        from query: ProvenanceSQLiteStatement,
        offset: Int32
    ) -> ProvenanceChangeSetRecord? {
        guard let id = query.string(at: offset),
              let worktreeID = query.string(at: offset + 3) else {
            return nil
        }

        return ProvenanceChangeSetRecord(
            id: id,
            checkpointID: query.string(at: offset + 1),
            contributionID: query.string(at: offset + 2),
            worktreeID: worktreeID,
            summary: query.string(at: offset + 4),
            diffFingerprint: query.string(at: offset + 5),
            createdAt: Date(timeIntervalSince1970: query.double(at: offset + 6) ?? 0)
        )
    }

    private func checkpoint(
        from query: ProvenanceSQLiteStatement,
        offset: Int32
    ) -> ProvenanceCheckpointRecord? {
        guard let id = query.string(at: offset),
              let contributionID = query.string(at: offset + 1),
              let status = query.string(at: offset + 6),
              let confidenceRawValue = query.string(at: offset + 8),
              let confidence = ProvenanceConfidence(rawValue: confidenceRawValue),
              let freshness = query.string(at: offset + 9) else {
            return nil
        }

        return ProvenanceCheckpointRecord(
            id: id,
            contributionID: contributionID,
            sequence: query.int(at: offset + 2),
            gitHEAD: query.string(at: offset + 3),
            diffFingerprint: query.string(at: offset + 4),
            summary: query.string(at: offset + 5),
            status: status,
            validationState: query.string(at: offset + 7),
            semanticConfidence: confidence,
            freshness: freshness,
            createdAt: Date(timeIntervalSince1970: query.double(at: offset + 10) ?? 0)
        )
    }

    private func validationRun(
        from query: ProvenanceSQLiteStatement,
        offset: Int32
    ) -> ProvenanceValidationRunRecord? {
        guard let id = query.string(at: offset),
              let command = query.string(at: offset + 3),
              let status = query.string(at: offset + 4) else {
            return nil
        }

        return ProvenanceValidationRunRecord(
            id: id,
            checkpointID: query.string(at: offset + 1),
            contributionID: query.string(at: offset + 2),
            command: command,
            status: status,
            summary: query.string(at: offset + 5),
            startedAt: query.double(at: offset + 6).map { Date(timeIntervalSince1970: $0) },
            endedAt: query.double(at: offset + 7).map { Date(timeIntervalSince1970: $0) }
        )
    }

    private func fileChange(
        from query: ProvenanceSQLiteStatement,
        offset: Int32
    ) -> ProvenanceFileChangeRecord? {
        guard let id = query.string(at: offset),
              let changeSetID = query.string(at: offset + 1),
              let repositoryID = query.string(at: offset + 2),
              let worktreeID = query.string(at: offset + 3),
              let path = query.string(at: offset + 4),
              let status = query.string(at: offset + 5),
              let sourceRawValue = query.string(at: offset + 8),
              let source = ProvenanceSource(rawValue: sourceRawValue),
              let confidenceRawValue = query.string(at: offset + 9),
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
            beforeHash: query.string(at: offset + 6),
            afterHash: query.string(at: offset + 7),
            attributionSource: source,
            attributionConfidence: confidence,
            updatedAt: Date(timeIntervalSince1970: query.double(at: offset + 10) ?? 0)
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

    private func applyProjectionUpdates(from payload: ProvenanceEventPayload) throws {
        if let repository = payload.repository {
            try upsertRepository(repository)
        }
        if let worktree = payload.worktree {
            try upsertWorktree(worktree)
        }
        if let session = payload.session {
            try upsertSession(session)
        }
        if let sessionRelationship = payload.sessionRelationship {
            try upsertSessionRelationship(sessionRelationship)
        }
        for externalIdentity in payload.externalIdentities {
            try upsertExternalIdentity(externalIdentity)
        }
        if let workItem = payload.workItem {
            try upsertWorkItem(workItem)
        }
        if let contribution = payload.contribution {
            try upsertContribution(contribution)
        }
        if let checkpoint = payload.checkpoint {
            try upsertCheckpoint(checkpoint)
        }
        if let changeSet = payload.changeSet {
            try upsertChangeSet(changeSet)
        }
        for fileChange in payload.fileChanges {
            try upsertFileChange(fileChange)
        }
        if let validationRun = payload.validationRun {
            try upsertValidationRun(validationRun)
        }
    }

    private func clearProjectionTables() throws {
        for tableName in [
            "provenance_validation_runs",
            "provenance_file_changes",
            "provenance_change_sets",
            "provenance_checkpoints",
            "provenance_work_contributions",
            "provenance_work_items",
            "provenance_session_external_identities",
            "provenance_session_relationships",
            "provenance_sessions",
            "provenance_worktrees",
            "provenance_repositories",
        ] {
            try database.execute("DELETE FROM \(tableName)")
        }
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

    private func upsertValidationRun(_ validationRun: ProvenanceValidationRunRecord) throws {
        let upsert = try database.prepare(
            """
            INSERT INTO provenance_validation_runs (
                id,
                checkpoint_id,
                contribution_id,
                command,
                status,
                summary,
                started_at_seconds,
                ended_at_seconds
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                checkpoint_id = excluded.checkpoint_id,
                contribution_id = excluded.contribution_id,
                command = excluded.command,
                status = excluded.status,
                summary = excluded.summary,
                started_at_seconds = excluded.started_at_seconds,
                ended_at_seconds = excluded.ended_at_seconds
            """
        )
        defer { upsert.finalize() }

        try upsert.bind(validationRun.id, at: 1)
        try upsert.bind(validationRun.checkpointID, at: 2)
        try upsert.bind(validationRun.contributionID, at: 3)
        try upsert.bind(validationRun.command, at: 4)
        try upsert.bind(validationRun.status, at: 5)
        try upsert.bind(validationRun.summary, at: 6)
        try upsert.bind(validationRun.startedAt?.timeIntervalSince1970, at: 7)
        try upsert.bind(validationRun.endedAt?.timeIntervalSince1970, at: 8)

        _ = try upsert.step()
    }

    private func lifecycleIdentity(
        for request: ProvenanceSubsessionLifecycleRequest
    ) -> (
        kind: String,
        value: String,
        confidence: ProvenanceConfidence
    ) {
        let trimmed = request.externalIdentityValue?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmed, !trimmed.isEmpty {
            let identityKind = request.externalIdentityKind?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return (
                kind: identityKind.flatMap { $0.isEmpty ? nil : $0 } ?? "subsession",
                value: trimmed,
                confidence: .high
            )
        }
        return (
            kind: "unresolved_subsession",
            value: "\(request.agentKind):\(request.parentSessionID):default",
            confidence: .low
        )
    }

    private func boundedErrorSummary(_ error: Error) -> String {
        boundedErrorSummary(String(describing: error))
    }

    private func boundedErrorSummary(_ message: String) -> String {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 512 else { return trimmed }
        return String(trimmed.prefix(512))
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
        ProvenanceSQLiteMigration(
            version: 6,
            statements: [
                """
                CREATE TABLE provenance_validation_runs (
                    id TEXT PRIMARY KEY NOT NULL,
                    checkpoint_id TEXT,
                    contribution_id TEXT,
                    command TEXT NOT NULL,
                    status TEXT NOT NULL,
                    summary TEXT,
                    started_at_seconds REAL,
                    ended_at_seconds REAL
                )
                """,
                """
                CREATE INDEX provenance_validation_runs_checkpoint_index
                ON provenance_validation_runs (checkpoint_id)
                """,
                """
                CREATE INDEX provenance_validation_runs_contribution_index
                ON provenance_validation_runs (contribution_id)
                """,
                """
                CREATE INDEX provenance_validation_runs_time_index
                ON provenance_validation_runs (ended_at_seconds, started_at_seconds)
                """,
            ]
        ),
    ]
}

extension ProvenanceSQLiteRepository: ProvenanceSubsessionLifecycleRecording {
    func recordSubsessionLifecycle(
        _ request: ProvenanceSubsessionLifecycleRequest
    ) async -> ProvenanceSubsessionLifecycleResponse {
        var builtEvent: ProvenanceEvent?
        do {
            let event = try await subsessionLifecycleEvent(for: request)
            builtEvent = event
            try appendEvent(event)
            return ProvenanceSubsessionLifecycleResponse(
                accepted: true,
                eventID: event.id,
                childSessionID: event.payload.session?.id,
                relationshipSessionID: event.payload.sessionRelationship?.sessionID,
                externalIdentityID: event.payload.externalIdentities.first?.id
            )
        } catch {
            return ProvenanceSubsessionLifecycleResponse(
                accepted: false,
                eventID: builtEvent?.id,
                childSessionID: builtEvent?.payload.session?.id,
                relationshipSessionID: builtEvent?.payload.sessionRelationship?.sessionID,
                externalIdentityID: builtEvent?.payload.externalIdentities.first?.id,
                errorDescription: boundedErrorSummary(error)
            )
        }
    }

    func subsessionLifecycleEvent(
        for request: ProvenanceSubsessionLifecycleRequest
    ) async throws -> ProvenanceEvent {
        let identity = lifecycleIdentity(for: request)
        let childSessionID = stableIDFactory.subsessionSessionID(
            agentKind: request.agentKind,
            parentSessionID: request.parentSessionID,
            identityKind: identity.kind,
            identityValue: identity.value
        )
        let parentRelationship = try parentSession(for: request.parentSessionID)
        let rootSessionID = parentRelationship?.rootSessionID ?? request.parentSessionID
        let depth = (parentRelationship?.depth ?? 0) + 1
        let existingChildSession = try session(id: childSessionID)
        let status: String
        let eventType: ProvenanceEventType
        let startedAt: Date?
        switch request.phase {
        case .started:
            status = "active"
            eventType = .subsessionStarted
            startedAt = request.timestamp
        case .stopped:
            status = "completed"
            eventType = .subsessionStopped
            startedAt = existingChildSession?.startedAt
        }
        let session = ProvenanceSessionRecord(
            id: childSessionID,
            agentKind: request.agentKind,
            workspaceID: request.workspaceID,
            surfaceID: request.surfaceID,
            cwd: request.workingDirectory,
            status: status,
            startedAt: startedAt,
            updatedAt: request.timestamp
        )
        let relationship = ProvenanceSessionRelationshipRecord(
            sessionID: childSessionID,
            parentSessionID: request.parentSessionID,
            rootSessionID: rootSessionID,
            depth: depth,
            source: .observed,
            confidence: identity.confidence,
            createdAt: request.timestamp,
            updatedAt: request.timestamp
        )
        let externalIdentity = ProvenanceExternalIdentityRecord(
            id: stableIDFactory.externalIdentityID(
                system: request.agentKind,
                kind: identity.kind,
                externalID: identity.value
            ),
            sessionID: childSessionID,
            system: request.agentKind,
            kind: identity.kind,
            externalID: identity.value,
            source: .observed,
            confidence: identity.confidence,
            createdAt: request.timestamp,
            updatedAt: request.timestamp
        )
        return ProvenanceEvent(
            id: stableIDFactory.subsessionLifecycleEventID(
                phase: request.phase.rawValue,
                childSessionID: childSessionID,
                timestamp: request.timestamp
            ),
            eventType: eventType,
            timestamp: request.timestamp,
            sessionID: childSessionID,
            source: .observed,
            confidence: identity.confidence,
            payload: ProvenanceEventPayload(
                session: session,
                sessionRelationship: relationship,
                externalIdentities: [externalIdentity]
            )
        )
    }
}
