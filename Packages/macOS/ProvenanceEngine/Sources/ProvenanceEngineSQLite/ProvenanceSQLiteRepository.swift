import Foundation
import ProvenanceEngineContracts

/// Internal repository actor that owns one migrated SQLite database connection.
actor ProvenanceSQLiteRepository {
    let database: ProvenanceSQLiteDatabase
    let payloadEncoder: JSONEncoder
    let payloadDecoder: JSONDecoder
    let stableIDFactory: ProvenanceStableIDFactory

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
            validationRunCount: try countRows(in: "provenance_validation_runs"),
            workspaceDisplayCount: try countRows(in: "provenance_workspace_display"),
            codingAgentThreadCount: try countRows(in: "provenance_coding_agent_threads"),
            codingAgentTurnCount: try countRows(in: "provenance_coding_agent_turns"),
            codingAgentPromptCount: try countRows(in: "provenance_coding_agent_prompts"),
            codingAgentPlanUpdateCount: try countRows(in: "provenance_coding_agent_plan_updates"),
            codingAgentCommandCount: try countRows(in: "provenance_coding_agent_commands"),
            codingAgentReasoningSummaryCount: try countRows(in: "provenance_coding_agent_reasoning_summaries"),
            codingAgentAssistantMessageCount: try countRows(in: "provenance_coding_agent_assistant_messages"),
            codingAgentFileChangeAttributionCount: try countRows(in: "provenance_coding_agent_file_change_attributions"),
            codingAgentTurnOutcomeCount: try countRows(in: "provenance_coding_agent_turn_outcomes"),
            codingAgentTurnOutcomeRevisionCount: try countRows(in: "provenance_coding_agent_turn_outcome_revisions")
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
            try applyProjectionUpdates(
                from: event,
                latestEventSequence: eventSequence(id: event.id)
            )
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
                payload_json,
                evidence_origin,
                evidence_scope_json
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
                payload_json,
                evidence_origin,
                evidence_scope_json
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
                payload_json,
                evidence_origin,
                evidence_scope_json
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

    /// Validates current-state projection keys against bounded append-order ledger replay.
    ///
    /// - Parameters:
    ///   - limit: Maximum number of append-order ledger rows to decode.
    ///   - mismatchLimit: Maximum number of missing/unexpected projection keys to include.
    /// - Returns: Checked ledger row metadata and bounded projection key mismatches when the scan is complete.
    /// - Throws: ``ProvenanceSQLiteError`` when SQLite rejects a read or stored enum data is invalid.
    func validateProjectionKeys(
        limit: Int = 1_000,
        mismatchLimit: Int = 100
    ) throws -> ProvenanceSQLiteProjectionKeyValidationReport {
        let rowLimit = max(0, limit)
        let boundedMismatchLimit = max(0, mismatchLimit)
        let ledgerSummary = try eventLedgerSummary()
        let entries = try eventLedgerEntries(limit: rowLimit)
        let truncated = ledgerSummary.count > rowLimit

        guard !truncated else {
            return ProvenanceSQLiteProjectionKeyValidationReport(
                checkedEventCount: entries.count,
                latestCheckedSequence: entries.last?.sequence,
                truncated: true,
                comparedProjectionKeys: false,
                mismatchLimit: boundedMismatchLimit,
                truncatedMismatches: false,
                mismatches: []
            )
        }

        let expectedKeys = projectionKeys(from: entries.map(\.event.payload))
        let comparison = try projectionKeyMismatches(
            expected: expectedKeys,
            mismatchLimit: boundedMismatchLimit
        )
        return ProvenanceSQLiteProjectionKeyValidationReport(
            checkedEventCount: entries.count,
            latestCheckedSequence: entries.last?.sequence,
            truncated: false,
            comparedProjectionKeys: true,
            mismatchLimit: boundedMismatchLimit,
            truncatedMismatches: comparison.truncated,
            mismatches: comparison.mismatches
        )
    }

    /// Repairs current-state projection key drift by replaying the immutable event ledger.
    ///
    /// - Parameters:
    ///   - validationLimit: Maximum number of append-order ledger rows to decode before deciding repair safety.
    ///   - mismatchLimit: Maximum number of missing/unexpected projection keys to include in validation reports.
    ///   - rebuildBatchSize: Maximum number of ledger entries decoded per repair cursor read.
    /// - Returns: Validation and optional rebuild metadata for the repair attempt.
    /// - Throws: ``ProvenanceSQLiteError`` when SQLite rejects a read/rebuild or stored enum data is invalid.
    func repairProjectionDrift(
        validationLimit: Int = 1_000,
        mismatchLimit: Int = 100,
        rebuildBatchSize: Int = 1_000
    ) throws -> ProvenanceSQLiteProjectionRepairReport {
        let validation = try validateProjectionKeys(
            limit: validationLimit,
            mismatchLimit: mismatchLimit
        )
        let hasRepairableDrift = !validation.mismatches.isEmpty || validation.truncatedMismatches
        guard validation.comparedProjectionKeys, hasRepairableDrift else {
            return ProvenanceSQLiteProjectionRepairReport(
                validation: validation,
                repaired: false,
                replayedEventCount: 0,
                postRepairValidation: nil
            )
        }

        let replayedEventCount = try rebuildProjectionsFromEventLedger(batchSize: rebuildBatchSize)
        return ProvenanceSQLiteProjectionRepairReport(
            validation: validation,
            repaired: true,
            replayedEventCount: replayedEventCount,
            postRepairValidation: try validateProjectionKeys(
                limit: validationLimit,
                mismatchLimit: mismatchLimit
            )
        )
    }

    /// Reads a bounded integrity report over internal SQLite ledger and projection state.
    ///
    /// - Parameters:
    ///   - validationLimit: Maximum number of append-order ledger rows to decode.
    ///   - mismatchLimit: Maximum number of missing/unexpected projection keys to include.
    /// - Returns: Storage counts, ledger validation, optional projection comparisons, and repair guidance.
    /// - Throws: ``ProvenanceSQLiteError`` when SQLite rejects a read.
    func storageIntegrityReport(
        validationLimit: Int = 1_000,
        mismatchLimit: Int = 100
    ) throws -> ProvenanceSQLiteStorageIntegrityReport {
        let storageSummary = try storageSummary()
        let ledgerValidation = try validateEventLedger(limit: validationLimit)

        guard ledgerValidation.invalidEventCount == 0 else {
            return ProvenanceSQLiteStorageIntegrityReport(
                status: "ledger_invalid",
                repairRecommended: false,
                storageSummary: storageSummary,
                ledgerValidation: ledgerValidation,
                projectionCountValidation: nil,
                projectionKeyValidation: nil
            )
        }

        let projectionCountValidation = try validateProjectionCounts(limit: validationLimit)
        let projectionKeyValidation = try validateProjectionKeys(
            limit: validationLimit,
            mismatchLimit: mismatchLimit
        )
        let projectionDriftDetected = !projectionCountValidation.mismatches.isEmpty
            || !projectionKeyValidation.mismatches.isEmpty
            || projectionKeyValidation.truncatedMismatches
        let validationTruncated = ledgerValidation.truncated
            || projectionCountValidation.truncated
            || projectionKeyValidation.truncated
            || !projectionCountValidation.comparedProjectionCounts
            || !projectionKeyValidation.comparedProjectionKeys
        let status: String
        if projectionDriftDetected {
            status = "projection_drift"
        } else if validationTruncated {
            status = "validation_truncated"
        } else {
            status = "healthy"
        }

        return ProvenanceSQLiteStorageIntegrityReport(
            status: status,
            repairRecommended: projectionKeyValidation.comparedProjectionKeys
                && (!projectionKeyValidation.mismatches.isEmpty || projectionKeyValidation.truncatedMismatches),
            storageSummary: storageSummary,
            ledgerValidation: ledgerValidation,
            projectionCountValidation: projectionCountValidation,
            projectionKeyValidation: projectionKeyValidation
        )
    }

    /// Repairs storage integrity only when bounded validation proves projection repair is safe.
    ///
    /// - Parameters:
    ///   - validationLimit: Maximum number of append-order ledger rows to decode before deciding repair safety.
    ///   - mismatchLimit: Maximum number of missing/unexpected projection keys to include in validation reports.
    ///   - rebuildBatchSize: Maximum number of ledger entries decoded per repair cursor read.
    /// - Returns: Initial integrity, optional projection repair, and optional post-repair integrity metadata.
    /// - Throws: ``ProvenanceSQLiteError`` when SQLite rejects a read/rebuild or stored enum data is invalid.
    func repairStorageIntegrity(
        validationLimit: Int = 1_000,
        mismatchLimit: Int = 100,
        rebuildBatchSize: Int = 1_000,
        attemptedAt: Date = Date()
    ) throws -> ProvenanceSQLiteStorageRepairReport {
        let initialIntegrityReport = try storageIntegrityReport(
            validationLimit: validationLimit,
            mismatchLimit: mismatchLimit
        )
        guard initialIntegrityReport.repairRecommended else {
            let report = ProvenanceSQLiteStorageRepairReport(
                initialIntegrityReport: initialIntegrityReport,
                repairAttempted: false,
                projectionRepairReport: nil,
                postRepairIntegrityReport: nil
            )
            try insertStorageRepairAttempt(report, attemptedAt: attemptedAt)
            return report
        }

        let projectionRepairReport = try repairProjectionDrift(
            validationLimit: validationLimit,
            mismatchLimit: mismatchLimit,
            rebuildBatchSize: rebuildBatchSize
        )
        let report = ProvenanceSQLiteStorageRepairReport(
            initialIntegrityReport: initialIntegrityReport,
            repairAttempted: true,
            projectionRepairReport: projectionRepairReport,
            postRepairIntegrityReport: try storageIntegrityReport(
                validationLimit: validationLimit,
                mismatchLimit: mismatchLimit
            )
        )
        try insertStorageRepairAttempt(report, attemptedAt: attemptedAt)
        return report
    }

    /// Reads recent storage-integrity repair wrapper calls from internal metadata.
    ///
    /// - Parameter limit: Maximum number of repair-attempt rows to return.
    /// - Returns: Repair attempts sorted newest first by SQLite sequence.
    /// - Throws: ``ProvenanceSQLiteError`` when SQLite rejects the read.
    func storageRepairAttempts(limit: Int = 100) throws -> [ProvenanceSQLiteStorageRepairAttempt] {
        let query = try database.prepare(
            """
            SELECT
                sequence,
                attempted_at_seconds,
                initial_status,
                repair_recommended,
                repair_attempted,
                repaired,
                replayed_event_count,
                post_repair_status
            FROM provenance_storage_repair_attempts
            ORDER BY sequence DESC
            LIMIT ?
            """
        )
        defer { query.finalize() }

        try query.bind(max(0, limit), at: 1)
        var attempts: [ProvenanceSQLiteStorageRepairAttempt] = []
        while try query.step() {
            attempts.append(
                ProvenanceSQLiteStorageRepairAttempt(
                    sequence: query.int(at: 0),
                    attemptedAt: Date(timeIntervalSince1970: query.double(at: 1) ?? 0),
                    initialStatus: query.string(at: 2) ?? "",
                    repairRecommended: query.int(at: 3) != 0,
                    repairAttempted: query.int(at: 4) != 0,
                    repaired: query.int(at: 5) != 0,
                    replayedEventCount: query.int(at: 6),
                    postRepairStatus: query.string(at: 7)
                )
            )
        }
        return attempts
    }

    /// Reads recent applied SQLite schema migrations from internal metadata.
    ///
    /// - Parameter limit: Maximum number of migration metadata rows to return.
    /// - Returns: Applied migrations sorted newest first by SQLite sequence.
    /// - Throws: ``ProvenanceSQLiteError`` when SQLite rejects the read.
    func schemaMigrationRecords(limit: Int = 100) throws -> [ProvenanceSQLiteSchemaMigrationRecord] {
        let query = try database.prepare(
            """
            SELECT
                sequence,
                version,
                applied_at_seconds
            FROM provenance_schema_migrations
            ORDER BY sequence DESC
            LIMIT ?
            """
        )
        defer { query.finalize() }

        try query.bind(max(0, limit), at: 1)
        var records: [ProvenanceSQLiteSchemaMigrationRecord] = []
        while try query.step() {
            records.append(
                ProvenanceSQLiteSchemaMigrationRecord(
                    sequence: query.int(at: 0),
                    version: query.int32(at: 1),
                    appliedAt: Date(timeIntervalSince1970: query.double(at: 2) ?? 0)
                )
            )
        }
        return records
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
                    try applyProjectionUpdates(
                        from: entry.event,
                        latestEventSequence: entry.sequence
                    )
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

    /// Reads one current-state coding-agent thread projection by stable ID.
    ///
    /// - Parameter id: Stable coding-agent thread identifier.
    /// - Returns: The persisted thread projection, or `nil` when the ID is unknown.
    /// - Throws: ``ProvenanceSQLiteError`` when SQLite rejects the read.
    func codingAgentThread(id: String) throws -> ProvenanceCodingAgentThreadRecord? {
        let query = try database.prepare(
            """
            SELECT
                session_id,
                provider,
                provider_thread_id,
                worktree_id,
                source,
                confidence,
                first_observed_at_seconds,
                updated_at_seconds
            FROM provenance_coding_agent_threads
            WHERE id = ?
            """
        )
        defer { query.finalize() }

        try query.bind(id, at: 1)
        guard try query.step(),
              let sessionID = query.string(at: 0),
              let provider = query.string(at: 1),
              let providerThreadID = query.string(at: 2),
              let sourceRawValue = query.string(at: 4),
              let source = ProvenanceSource(rawValue: sourceRawValue),
              let confidenceRawValue = query.string(at: 5),
              let confidence = ProvenanceConfidence(rawValue: confidenceRawValue) else {
            return nil
        }

        return ProvenanceCodingAgentThreadRecord(
            id: id,
            sessionID: sessionID,
            provider: provider,
            providerThreadID: providerThreadID,
            worktreeID: query.string(at: 3),
            source: source,
            confidence: confidence,
            firstObservedAt: Date(timeIntervalSince1970: query.double(at: 6) ?? 0),
            updatedAt: Date(timeIntervalSince1970: query.double(at: 7) ?? 0)
        )
    }

    /// Reads one current-state coding-agent turn projection by stable ID.
    ///
    /// - Parameter id: Stable coding-agent turn identifier.
    /// - Returns: The persisted turn projection, or `nil` when the ID is unknown.
    /// - Throws: ``ProvenanceSQLiteError`` when SQLite rejects the read.
    func codingAgentTurn(id: String) throws -> ProvenanceCodingAgentTurnRecord? {
        let query = try database.prepare(
            """
            SELECT
                session_id,
                thread_id,
                provider,
                provider_turn_id,
                status,
                model,
                effort,
                started_at_seconds,
                completed_at_seconds,
                updated_at_seconds,
                source,
                confidence
            FROM provenance_coding_agent_turns
            WHERE id = ?
            """
        )
        defer { query.finalize() }

        try query.bind(id, at: 1)
        guard try query.step(),
              let sessionID = query.string(at: 0),
              let provider = query.string(at: 2),
              let providerTurnID = query.string(at: 3),
              let status = query.string(at: 4),
              let sourceRawValue = query.string(at: 10),
              let source = ProvenanceSource(rawValue: sourceRawValue),
              let confidenceRawValue = query.string(at: 11),
              let confidence = ProvenanceConfidence(rawValue: confidenceRawValue) else {
            return nil
        }

        return ProvenanceCodingAgentTurnRecord(
            id: id,
            sessionID: sessionID,
            threadID: query.string(at: 1),
            provider: provider,
            providerTurnID: providerTurnID,
            status: status,
            model: query.string(at: 5),
            effort: query.string(at: 6),
            startedAt: query.double(at: 7).map { Date(timeIntervalSince1970: $0) },
            completedAt: query.double(at: 8).map { Date(timeIntervalSince1970: $0) },
            updatedAt: Date(timeIntervalSince1970: query.double(at: 9) ?? 0),
            source: source,
            confidence: confidence
        )
    }

    /// Reads one current-state coding-agent prompt projection by stable ID.
    ///
    /// - Parameter id: Stable coding-agent prompt identifier.
    /// - Returns: The persisted prompt projection, or `nil` when the ID is unknown.
    /// - Throws: ``ProvenanceSQLiteError`` when SQLite rejects the read.
    func codingAgentPrompt(id: String) throws -> ProvenanceCodingAgentPromptRecord? {
        let query = try database.prepare(
            """
            SELECT
                session_id,
                thread_id,
                turn_id,
                provider,
                text,
                submitted_at_seconds,
                source,
                confidence
            FROM provenance_coding_agent_prompts
            WHERE id = ?
            """
        )
        defer { query.finalize() }

        try query.bind(id, at: 1)
        guard try query.step(),
              let sessionID = query.string(at: 0),
              let provider = query.string(at: 3),
              let text = query.string(at: 4),
              let sourceRawValue = query.string(at: 6),
              let source = ProvenanceSource(rawValue: sourceRawValue),
              let confidenceRawValue = query.string(at: 7),
              let confidence = ProvenanceConfidence(rawValue: confidenceRawValue) else {
            return nil
        }

        return ProvenanceCodingAgentPromptRecord(
            id: id,
            sessionID: sessionID,
            threadID: query.string(at: 1),
            turnID: query.string(at: 2),
            provider: provider,
            text: text,
            submittedAt: Date(timeIntervalSince1970: query.double(at: 5) ?? 0),
            source: source,
            confidence: confidence
        )
    }

    /// Reads one current-state coding-agent plan update projection by stable ID.
    ///
    /// - Parameter id: Stable coding-agent plan update identifier.
    /// - Returns: The persisted plan update projection, or `nil` when the ID is unknown.
    /// - Throws: ``ProvenanceSQLiteError`` when SQLite rejects the read.
    func codingAgentPlanUpdate(id: String) throws -> ProvenanceCodingAgentPlanUpdateRecord? {
        let query = try database.prepare(
            """
            SELECT
                session_id,
                thread_id,
                turn_id,
                provider,
                explanation,
                steps_json,
                observed_at_seconds,
                source,
                confidence
            FROM provenance_coding_agent_plan_updates
            WHERE id = ?
            """
        )
        defer { query.finalize() }

        try query.bind(id, at: 1)
        guard try query.step(),
              let sessionID = query.string(at: 0),
              let provider = query.string(at: 3),
              let stepsJSON = query.string(at: 5),
              let stepsData = stepsJSON.data(using: .utf8),
              let sourceRawValue = query.string(at: 7),
              let source = ProvenanceSource(rawValue: sourceRawValue),
              let confidenceRawValue = query.string(at: 8),
              let confidence = ProvenanceConfidence(rawValue: confidenceRawValue) else {
            return nil
        }
        let steps = try payloadDecoder.decode([ProvenanceCodingAgentPlanStepRecord].self, from: stepsData)

        return ProvenanceCodingAgentPlanUpdateRecord(
            id: id,
            sessionID: sessionID,
            threadID: query.string(at: 1),
            turnID: query.string(at: 2),
            provider: provider,
            explanation: query.string(at: 4),
            steps: steps,
            observedAt: Date(timeIntervalSince1970: query.double(at: 6) ?? 0),
            source: source,
            confidence: confidence
        )
    }

    /// Reads one current-state coding-agent command projection by stable ID.
    ///
    /// - Parameter id: Stable coding-agent command identifier.
    /// - Returns: The persisted command projection, or `nil` when the ID is unknown.
    /// - Throws: ``ProvenanceSQLiteError`` when SQLite rejects the read.
    func codingAgentCommand(id: String) throws -> ProvenanceCodingAgentCommandRecord? {
        let query = try database.prepare(
            """
            SELECT
                session_id,
                thread_id,
                turn_id,
                provider,
                operation_id,
                command_text,
                cwd,
                status,
                exit_code,
                output_summary,
                started_at_seconds,
                completed_at_seconds,
                source,
                confidence
            FROM provenance_coding_agent_commands
            WHERE id = ?
            """
        )
        defer { query.finalize() }

        try query.bind(id, at: 1)
        guard try query.step(),
              let sessionID = query.string(at: 0),
              let provider = query.string(at: 3),
              let commandText = query.string(at: 5),
              let status = query.string(at: 7),
              let sourceRawValue = query.string(at: 12),
              let source = ProvenanceSource(rawValue: sourceRawValue),
              let confidenceRawValue = query.string(at: 13),
              let confidence = ProvenanceConfidence(rawValue: confidenceRawValue) else {
            return nil
        }

        return ProvenanceCodingAgentCommandRecord(
            id: id,
            sessionID: sessionID,
            threadID: query.string(at: 1),
            turnID: query.string(at: 2),
            provider: provider,
            operationID: query.string(at: 4),
            command: commandText,
            cwd: query.string(at: 6),
            status: status,
            exitCode: query.double(at: 8).map(Int.init),
            outputSummary: query.string(at: 9),
            startedAt: query.double(at: 10).map { Date(timeIntervalSince1970: $0) },
            completedAt: Date(timeIntervalSince1970: query.double(at: 11) ?? 0),
            source: source,
            confidence: confidence
        )
    }

    /// Reads one current-state visible reasoning-summary projection by stable ID.
    ///
    /// - Parameter id: Stable coding-agent reasoning-summary identifier.
    /// - Returns: The persisted visible summary projection, or `nil` when the ID is unknown.
    /// - Throws: ``ProvenanceSQLiteError`` when SQLite rejects the read.
    func codingAgentReasoningSummary(id: String) throws -> ProvenanceCodingAgentReasoningSummaryRecord? {
        let query = try database.prepare(
            """
            SELECT
                session_id,
                thread_id,
                turn_id,
                provider,
                item_id,
                text,
                completed_at_seconds,
                source,
                confidence
            FROM provenance_coding_agent_reasoning_summaries
            WHERE id = ?
            """
        )
        defer { query.finalize() }

        try query.bind(id, at: 1)
        guard try query.step(),
              let sessionID = query.string(at: 0),
              let provider = query.string(at: 3),
              let text = query.string(at: 5),
              let sourceRawValue = query.string(at: 7),
              let source = ProvenanceSource(rawValue: sourceRawValue),
              let confidenceRawValue = query.string(at: 8),
              let confidence = ProvenanceConfidence(rawValue: confidenceRawValue) else {
            return nil
        }

        return ProvenanceCodingAgentReasoningSummaryRecord(
            id: id,
            sessionID: sessionID,
            threadID: query.string(at: 1),
            turnID: query.string(at: 2),
            provider: provider,
            itemID: query.string(at: 4),
            text: text,
            completedAt: Date(timeIntervalSince1970: query.double(at: 6) ?? 0),
            source: source,
            confidence: confidence
        )
    }

    /// Reads one current-state file-change attribution projection by stable ID.
    ///
    /// - Parameter id: Stable coding-agent file-change attribution identifier.
    /// - Returns: The persisted attribution projection, or `nil` when the ID is unknown.
    /// - Throws: ``ProvenanceSQLiteError`` when SQLite rejects the read.
    func codingAgentFileChangeAttribution(id: String) throws -> ProvenanceCodingAgentFileChangeAttributionRecord? {
        let query = try database.prepare(
            """
            SELECT
                session_id,
                thread_id,
                turn_id,
                provider,
                operation_id,
                change_set_id,
                file_change_ids_json,
                paths_json,
                summary,
                observed_at_seconds,
                source,
                confidence
            FROM provenance_coding_agent_file_change_attributions
            WHERE id = ?
            """
        )
        defer { query.finalize() }

        try query.bind(id, at: 1)
        guard try query.step(),
              let sessionID = query.string(at: 0),
              let provider = query.string(at: 3),
              let fileChangeIDsJSON = query.string(at: 6),
              let fileChangeIDsData = fileChangeIDsJSON.data(using: .utf8),
              let pathsJSON = query.string(at: 7),
              let pathsData = pathsJSON.data(using: .utf8),
              let sourceRawValue = query.string(at: 10),
              let source = ProvenanceSource(rawValue: sourceRawValue),
              let confidenceRawValue = query.string(at: 11),
              let confidence = ProvenanceConfidence(rawValue: confidenceRawValue) else {
            return nil
        }
        let fileChangeIDs = try payloadDecoder.decode([String].self, from: fileChangeIDsData)
        let paths = try payloadDecoder.decode([String].self, from: pathsData)

        return ProvenanceCodingAgentFileChangeAttributionRecord(
            id: id,
            sessionID: sessionID,
            threadID: query.string(at: 1),
            turnID: query.string(at: 2),
            provider: provider,
            operationID: query.string(at: 4),
            changeSetID: query.string(at: 5),
            fileChangeIDs: fileChangeIDs,
            paths: paths,
            summary: query.string(at: 8),
            observedAt: Date(timeIntervalSince1970: query.double(at: 9) ?? 0),
            source: source,
            confidence: confidence
        )
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

    /// Reads current display metadata for one workspace.
    ///
    /// - Parameter request: Workspace display query parameters.
    /// - Returns: Found response with current display metadata, or `no_workspace_display` when absent.
    /// - Throws: ``ProvenanceSQLiteError`` when SQLite rejects the read.
    func workspaceDisplay(_ request: ProvenanceWorkspaceDisplayRequest) throws -> ProvenanceWorkspaceDisplayResponse {
        guard let display = try workspaceDisplay(workspaceID: request.workspaceID) else {
            return ProvenanceWorkspaceDisplayResponse(
                found: false,
                reason: "no_workspace_display",
                workspaceID: request.workspaceID,
                display: nil
            )
        }

        return ProvenanceWorkspaceDisplayResponse(
            found: true,
            workspaceID: request.workspaceID,
            display: display
        )
    }

    /// Reads the factual session projection snapshot for one coding-agent session.
    ///
    /// - Parameter request: Factual session projection query parameters.
    /// - Returns: Found response with revisioned factual coding-agent evidence, or `no_session` when absent.
    /// - Throws: ``ProvenanceSQLiteError`` when SQLite rejects the read.
    func factualSessionProjection(_ request: ProvenanceFactualSessionProjectionRequest) throws -> ProvenanceFactualSessionProjectionResponse {
        guard let session = try session(id: request.sessionID) else {
            return ProvenanceFactualSessionProjectionResponse(
                found: false,
                reason: "no_session",
                sessionID: request.sessionID,
                snapshot: nil
            )
        }

        let providerThreads = try codingAgentThreadIDs(sessionID: request.sessionID).compactMap {
            try codingAgentThread(id: $0)
        }
        let allTurnIDs = try codingAgentTurnIDs(sessionID: request.sessionID, limit: nil)
        let latestTurnID = allTurnIDs.last
        let latestTurn = try latestTurnID.flatMap { try factualTurnSnapshot(turnID: $0) }
        let priorTurns = try allTurnIDs.dropLast(latestTurnID == nil ? 0 : 1).compactMap { turnID in
            try codingAgentTurn(id: turnID).map(ProvenanceFactualSessionProjectionTurnReference.init(turn:))
        }
        let turns = try codingAgentTurnIDs(
            sessionID: request.sessionID,
            limit: request.turnLimit
        ).compactMap { turnID in
            try factualTurnSnapshot(turnID: turnID)
        }

        return ProvenanceFactualSessionProjectionResponse(
            found: true,
            sessionID: request.sessionID,
            snapshot: ProvenanceFactualSessionProjectionSnapshot(
                revision: try latestEventSequence(sessionID: request.sessionID),
                session: session,
                providerThreadIdentities: providerThreads.map(
                    ProvenanceFactualSessionProjectionProviderThreadIdentity.init(thread:)
                ),
                providerThreads: providerThreads,
                latestTurn: latestTurn,
                priorTurns: priorTurns,
                turns: turns
            )
        )
    }

    /// Reads factual detail for one observed coding-agent turn.
    ///
    /// - Parameter request: Factual turn-detail query parameters.
    /// - Returns: Found response with revisioned factual turn evidence, or `no_turn` when absent.
    /// - Throws: ``ProvenanceSQLiteError`` when SQLite rejects the read.
    func factualSessionTurnDetail(_ request: ProvenanceFactualSessionTurnDetailRequest) async throws
        -> ProvenanceFactualSessionTurnDetailResponse {
        guard let detail = try factualTurnSnapshot(turnID: request.turnID) else {
            return ProvenanceFactualSessionTurnDetailResponse(
                found: false,
                reason: "no_turn",
                turnID: request.turnID,
                turnDetail: nil
            )
        }

        return ProvenanceFactualSessionTurnDetailResponse(
            found: true,
            turnID: request.turnID,
            sessionID: detail.turn.sessionID,
            revision: try latestEventSequence(sessionID: detail.turn.sessionID),
            turnDetail: detail
        )
    }

    /// Publishes one semantic inference record and supersedes historical records atomically.
    ///
    /// - Parameter request: Semantic inference publish request.
    /// - Returns: Accepted response with superseded inference IDs.
    /// - Throws: ``ProvenanceSQLiteError`` when SQLite rejects the write or record JSON cannot be encoded.
    func publishSemanticInferenceRecord(_ request: ProvenanceSemanticInferencePublishRequest) throws
        -> ProvenanceSemanticInferencePublishResponse {
        try database.execute("BEGIN IMMEDIATE TRANSACTION")
        do {
            try insertSemanticInference(request.record)
            for supersededID in request.record.supersedes {
                try supersedeSemanticInference(id: supersededID, replacement: request.record)
            }
            try database.execute("COMMIT")
        } catch {
            try? database.execute("ROLLBACK")
            throw error
        }

        return ProvenanceSemanticInferencePublishResponse(
            accepted: true,
            inferenceID: request.record.id,
            supersededInferenceIDs: request.record.supersedes
        )
    }

    /// Reads semantic inference records for one scope.
    ///
    /// - Parameter request: Semantic inference query parameters.
    /// - Returns: Matching semantic records in newest-first order.
    /// - Throws: ``ProvenanceSQLiteError`` when SQLite rejects the read or stored JSON cannot be decoded.
    func semanticInferenceRecords(_ request: ProvenanceSemanticInferenceQueryRequest) throws
        -> ProvenanceSemanticInferenceQueryResponse {
        let rowLimit = request.limit.map { max(0, $0) }
        var sql = """
            SELECT
                id,
                schema_version,
                inference_kind,
                scope,
                scope_id,
                payload_json,
                supporting_evidence_refs_json,
                supporting_factual_revision,
                confidence,
                specificity,
                producer_type,
                producer_id,
                producer_version,
                created_at_seconds,
                supersedes_json,
                superseded_by,
                status
            FROM provenance_semantic_inferences
            WHERE scope = ?
              AND scope_id = ?
            """
        if request.kind != nil {
            sql += "\n  AND inference_kind = ?"
        }
        if !request.includeInactive {
            sql += "\n  AND status = 'active'"
        }
        sql += "\nORDER BY created_at_seconds DESC, rowid DESC"
        if rowLimit != nil {
            sql += "\nLIMIT ?"
        }

        let query = try database.prepare(sql)
        defer { query.finalize() }

        var bindIndex: Int32 = 1
        try query.bind(request.scope.rawValue, at: bindIndex)
        bindIndex += 1
        try query.bind(request.scopeID, at: bindIndex)
        bindIndex += 1
        if let kind = request.kind {
            try query.bind(kind, at: bindIndex)
            bindIndex += 1
        }
        if let rowLimit {
            try query.bind(rowLimit, at: bindIndex)
        }

        var records: [ProvenanceSemanticInferenceRecord] = []
        while try query.step() {
            records.append(try semanticInference(from: query))
        }
        return ProvenanceSemanticInferenceQueryResponse(records: records)
    }

    /// Publishes one semantic message record and supersedes historical wording atomically.
    ///
    /// - Parameter request: Semantic message publish request.
    /// - Returns: Accepted response with superseded message IDs.
    /// - Throws: ``ProvenanceSQLiteError`` when SQLite rejects the write or record JSON cannot be encoded.
    func publishSemanticMessageRecord(_ request: ProvenanceSemanticMessagePublishRequest) throws
        -> ProvenanceSemanticMessagePublishResponse {
        try database.execute("BEGIN IMMEDIATE TRANSACTION")
        do {
            try insertSemanticMessage(request.record)
            for supersededID in request.record.supersedes {
                try supersedeSemanticMessage(id: supersededID, replacement: request.record)
            }
            try database.execute("COMMIT")
        } catch {
            try? database.execute("ROLLBACK")
            throw error
        }

        return ProvenanceSemanticMessagePublishResponse(
            accepted: true,
            messageID: request.record.id,
            supersededMessageIDs: request.record.supersedes
        )
    }

    /// Reads semantic message records for one scope.
    ///
    /// - Parameter request: Semantic message query parameters.
    /// - Returns: Matching semantic messages in newest-first order.
    /// - Throws: ``ProvenanceSQLiteError`` when SQLite rejects the read or stored JSON cannot be decoded.
    func semanticMessageRecords(_ request: ProvenanceSemanticMessageQueryRequest) throws
        -> ProvenanceSemanticMessageQueryResponse {
        let rowLimit = request.limit.map { max(0, $0) }
        var sql = """
            SELECT
                id,
                schema_version,
                semantic_inference_id,
                semantic_inference_kind,
                scope,
                scope_id,
                concise_phrase,
                expanded_meaning,
                structured_semantic_payload_json,
                supporting_evidence_refs_json,
                supporting_factual_revision,
                confidence,
                specificity,
                presentation_producer_type,
                presentation_producer_id,
                presentation_producer_version,
                presentation_policy_id,
                presentation_policy_version,
                locale_identifier,
                created_at_seconds,
                supersedes_json,
                superseded_by,
                status
            FROM provenance_semantic_messages
            WHERE scope = ?
              AND scope_id = ?
            """
        if request.semanticInferenceKind != nil {
            sql += "\n  AND semantic_inference_kind = ?"
        }
        if request.semanticInferenceID != nil {
            sql += "\n  AND semantic_inference_id = ?"
        }
        if request.presentationPolicyID != nil {
            sql += "\n  AND presentation_policy_id = ?"
        }
        if !request.includeInactive {
            sql += "\n  AND status = 'active'"
        }
        sql += "\nORDER BY created_at_seconds DESC, rowid DESC"
        if rowLimit != nil {
            sql += "\nLIMIT ?"
        }

        let query = try database.prepare(sql)
        defer { query.finalize() }

        var bindIndex: Int32 = 1
        try query.bind(request.scope.rawValue, at: bindIndex)
        bindIndex += 1
        try query.bind(request.scopeID, at: bindIndex)
        bindIndex += 1
        if let kind = request.semanticInferenceKind {
            try query.bind(kind, at: bindIndex)
            bindIndex += 1
        }
        if let semanticInferenceID = request.semanticInferenceID {
            try query.bind(semanticInferenceID, at: bindIndex)
            bindIndex += 1
        }
        if let presentationPolicyID = request.presentationPolicyID {
            try query.bind(presentationPolicyID, at: bindIndex)
            bindIndex += 1
        }
        if let rowLimit {
            try query.bind(rowLimit, at: bindIndex)
        }

        var records: [ProvenanceSemanticMessageRecord] = []
        while try query.step() {
            records.append(try semanticMessage(from: query))
        }
        return ProvenanceSemanticMessageQueryResponse(records: records)
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

    private func eventSequence(id: String) throws -> Int? {
        let query = try database.prepare("SELECT sequence FROM provenance_events WHERE id = ?")
        defer { query.finalize() }
        try query.bind(id, at: 1)
        guard try query.step() else { return nil }
        return query.int(at: 0)
    }

    private func latestEventSequence(sessionID: String) throws -> Int? {
        let query = try database.prepare("SELECT MAX(sequence) FROM provenance_events WHERE session_id = ?")
        defer { query.finalize() }
        try query.bind(sessionID, at: 1)
        guard try query.step() else { return nil }
        return query.double(at: 0).map(Int.init)
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
        var workspaceDisplays = Set<String>()
        var codingAgentThreads = Set<String>()
        var codingAgentTurns = Set<String>()
        var codingAgentPrompts = Set<String>()
        var codingAgentPlanUpdates = Set<String>()
        var codingAgentCommands = Set<String>()
        var codingAgentReasoningSummaries = Set<String>()
        var codingAgentAssistantMessages = Set<String>()
        var codingAgentFileChangeAttributions = Set<String>()

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
            if let workspaceDisplay = payload.workspaceDisplay {
                workspaceDisplays.insert(workspaceDisplay.id)
            }
            if let codingAgentThread = payload.codingAgentThread {
                codingAgentThreads.insert(codingAgentThread.id)
            }
            if let codingAgentTurn = payload.codingAgentTurn {
                codingAgentTurns.insert(codingAgentTurn.id)
            }
            if let codingAgentPrompt = payload.codingAgentPrompt {
                codingAgentPrompts.insert(codingAgentPrompt.id)
            }
            if let codingAgentPlanUpdate = payload.codingAgentPlanUpdate {
                codingAgentPlanUpdates.insert(codingAgentPlanUpdate.id)
            }
            if let codingAgentCommand = payload.codingAgentCommand {
                codingAgentCommands.insert(codingAgentCommand.id)
            }
            if let codingAgentReasoningSummary = payload.codingAgentReasoningSummary {
                codingAgentReasoningSummaries.insert(codingAgentReasoningSummary.id)
            }
            if let codingAgentAssistantMessage = payload.codingAgentAssistantMessage {
                codingAgentAssistantMessages.insert(codingAgentAssistantMessage.id)
            }
            if let codingAgentFileChangeAttribution = payload.codingAgentFileChangeAttribution {
                codingAgentFileChangeAttributions.insert(codingAgentFileChangeAttribution.id)
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
            "provenance_workspace_display": workspaceDisplays.count,
            "provenance_coding_agent_threads": codingAgentThreads.count,
            "provenance_coding_agent_turns": codingAgentTurns.count,
            "provenance_coding_agent_prompts": codingAgentPrompts.count,
            "provenance_coding_agent_plan_updates": codingAgentPlanUpdates.count,
            "provenance_coding_agent_commands": codingAgentCommands.count,
            "provenance_coding_agent_reasoning_summaries": codingAgentReasoningSummaries.count,
            "provenance_coding_agent_assistant_messages": codingAgentAssistantMessages.count,
            "provenance_coding_agent_file_change_attributions": codingAgentFileChangeAttributions.count,
        ]
    }

    private func projectionKeys(from payloads: [ProvenanceEventPayload]) -> [String: Set<String>] {
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
        var workspaceDisplays = Set<String>()
        var codingAgentThreads = Set<String>()
        var codingAgentTurns = Set<String>()
        var codingAgentPrompts = Set<String>()
        var codingAgentPlanUpdates = Set<String>()
        var codingAgentCommands = Set<String>()
        var codingAgentReasoningSummaries = Set<String>()
        var codingAgentAssistantMessages = Set<String>()
        var codingAgentFileChangeAttributions = Set<String>()

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
                externalIdentities.insert(projectionExternalIdentityKey(identity))
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
            if let workspaceDisplay = payload.workspaceDisplay {
                workspaceDisplays.insert(workspaceDisplay.id)
            }
            if let codingAgentThread = payload.codingAgentThread {
                codingAgentThreads.insert(codingAgentThread.id)
            }
            if let codingAgentTurn = payload.codingAgentTurn {
                codingAgentTurns.insert(codingAgentTurn.id)
            }
            if let codingAgentPrompt = payload.codingAgentPrompt {
                codingAgentPrompts.insert(codingAgentPrompt.id)
            }
            if let codingAgentPlanUpdate = payload.codingAgentPlanUpdate {
                codingAgentPlanUpdates.insert(codingAgentPlanUpdate.id)
            }
            if let codingAgentCommand = payload.codingAgentCommand {
                codingAgentCommands.insert(codingAgentCommand.id)
            }
            if let codingAgentReasoningSummary = payload.codingAgentReasoningSummary {
                codingAgentReasoningSummaries.insert(codingAgentReasoningSummary.id)
            }
            if let codingAgentAssistantMessage = payload.codingAgentAssistantMessage {
                codingAgentAssistantMessages.insert(codingAgentAssistantMessage.id)
            }
            if let codingAgentFileChangeAttribution = payload.codingAgentFileChangeAttribution {
                codingAgentFileChangeAttributions.insert(codingAgentFileChangeAttribution.id)
            }
        }

        return [
            "provenance_repositories": repositories,
            "provenance_worktrees": worktrees,
            "provenance_sessions": sessions,
            "provenance_session_relationships": sessionRelationships,
            "provenance_session_external_identities": externalIdentities,
            "provenance_work_items": workItems,
            "provenance_work_contributions": contributions,
            "provenance_checkpoints": checkpoints,
            "provenance_change_sets": changeSets,
            "provenance_file_changes": fileChanges,
            "provenance_validation_runs": validationRuns,
            "provenance_workspace_display": workspaceDisplays,
            "provenance_coding_agent_threads": codingAgentThreads,
            "provenance_coding_agent_turns": codingAgentTurns,
            "provenance_coding_agent_prompts": codingAgentPrompts,
            "provenance_coding_agent_plan_updates": codingAgentPlanUpdates,
            "provenance_coding_agent_commands": codingAgentCommands,
            "provenance_coding_agent_reasoning_summaries": codingAgentReasoningSummaries,
            "provenance_coding_agent_assistant_messages": codingAgentAssistantMessages,
            "provenance_coding_agent_file_change_attributions": codingAgentFileChangeAttributions,
        ]
    }

    private func projectionCountMismatches(
        expected: [String: Int]
    ) throws -> [ProvenanceSQLiteProjectionValidationMismatch] {
        var mismatches: [ProvenanceSQLiteProjectionValidationMismatch] = []
        for tableName in projectionTableNames {
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

    private func projectionKeyMismatches(
        expected: [String: Set<String>],
        mismatchLimit: Int
    ) throws -> (mismatches: [ProvenanceSQLiteProjectionKeyMismatch], truncated: Bool) {
        var mismatches: [ProvenanceSQLiteProjectionKeyMismatch] = []
        var truncated = false

        for tableName in projectionTableNames {
            let expectedKeys = expected[tableName] ?? []
            let actualKeys = try projectionKeys(in: tableName)
            let missingKeys = expectedKeys.subtracting(actualKeys).sorted()
            let unexpectedKeys = actualKeys.subtracting(expectedKeys).sorted()

            for key in missingKeys {
                guard mismatches.count < mismatchLimit else {
                    truncated = true
                    break
                }
                mismatches.append(
                    ProvenanceSQLiteProjectionKeyMismatch(
                        tableName: tableName,
                        key: key,
                        kind: "missing"
                    )
                )
            }
            for key in unexpectedKeys {
                guard mismatches.count < mismatchLimit else {
                    truncated = true
                    break
                }
                mismatches.append(
                    ProvenanceSQLiteProjectionKeyMismatch(
                        tableName: tableName,
                        key: key,
                        kind: "unexpected"
                    )
                )
            }
        }

        return (mismatches, truncated)
    }

    private var projectionTableNames: [String] {
        [
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
            "provenance_workspace_display",
            "provenance_coding_agent_threads",
            "provenance_coding_agent_turns",
            "provenance_coding_agent_prompts",
            "provenance_coding_agent_plan_updates",
            "provenance_coding_agent_commands",
            "provenance_coding_agent_reasoning_summaries",
            "provenance_coding_agent_assistant_messages",
            "provenance_coding_agent_file_change_attributions",
        ]
    }

    private func projectionKeys(in tableName: String) throws -> Set<String> {
        let sql: String
        switch tableName {
        case "provenance_session_relationships":
            sql = "SELECT session_id FROM provenance_session_relationships"
        case "provenance_session_external_identities":
            sql = "SELECT system, kind, external_id FROM provenance_session_external_identities"
        default:
            sql = "SELECT id FROM \(tableName)"
        }

        let query = try database.prepare(sql)
        defer { query.finalize() }

        var keys = Set<String>()
        while try query.step() {
            if tableName == "provenance_session_external_identities" {
                guard let system = query.string(at: 0),
                      let kind = query.string(at: 1),
                      let externalID = query.string(at: 2) else {
                    continue
                }
                keys.insert(projectionExternalIdentityKey(system: system, kind: kind, externalID: externalID))
            } else if let key = query.string(at: 0) {
                keys.insert(key)
            }
        }
        return keys
    }

    private func projectionExternalIdentityKey(_ identity: ProvenanceExternalIdentityRecord) -> String {
        projectionExternalIdentityKey(system: identity.system, kind: identity.kind, externalID: identity.externalID)
    }

    private func projectionExternalIdentityKey(system: String, kind: String, externalID: String) -> String {
        "\(system)\u{0}\(kind)\u{0}\(externalID)"
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
        let evidenceScope: ProvenanceEvidenceScope?
        if let evidenceScopeJSON = query.string(at: offset + 11) {
            guard let evidenceScopeData = evidenceScopeJSON.data(using: .utf8) else {
                throw ProvenanceSQLiteError.sqlite(message: "stored event has invalid evidence scope")
            }
            evidenceScope = try payloadDecoder.decode(ProvenanceEvidenceScope.self, from: evidenceScopeData)
        } else {
            evidenceScope = nil
        }
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
            evidenceOrigin: query.string(at: offset + 10).map(ProvenanceEvidenceOrigin.init(rawValue:)),
            evidenceScope: evidenceScope,
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

    private func workspaceDisplay(workspaceID: String) throws -> ProvenanceWorkspaceDisplayRecord? {
        let query = try database.prepare(
            """
            SELECT
                id,
                workspace_id,
                repository_id,
                worktree_id,
                title,
                title_source,
                branch,
                pull_request_number,
                pull_request_url,
                pull_request_owner_login,
                pull_request_owner_url,
                pull_request_status,
                pull_request_branch,
                pull_request_is_stale,
                current_directory,
                is_dirty,
                ticket_ids_json,
                ticket_links_json,
                project_links_json,
                current_work_summary,
                last_submitted_prompt,
                last_submitted_prompt_submitted_at_seconds,
                last_submitted_prompt_session_id,
                cleared_fields_json,
                field_metadata_json,
                latest_event_id,
                latest_event_sequence,
                observed_at_seconds,
                updated_at_seconds
            FROM provenance_workspace_display
            WHERE workspace_id = ?
            ORDER BY updated_at_seconds DESC, rowid DESC
            LIMIT 1
            """
        )
        defer { query.finalize() }

        try query.bind(workspaceID, at: 1)
        guard try query.step() else { return nil }
        return try workspaceDisplay(from: query)
    }

    private func workspaceDisplay(from query: ProvenanceSQLiteStatement) throws -> ProvenanceWorkspaceDisplayRecord? {
        guard let id = query.string(at: 0),
              let workspaceID = query.string(at: 1),
              let ticketIDsJSON = query.string(at: 16),
              let ticketIDsData = ticketIDsJSON.data(using: .utf8),
              let ticketLinksJSON = query.string(at: 17),
              let ticketLinksData = ticketLinksJSON.data(using: .utf8),
              let projectLinksJSON = query.string(at: 18),
              let projectLinksData = projectLinksJSON.data(using: .utf8),
              let clearedFieldsJSON = query.string(at: 23),
              let clearedFieldsData = clearedFieldsJSON.data(using: .utf8),
              let fieldMetadataJSON = query.string(at: 24),
              let fieldMetadataData = fieldMetadataJSON.data(using: .utf8) else {
            return nil
        }

        let ticketIDs = (try? payloadDecoder.decode([String].self, from: ticketIDsData)) ?? []
        let ticketLinks = (try? payloadDecoder.decode(
            [ProvenanceWorkspaceDisplayTicketLinkRecord].self,
            from: ticketLinksData
        )) ?? []
        let projectLinks = (try? payloadDecoder.decode(
            [ProvenanceWorkspaceDisplayProjectLinkRecord].self,
            from: projectLinksData
        )) ?? []
        let clearedFields = (try? payloadDecoder.decode([String].self, from: clearedFieldsData)) ?? []
        let fieldMetadata = (try? payloadDecoder.decode(
            [String: ProvenanceWorkspaceDisplayFieldMetadataRecord].self,
            from: fieldMetadataData
        )) ?? [:]
        return ProvenanceWorkspaceDisplayRecord(
            id: id,
            workspaceID: workspaceID,
            repositoryID: query.string(at: 2),
            worktreeID: query.string(at: 3),
            currentDirectory: query.string(at: 14),
            title: query.string(at: 4),
            titleSource: query.string(at: 5),
            branch: query.string(at: 6),
            pullRequestNumber: query.double(at: 7).map(Int.init),
            pullRequestURL: query.string(at: 8),
            pullRequestOwnerLogin: query.string(at: 9),
            pullRequestOwnerURL: query.string(at: 10),
            pullRequestStatus: query.string(at: 11),
            pullRequestBranch: query.string(at: 12),
            pullRequestIsStale: query.int(at: 13) != 0,
            isDirty: query.double(at: 15).map { Int($0) != 0 },
            ticketIDs: ticketIDs,
            ticketLinks: ticketLinks,
            projectLinks: projectLinks,
            currentWorkSummary: query.string(at: 19),
            lastSubmittedPrompt: query.string(at: 20),
            lastSubmittedPromptSubmittedAt: query.double(at: 21).map { Date(timeIntervalSince1970: $0) },
            lastSubmittedPromptSessionID: query.string(at: 22),
            clearedFields: clearedFields,
            fieldMetadata: fieldMetadata,
            latestEventID: query.string(at: 25),
            latestEventSequence: query.double(at: 26).map(Int.init),
            observedAt: Date(timeIntervalSince1970: query.double(at: 27) ?? 0),
            updatedAt: Date(timeIntervalSince1970: query.double(at: 28) ?? 0)
        )
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
        let evidenceScopeJSON: String?
        if let evidenceScope = event.evidenceScope {
            let evidenceScopeData = try payloadEncoder.encode(evidenceScope)
            guard let encodedEvidenceScope = String(data: evidenceScopeData, encoding: .utf8) else {
                throw ProvenanceSQLiteError.sqlite(message: "failed to encode event evidence scope")
            }
            evidenceScopeJSON = encodedEvidenceScope
        } else {
            evidenceScopeJSON = nil
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
                payload_json,
                evidence_origin,
                evidence_scope_json
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
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
        try insert.bind(event.evidenceOrigin?.rawValue, at: 12)
        try insert.bind(evidenceScopeJSON, at: 13)

        _ = try insert.step()
    }

    private func applyProjectionUpdates(
        from event: ProvenanceEvent,
        latestEventSequence: Int? = nil
    ) throws {
        let payload = event.payload
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
        if let workspaceDisplay = payload.workspaceDisplay {
            try upsertWorkspaceDisplay(
                workspaceDisplay,
                event: event,
                latestEventSequence: latestEventSequence
            )
        }
        if let codingAgentThread = payload.codingAgentThread {
            try upsertCodingAgentThread(codingAgentThread)
        }
        if let codingAgentTurn = payload.codingAgentTurn {
            try upsertCodingAgentTurn(codingAgentTurn)
        }
        if let codingAgentPrompt = payload.codingAgentPrompt {
            try upsertCodingAgentPrompt(codingAgentPrompt)
        }
        if let codingAgentPlanUpdate = payload.codingAgentPlanUpdate {
            try upsertCodingAgentPlanUpdate(codingAgentPlanUpdate)
        }
        if let codingAgentCommand = payload.codingAgentCommand {
            try upsertCodingAgentCommand(codingAgentCommand)
        }
        if let codingAgentReasoningSummary = payload.codingAgentReasoningSummary {
            try upsertCodingAgentReasoningSummary(codingAgentReasoningSummary)
        }
        if let codingAgentAssistantMessage = payload.codingAgentAssistantMessage {
            try upsertCodingAgentAssistantMessage(codingAgentAssistantMessage)
        }
        if let codingAgentFileChangeAttribution = payload.codingAgentFileChangeAttribution {
            try upsertCodingAgentFileChangeAttribution(codingAgentFileChangeAttribution)
        }
        try refreshTurnOutcomes(affectedBy: event, latestEventSequence: latestEventSequence)
    }

    private func clearProjectionTables() throws {
        for tableName in [
            "provenance_coding_agent_turn_outcomes",
            "provenance_coding_agent_turn_outcome_revisions",
            "provenance_coding_agent_file_change_attributions",
            "provenance_coding_agent_assistant_messages",
            "provenance_coding_agent_reasoning_summaries",
            "provenance_coding_agent_commands",
            "provenance_coding_agent_plan_updates",
            "provenance_coding_agent_prompts",
            "provenance_coding_agent_turns",
            "provenance_coding_agent_threads",
            "provenance_workspace_display",
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

    private func upsertWorkspaceDisplay(
        _ display: ProvenanceWorkspaceDisplayRecord,
        event: ProvenanceEvent,
        latestEventSequence: Int? = nil
    ) throws {
        let merged = try mergedWorkspaceDisplay(
            display,
            event: event,
            latestEventSequence: latestEventSequence
        )
        let ticketIDsJSON = try encodedWorkspaceDisplayJSON(
            merged.ticketIDs,
            failureMessage: "failed to encode workspace display ticket IDs"
        )
        let ticketLinksJSON = try encodedWorkspaceDisplayJSON(
            merged.ticketLinks,
            failureMessage: "failed to encode workspace display ticket links"
        )
        let projectLinksJSON = try encodedWorkspaceDisplayJSON(
            merged.projectLinks,
            failureMessage: "failed to encode workspace display project links"
        )
        let clearedFieldsJSON = try encodedWorkspaceDisplayJSON(
            merged.clearedFields,
            failureMessage: "failed to encode workspace display cleared fields"
        )
        let fieldMetadataJSON = try encodedWorkspaceDisplayJSON(
            merged.fieldMetadata,
            failureMessage: "failed to encode workspace display field metadata"
        )

        let upsert = try database.prepare(
            """
            INSERT INTO provenance_workspace_display (
                id,
                workspace_id,
                repository_id,
                worktree_id,
                title,
                title_source,
                branch,
                pull_request_number,
                pull_request_url,
                pull_request_owner_login,
                pull_request_owner_url,
                pull_request_status,
                pull_request_branch,
                pull_request_is_stale,
                current_directory,
                is_dirty,
                ticket_ids_json,
                ticket_links_json,
                project_links_json,
                current_work_summary,
                last_submitted_prompt,
                last_submitted_prompt_submitted_at_seconds,
                last_submitted_prompt_session_id,
                cleared_fields_json,
                field_metadata_json,
                latest_event_id,
                latest_event_sequence,
                observed_at_seconds,
                updated_at_seconds
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                workspace_id = excluded.workspace_id,
                repository_id = excluded.repository_id,
                worktree_id = excluded.worktree_id,
                title = excluded.title,
                title_source = excluded.title_source,
                branch = excluded.branch,
                pull_request_number = excluded.pull_request_number,
                pull_request_url = excluded.pull_request_url,
                pull_request_owner_login = excluded.pull_request_owner_login,
                pull_request_owner_url = excluded.pull_request_owner_url,
                pull_request_status = excluded.pull_request_status,
                pull_request_branch = excluded.pull_request_branch,
                pull_request_is_stale = excluded.pull_request_is_stale,
                current_directory = excluded.current_directory,
                is_dirty = excluded.is_dirty,
                ticket_ids_json = excluded.ticket_ids_json,
                ticket_links_json = excluded.ticket_links_json,
                project_links_json = excluded.project_links_json,
                current_work_summary = excluded.current_work_summary,
                last_submitted_prompt = excluded.last_submitted_prompt,
                last_submitted_prompt_submitted_at_seconds = excluded.last_submitted_prompt_submitted_at_seconds,
                last_submitted_prompt_session_id = excluded.last_submitted_prompt_session_id,
                cleared_fields_json = excluded.cleared_fields_json,
                field_metadata_json = excluded.field_metadata_json,
                latest_event_id = excluded.latest_event_id,
                latest_event_sequence = excluded.latest_event_sequence,
                observed_at_seconds = excluded.observed_at_seconds,
                updated_at_seconds = excluded.updated_at_seconds
            """
        )
        defer { upsert.finalize() }

        try upsert.bind(merged.id, at: 1)
        try upsert.bind(merged.workspaceID, at: 2)
        try upsert.bind(merged.repositoryID, at: 3)
        try upsert.bind(merged.worktreeID, at: 4)
        try upsert.bind(merged.title, at: 5)
        try upsert.bind(merged.titleSource, at: 6)
        try upsert.bind(merged.branch, at: 7)
        if let pullRequestNumber = merged.pullRequestNumber {
            try upsert.bind(pullRequestNumber, at: 8)
        } else {
            try upsert.bind(nil as String?, at: 8)
        }
        try upsert.bind(merged.pullRequestURL, at: 9)
        try upsert.bind(merged.pullRequestOwnerLogin, at: 10)
        try upsert.bind(merged.pullRequestOwnerURL, at: 11)
        try upsert.bind(merged.pullRequestStatus, at: 12)
        try upsert.bind(merged.pullRequestBranch, at: 13)
        try upsert.bind(merged.pullRequestIsStale ? 1 : 0, at: 14)
        try upsert.bind(merged.currentDirectory, at: 15)
        if let isDirty = merged.isDirty {
            try upsert.bind(isDirty ? 1 : 0, at: 16)
        } else {
            try upsert.bind(nil as String?, at: 16)
        }
        try upsert.bind(ticketIDsJSON, at: 17)
        try upsert.bind(ticketLinksJSON, at: 18)
        try upsert.bind(projectLinksJSON, at: 19)
        try upsert.bind(merged.currentWorkSummary, at: 20)
        try upsert.bind(merged.lastSubmittedPrompt, at: 21)
        try upsert.bind(merged.lastSubmittedPromptSubmittedAt?.timeIntervalSince1970, at: 22)
        try upsert.bind(merged.lastSubmittedPromptSessionID, at: 23)
        try upsert.bind(clearedFieldsJSON, at: 24)
        try upsert.bind(fieldMetadataJSON, at: 25)
        try upsert.bind(merged.latestEventID, at: 26)
        if let latestEventSequence = merged.latestEventSequence {
            try upsert.bind(latestEventSequence, at: 27)
        } else {
            try upsert.bind(nil as String?, at: 27)
        }
        try upsert.bind(merged.observedAt.timeIntervalSince1970, at: 28)
        try upsert.bind(merged.updatedAt.timeIntervalSince1970, at: 29)

        _ = try upsert.step()
    }

    private func mergedWorkspaceDisplay(
        _ incoming: ProvenanceWorkspaceDisplayRecord,
        event: ProvenanceEvent,
        latestEventSequence: Int?
    ) throws -> ProvenanceWorkspaceDisplayRecord {
        let existing = try workspaceDisplay(workspaceID: incoming.workspaceID)
        let requestedClears = Set(incoming.clearedFields)
        var clearedFields = Set(existing?.clearedFields ?? [])
        var fieldMetadata = existing?.fieldMetadata ?? incoming.fieldMetadata

        func metadata(fieldName: String, explicitlyCleared: Bool) -> ProvenanceWorkspaceDisplayFieldMetadataRecord {
            ProvenanceWorkspaceDisplayFieldMetadataRecord(
                fieldName: fieldName,
                observedAt: incoming.observedAt,
                source: event.source,
                evidenceOrigin: event.evidenceOrigin,
                evidenceEventID: event.id,
                evidenceEventSequence: latestEventSequence,
                freshness: explicitlyCleared ? "explicitly_cleared" : "current",
                isExplicitlyCleared: explicitlyCleared
            )
        }

        func markUpdated(_ fieldName: String) {
            clearedFields.remove(fieldName)
            fieldMetadata[fieldName] = metadata(fieldName: fieldName, explicitlyCleared: false)
        }

        func markCleared(_ fieldName: String) {
            clearedFields.insert(fieldName)
            fieldMetadata[fieldName] = metadata(fieldName: fieldName, explicitlyCleared: true)
        }

        func stringField(_ fieldName: String, incomingValue: String?, existingValue: String?) -> String? {
            if requestedClears.contains(fieldName) {
                markCleared(fieldName)
                return nil
            }
            guard let incomingValue else { return existingValue }
            markUpdated(fieldName)
            return incomingValue
        }

        func intField(_ fieldName: String, incomingValue: Int?, existingValue: Int?) -> Int? {
            if requestedClears.contains(fieldName) {
                markCleared(fieldName)
                return nil
            }
            guard let incomingValue else { return existingValue }
            markUpdated(fieldName)
            return incomingValue
        }

        func boolField(_ fieldName: String, incomingValue: Bool?, existingValue: Bool?) -> Bool? {
            if requestedClears.contains(fieldName) {
                markCleared(fieldName)
                return nil
            }
            guard let incomingValue else { return existingValue }
            markUpdated(fieldName)
            return incomingValue
        }

        let clearsPullRequest = requestedClears.contains("pull_request")
        let pullRequestNumber: Int?
        let pullRequestURL: String?
        let pullRequestOwnerLogin: String?
        let pullRequestOwnerURL: String?
        let pullRequestStatus: String?
        let pullRequestBranch: String?
        let pullRequestIsStale: Bool
        if clearsPullRequest {
            for fieldName in [
                "pull_request",
                "pull_request_number",
                "pull_request_url",
                "pull_request_owner_login",
                "pull_request_owner_url",
                "pull_request_status",
                "pull_request_branch",
                "pull_request_is_stale",
            ] {
                markCleared(fieldName)
            }
            pullRequestNumber = nil
            pullRequestURL = nil
            pullRequestOwnerLogin = nil
            pullRequestOwnerURL = nil
            pullRequestStatus = nil
            pullRequestBranch = nil
            pullRequestIsStale = false
        } else {
            pullRequestNumber = intField(
                "pull_request_number",
                incomingValue: incoming.pullRequestNumber,
                existingValue: existing?.pullRequestNumber
            )
            pullRequestURL = stringField(
                "pull_request_url",
                incomingValue: incoming.pullRequestURL,
                existingValue: existing?.pullRequestURL
            )
            pullRequestOwnerLogin = stringField(
                "pull_request_owner_login",
                incomingValue: incoming.pullRequestOwnerLogin,
                existingValue: existing?.pullRequestOwnerLogin
            )
            pullRequestOwnerURL = stringField(
                "pull_request_owner_url",
                incomingValue: incoming.pullRequestOwnerURL,
                existingValue: existing?.pullRequestOwnerURL
            )
            pullRequestStatus = stringField(
                "pull_request_status",
                incomingValue: incoming.pullRequestStatus,
                existingValue: existing?.pullRequestStatus
            )
            pullRequestBranch = stringField(
                "pull_request_branch",
                incomingValue: incoming.pullRequestBranch,
                existingValue: existing?.pullRequestBranch
            )
            let incomingTouchesPullRequest = incoming.pullRequestNumber != nil
                || incoming.pullRequestURL != nil
                || incoming.pullRequestOwnerLogin != nil
                || incoming.pullRequestOwnerURL != nil
                || incoming.pullRequestStatus != nil
                || incoming.pullRequestBranch != nil
                || incoming.pullRequestIsStale
            if incomingTouchesPullRequest {
                markUpdated("pull_request_is_stale")
                pullRequestIsStale = incoming.pullRequestIsStale
            } else {
                pullRequestIsStale = existing?.pullRequestIsStale ?? incoming.pullRequestIsStale
            }
        }

        let ticketFacts: (ids: [String], links: [ProvenanceWorkspaceDisplayTicketLinkRecord])
        if requestedClears.contains("tickets")
            || requestedClears.contains("ticket_ids")
            || requestedClears.contains("ticket_links") {
            markCleared("ticket_ids")
            markCleared("ticket_links")
            ticketFacts = ([], [])
        } else if !incoming.ticketIDs.isEmpty || !incoming.ticketLinks.isEmpty {
            if !incoming.ticketIDs.isEmpty { markUpdated("ticket_ids") }
            if !incoming.ticketLinks.isEmpty { markUpdated("ticket_links") }
            ticketFacts = mergedTicketFacts(
                existingIDs: existing?.ticketIDs ?? [],
                incomingIDs: incoming.ticketIDs,
                existingLinks: existing?.ticketLinks ?? [],
                incomingLinks: incoming.ticketLinks
            )
        } else {
            ticketFacts = (existing?.ticketIDs ?? incoming.ticketIDs, existing?.ticketLinks ?? incoming.ticketLinks)
        }

        let projectLinks: [ProvenanceWorkspaceDisplayProjectLinkRecord]
        if requestedClears.contains("projects")
            || requestedClears.contains("project_links") {
            markCleared("project_links")
            projectLinks = []
        } else if !incoming.projectLinks.isEmpty {
            markUpdated("project_links")
            projectLinks = mergedProjectLinks(
                existingLinks: existing?.projectLinks ?? [],
                incomingLinks: incoming.projectLinks
            )
        } else {
            projectLinks = existing?.projectLinks ?? incoming.projectLinks
        }

        let lastSubmittedPrompt: String?
        let lastSubmittedPromptSubmittedAt: Date?
        let lastSubmittedPromptSessionID: String?
        if requestedClears.contains("last_submitted_prompt") {
            markCleared("last_submitted_prompt")
            markCleared("last_submitted_prompt_submitted_at")
            markCleared("last_submitted_prompt_session_id")
            lastSubmittedPrompt = nil
            lastSubmittedPromptSubmittedAt = nil
            lastSubmittedPromptSessionID = nil
        } else if let incomingPrompt = incoming.lastSubmittedPrompt {
            markUpdated("last_submitted_prompt")
            markUpdated("last_submitted_prompt_submitted_at")
            if incoming.lastSubmittedPromptSessionID != nil {
                markUpdated("last_submitted_prompt_session_id")
            }
            lastSubmittedPrompt = incomingPrompt
            lastSubmittedPromptSubmittedAt = incoming.lastSubmittedPromptSubmittedAt ?? incoming.observedAt
            lastSubmittedPromptSessionID = incoming.lastSubmittedPromptSessionID
                ?? existing?.lastSubmittedPromptSessionID
        } else {
            lastSubmittedPrompt = existing?.lastSubmittedPrompt
            lastSubmittedPromptSubmittedAt = existing?.lastSubmittedPromptSubmittedAt
            lastSubmittedPromptSessionID = existing?.lastSubmittedPromptSessionID
        }

        return ProvenanceWorkspaceDisplayRecord(
            id: incoming.id,
            workspaceID: incoming.workspaceID,
            repositoryID: stringField(
                "repository_id",
                incomingValue: incoming.repositoryID,
                existingValue: existing?.repositoryID
            ),
            worktreeID: stringField(
                "worktree_id",
                incomingValue: incoming.worktreeID,
                existingValue: existing?.worktreeID
            ),
            currentDirectory: stringField(
                "current_directory",
                incomingValue: incoming.currentDirectory,
                existingValue: existing?.currentDirectory
            ),
            title: stringField("title", incomingValue: incoming.title, existingValue: existing?.title),
            titleSource: stringField(
                "title_source",
                incomingValue: incoming.titleSource,
                existingValue: existing?.titleSource
            ),
            branch: stringField("branch", incomingValue: incoming.branch, existingValue: existing?.branch),
            pullRequestNumber: pullRequestNumber,
            pullRequestURL: pullRequestURL,
            pullRequestOwnerLogin: pullRequestOwnerLogin,
            pullRequestOwnerURL: pullRequestOwnerURL,
            pullRequestStatus: pullRequestStatus,
            pullRequestBranch: pullRequestBranch,
            pullRequestIsStale: pullRequestIsStale,
            isDirty: boolField("is_dirty", incomingValue: incoming.isDirty, existingValue: existing?.isDirty),
            ticketIDs: ticketFacts.ids,
            ticketLinks: ticketFacts.links,
            projectLinks: projectLinks,
            currentWorkSummary: stringField(
                "current_work_summary",
                incomingValue: incoming.currentWorkSummary,
                existingValue: existing?.currentWorkSummary
            ),
            lastSubmittedPrompt: lastSubmittedPrompt,
            lastSubmittedPromptSubmittedAt: lastSubmittedPromptSubmittedAt,
            lastSubmittedPromptSessionID: lastSubmittedPromptSessionID,
            clearedFields: clearedFields.sorted(),
            fieldMetadata: fieldMetadata,
            latestEventID: incoming.latestEventID ?? event.id,
            latestEventSequence: incoming.latestEventSequence ?? latestEventSequence,
            observedAt: incoming.observedAt,
            updatedAt: incoming.updatedAt
        )
    }

    private func mergedProjectLinks(
        existingLinks: [ProvenanceWorkspaceDisplayProjectLinkRecord],
        incomingLinks: [ProvenanceWorkspaceDisplayProjectLinkRecord]
    ) -> [ProvenanceWorkspaceDisplayProjectLinkRecord] {
        let existingByID = workspaceDisplayProjectLinksByID(existingLinks)
        let incomingByID = workspaceDisplayProjectLinksByID(incomingLinks)
        let ids = uniqueWorkspaceDisplayIDs((existingLinks + incomingLinks).map(\.id))
        return ids.compactMap { id -> ProvenanceWorkspaceDisplayProjectLinkRecord? in
            guard let existing = existingByID[id] ?? incomingByID[id] else { return nil }
            let incoming = incomingByID[id]
            return ProvenanceWorkspaceDisplayProjectLinkRecord(
                id: id,
                system: incoming?.system ?? existing.system,
                title: incoming?.title ?? existing.title,
                url: incoming?.url ?? existing.url
            )
        }
    }

    private func workspaceDisplayProjectLinksByID(
        _ links: [ProvenanceWorkspaceDisplayProjectLinkRecord]
    ) -> [String: ProvenanceWorkspaceDisplayProjectLinkRecord] {
        links.reduce(into: [:]) { result, link in
            let trimmedID = link.id.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedID.isEmpty else { return }
            result[trimmedID] = link
        }
    }

    private func mergedTicketFacts(
        existingIDs: [String],
        incomingIDs: [String],
        existingLinks: [ProvenanceWorkspaceDisplayTicketLinkRecord],
        incomingLinks: [ProvenanceWorkspaceDisplayTicketLinkRecord]
    ) -> (ids: [String], links: [ProvenanceWorkspaceDisplayTicketLinkRecord]) {
        let normalizedIncomingIDs = uniqueWorkspaceDisplayIDs(incomingIDs)
        let normalizedExistingIDs = uniqueWorkspaceDisplayIDs(existingIDs)
        let incomingLinkIDs = uniqueWorkspaceDisplayIDs(incomingLinks.map(\.id))
        let ids: [String]
        if !normalizedIncomingIDs.isEmpty {
            ids = normalizedIncomingIDs
        } else if !normalizedExistingIDs.isEmpty {
            ids = normalizedExistingIDs
        } else {
            ids = incomingLinkIDs
        }

        var linkOrder = ids
        let targetIDs = Set(ids)
        for link in existingLinks + incomingLinks {
            let trimmedID = link.id.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedID.isEmpty else { continue }
            guard normalizedIncomingIDs.isEmpty || targetIDs.contains(trimmedID) else { continue }
            if !linkOrder.contains(trimmedID) {
                linkOrder.append(trimmedID)
            }
        }

        let existingByID = workspaceDisplayTicketLinksByID(existingLinks)
        let incomingByID = workspaceDisplayTicketLinksByID(incomingLinks)
        let links = linkOrder.compactMap { id -> ProvenanceWorkspaceDisplayTicketLinkRecord? in
            guard let existing = existingByID[id] ?? incomingByID[id] else { return nil }
            let incoming = incomingByID[id]
            return ProvenanceWorkspaceDisplayTicketLinkRecord(
                id: id,
                system: incoming?.system ?? existing.system,
                title: incoming?.title ?? existing.title,
                url: incoming?.url ?? existing.url,
                ownerName: incoming?.ownerName ?? existing.ownerName,
                ownerURL: incoming?.ownerURL ?? existing.ownerURL
            )
        }
        return (ids, links)
    }

    private func workspaceDisplayTicketLinksByID(
        _ links: [ProvenanceWorkspaceDisplayTicketLinkRecord]
    ) -> [String: ProvenanceWorkspaceDisplayTicketLinkRecord] {
        links.reduce(into: [:]) { result, link in
            let trimmedID = link.id.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedID.isEmpty else { return }
            result[trimmedID] = link
        }
    }

    private func uniqueWorkspaceDisplayIDs(_ ids: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for id in ids {
            let trimmedID = id.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedID.isEmpty, seen.insert(trimmedID).inserted else { continue }
            result.append(trimmedID)
        }
        return result
    }

    private func encodedWorkspaceDisplayJSON<T: Encodable>(
        _ value: T,
        failureMessage: String
    ) throws -> String {
        let data = try payloadEncoder.encode(value)
        guard let json = String(data: data, encoding: .utf8) else {
            throw ProvenanceSQLiteError.sqlite(message: failureMessage)
        }
        return json
    }

    private func encodedSemanticJSON<T: Encodable>(
        _ value: T,
        failureMessage: String
    ) throws -> String {
        let data = try payloadEncoder.encode(value)
        guard let json = String(data: data, encoding: .utf8) else {
            throw ProvenanceSQLiteError.sqlite(message: failureMessage)
        }
        return json
    }

    private func decodedSemanticJSON<T: Decodable>(
        _ json: String?,
        as type: T.Type,
        failureMessage: String
    ) throws -> T {
        guard let json,
              let data = json.data(using: .utf8) else {
            throw ProvenanceSQLiteError.sqlite(message: failureMessage)
        }
        return try payloadDecoder.decode(type, from: data)
    }

    private func insertSemanticInference(_ record: ProvenanceSemanticInferenceRecord) throws {
        let payloadJSON = try encodedSemanticJSON(
            record.payload,
            failureMessage: "failed to encode semantic inference payload"
        )
        let evidenceRefsJSON = try encodedSemanticJSON(
            record.supportingEvidenceRefs,
            failureMessage: "failed to encode semantic inference evidence refs"
        )
        let supersedesJSON = try encodedSemanticJSON(
            record.supersedes,
            failureMessage: "failed to encode superseded semantic inference ids"
        )
        let insert = try database.prepare(
            """
            INSERT INTO provenance_semantic_inferences (
                id,
                schema_version,
                inference_kind,
                scope,
                scope_id,
                payload_json,
                supporting_evidence_refs_json,
                supporting_factual_revision,
                confidence,
                specificity,
                producer_type,
                producer_id,
                producer_version,
                created_at_seconds,
                supersedes_json,
                superseded_by,
                status
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """
        )
        defer { insert.finalize() }

        try insert.bind(record.id, at: 1)
        try insert.bind(record.schemaVersion, at: 2)
        try insert.bind(record.kind, at: 3)
        try insert.bind(record.scope.rawValue, at: 4)
        try insert.bind(record.scopeID, at: 5)
        try insert.bind(payloadJSON, at: 6)
        try insert.bind(evidenceRefsJSON, at: 7)
        try insert.bind(record.supportingFactualRevision.map(Double.init), at: 8)
        try insert.bind(record.confidence.rawValue, at: 9)
        try insert.bind(record.specificity.rawValue, at: 10)
        try insert.bind(record.producerType.rawValue, at: 11)
        try insert.bind(record.producerID, at: 12)
        try insert.bind(record.producerVersion, at: 13)
        try insert.bind(record.createdAt.timeIntervalSince1970, at: 14)
        try insert.bind(supersedesJSON, at: 15)
        try insert.bind(record.supersededBy, at: 16)
        try insert.bind(record.status.rawValue, at: 17)

        _ = try insert.step()
    }

    private func supersedeSemanticInference(
        id: String,
        replacement: ProvenanceSemanticInferenceRecord
    ) throws {
        let update = try database.prepare(
            """
            UPDATE provenance_semantic_inferences
            SET status = 'superseded',
                superseded_by = ?
            WHERE id = ?
              AND inference_kind = ?
              AND scope = ?
              AND scope_id = ?
            """
        )
        defer { update.finalize() }

        try update.bind(replacement.id, at: 1)
        try update.bind(id, at: 2)
        try update.bind(replacement.kind, at: 3)
        try update.bind(replacement.scope.rawValue, at: 4)
        try update.bind(replacement.scopeID, at: 5)
        _ = try update.step()
        guard database.changes == 1 else {
            throw ProvenanceSQLiteError.sqlite(
                message: "semantic inference '\(id)' cannot be superseded because it does not exist in the replacement scope"
            )
        }
    }

    private func semanticInference(
        from query: ProvenanceSQLiteStatement
    ) throws -> ProvenanceSemanticInferenceRecord {
        guard let id = query.string(at: 0),
              let kind = query.string(at: 2),
              let scopeRawValue = query.string(at: 3),
              let scope = ProvenanceSemanticInferenceScope(rawValue: scopeRawValue),
              let scopeID = query.string(at: 4),
              let confidenceRawValue = query.string(at: 8),
              let confidence = ProvenanceConfidence(rawValue: confidenceRawValue),
              let specificityRawValue = query.string(at: 9),
              let specificity = ProvenanceSemanticSpecificity(rawValue: specificityRawValue),
              let producerTypeRawValue = query.string(at: 10),
              let producerType = ProvenanceSemanticInferenceProducerType(rawValue: producerTypeRawValue),
              let producerID = query.string(at: 11),
              let producerVersion = query.string(at: 12),
              let statusRawValue = query.string(at: 16),
              let status = ProvenanceSemanticInferenceStatus(rawValue: statusRawValue) else {
            throw ProvenanceSQLiteError.sqlite(message: "stored semantic inference has invalid scalar fields")
        }

        let payload = try decodedSemanticJSON(
            query.string(at: 5),
            as: ProvenanceSemanticPayloadValue.self,
            failureMessage: "stored semantic inference has invalid payload"
        )
        let evidenceRefs = try decodedSemanticJSON(
            query.string(at: 6),
            as: [ProvenanceSemanticEvidenceReference].self,
            failureMessage: "stored semantic inference has invalid evidence refs"
        )
        let supersedes = try decodedSemanticJSON(
            query.string(at: 14),
            as: [String].self,
            failureMessage: "stored semantic inference has invalid supersession ids"
        )

        return ProvenanceSemanticInferenceRecord(
            id: id,
            schemaVersion: query.int(at: 1),
            kind: kind,
            scope: scope,
            scopeID: scopeID,
            payload: payload,
            supportingEvidenceRefs: evidenceRefs,
            supportingFactualRevision: query.double(at: 7).map(Int.init),
            confidence: confidence,
            specificity: specificity,
            producerType: producerType,
            producerID: producerID,
            producerVersion: producerVersion,
            createdAt: Date(timeIntervalSince1970: query.double(at: 13) ?? 0),
            supersedes: supersedes,
            supersededBy: query.string(at: 15),
            status: status
        )
    }

    private func insertSemanticMessage(_ record: ProvenanceSemanticMessageRecord) throws {
        let structuredPayloadJSON = try encodedSemanticJSON(
            record.structuredSemanticPayload,
            failureMessage: "failed to encode semantic message structured payload"
        )
        let evidenceRefsJSON = try encodedSemanticJSON(
            record.supportingEvidenceRefs,
            failureMessage: "failed to encode semantic message evidence refs"
        )
        let supersedesJSON = try encodedSemanticJSON(
            record.supersedes,
            failureMessage: "failed to encode superseded semantic message ids"
        )
        let insert = try database.prepare(
            """
            INSERT INTO provenance_semantic_messages (
                id,
                schema_version,
                semantic_inference_id,
                semantic_inference_kind,
                scope,
                scope_id,
                concise_phrase,
                expanded_meaning,
                structured_semantic_payload_json,
                supporting_evidence_refs_json,
                supporting_factual_revision,
                confidence,
                specificity,
                presentation_producer_type,
                presentation_producer_id,
                presentation_producer_version,
                presentation_policy_id,
                presentation_policy_version,
                locale_identifier,
                created_at_seconds,
                supersedes_json,
                superseded_by,
                status
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """
        )
        defer { insert.finalize() }

        try insert.bind(record.id, at: 1)
        try insert.bind(record.schemaVersion, at: 2)
        try insert.bind(record.semanticInferenceID, at: 3)
        try insert.bind(record.semanticInferenceKind, at: 4)
        try insert.bind(record.scope.rawValue, at: 5)
        try insert.bind(record.scopeID, at: 6)
        try insert.bind(record.concisePhrase, at: 7)
        try insert.bind(record.expandedMeaning, at: 8)
        try insert.bind(structuredPayloadJSON, at: 9)
        try insert.bind(evidenceRefsJSON, at: 10)
        try insert.bind(record.supportingFactualRevision.map(Double.init), at: 11)
        try insert.bind(record.confidence.rawValue, at: 12)
        try insert.bind(record.specificity.rawValue, at: 13)
        try insert.bind(record.presentationProducerType.rawValue, at: 14)
        try insert.bind(record.presentationProducerID, at: 15)
        try insert.bind(record.presentationProducerVersion, at: 16)
        try insert.bind(record.presentationPolicyID, at: 17)
        try insert.bind(record.presentationPolicyVersion, at: 18)
        try insert.bind(record.localeIdentifier, at: 19)
        try insert.bind(record.createdAt.timeIntervalSince1970, at: 20)
        try insert.bind(supersedesJSON, at: 21)
        try insert.bind(record.supersededBy, at: 22)
        try insert.bind(record.status.rawValue, at: 23)

        _ = try insert.step()
    }

    private func supersedeSemanticMessage(
        id: String,
        replacement: ProvenanceSemanticMessageRecord
    ) throws {
        let update = try database.prepare(
            """
            UPDATE provenance_semantic_messages
            SET status = 'superseded',
                superseded_by = ?
            WHERE id = ?
              AND semantic_inference_kind = ?
              AND scope = ?
              AND scope_id = ?
              AND presentation_policy_id = ?
            """
        )
        defer { update.finalize() }

        try update.bind(replacement.id, at: 1)
        try update.bind(id, at: 2)
        try update.bind(replacement.semanticInferenceKind, at: 3)
        try update.bind(replacement.scope.rawValue, at: 4)
        try update.bind(replacement.scopeID, at: 5)
        try update.bind(replacement.presentationPolicyID, at: 6)
        _ = try update.step()
        guard database.changes == 1 else {
            throw ProvenanceSQLiteError.sqlite(
                message: "semantic message '\(id)' cannot be superseded because it does not exist in the replacement scope and policy"
            )
        }
    }

    private func semanticMessage(
        from query: ProvenanceSQLiteStatement
    ) throws -> ProvenanceSemanticMessageRecord {
        guard let id = query.string(at: 0),
              let semanticInferenceID = query.string(at: 2),
              let semanticInferenceKind = query.string(at: 3),
              let scopeRawValue = query.string(at: 4),
              let scope = ProvenanceSemanticInferenceScope(rawValue: scopeRawValue),
              let scopeID = query.string(at: 5),
              let concisePhrase = query.string(at: 6),
              let expandedMeaning = query.string(at: 7),
              let confidenceRawValue = query.string(at: 11),
              let confidence = ProvenanceConfidence(rawValue: confidenceRawValue),
              let specificityRawValue = query.string(at: 12),
              let specificity = ProvenanceSemanticSpecificity(rawValue: specificityRawValue),
              let producerTypeRawValue = query.string(at: 13),
              let producerType = ProvenanceSemanticInferenceProducerType(rawValue: producerTypeRawValue),
              let producerID = query.string(at: 14),
              let producerVersion = query.string(at: 15),
              let policyID = query.string(at: 16),
              let policyVersion = query.string(at: 17),
              let statusRawValue = query.string(at: 22),
              let status = ProvenanceSemanticMessageStatus(rawValue: statusRawValue) else {
            throw ProvenanceSQLiteError.sqlite(message: "stored semantic message has invalid scalar fields")
        }

        let payload = try decodedSemanticJSON(
            query.string(at: 8),
            as: ProvenanceSemanticPayloadValue.self,
            failureMessage: "stored semantic message has invalid structured payload"
        )
        let evidenceRefs = try decodedSemanticJSON(
            query.string(at: 9),
            as: [ProvenanceSemanticEvidenceReference].self,
            failureMessage: "stored semantic message has invalid evidence refs"
        )
        let supersedes = try decodedSemanticJSON(
            query.string(at: 20),
            as: [String].self,
            failureMessage: "stored semantic message has invalid supersession ids"
        )

        return ProvenanceSemanticMessageRecord(
            id: id,
            schemaVersion: query.int(at: 1),
            semanticInferenceID: semanticInferenceID,
            semanticInferenceKind: semanticInferenceKind,
            scope: scope,
            scopeID: scopeID,
            concisePhrase: concisePhrase,
            expandedMeaning: expandedMeaning,
            structuredSemanticPayload: payload,
            supportingEvidenceRefs: evidenceRefs,
            supportingFactualRevision: query.double(at: 10).map(Int.init),
            confidence: confidence,
            specificity: specificity,
            presentationProducerType: producerType,
            presentationProducerID: producerID,
            presentationProducerVersion: producerVersion,
            presentationPolicyID: policyID,
            presentationPolicyVersion: policyVersion,
            localeIdentifier: query.string(at: 18),
            createdAt: Date(timeIntervalSince1970: query.double(at: 19) ?? 0),
            supersedes: supersedes,
            supersededBy: query.string(at: 21),
            status: status
        )
    }

    private func upsertCodingAgentThread(_ thread: ProvenanceCodingAgentThreadRecord) throws {
        let upsert = try database.prepare(
            """
            INSERT INTO provenance_coding_agent_threads (
                id,
                session_id,
                provider,
                provider_thread_id,
                worktree_id,
                source,
                confidence,
                first_observed_at_seconds,
                updated_at_seconds
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                session_id = excluded.session_id,
                provider = excluded.provider,
                provider_thread_id = excluded.provider_thread_id,
                worktree_id = excluded.worktree_id,
                source = excluded.source,
                confidence = excluded.confidence,
                updated_at_seconds = excluded.updated_at_seconds
            """
        )
        defer { upsert.finalize() }

        try upsert.bind(thread.id, at: 1)
        try upsert.bind(thread.sessionID, at: 2)
        try upsert.bind(thread.provider, at: 3)
        try upsert.bind(thread.providerThreadID, at: 4)
        try upsert.bind(thread.worktreeID, at: 5)
        try upsert.bind(thread.source.rawValue, at: 6)
        try upsert.bind(thread.confidence.rawValue, at: 7)
        try upsert.bind(thread.firstObservedAt.timeIntervalSince1970, at: 8)
        try upsert.bind(thread.updatedAt.timeIntervalSince1970, at: 9)

        _ = try upsert.step()
    }

    private func upsertCodingAgentTurn(_ turn: ProvenanceCodingAgentTurnRecord) throws {
        let existing = try codingAgentTurn(id: turn.id)
        let startedAt = turn.startedAt ?? existing?.startedAt
        let upsert = try database.prepare(
            """
            INSERT INTO provenance_coding_agent_turns (
                id,
                session_id,
                thread_id,
                provider,
                provider_turn_id,
                status,
                model,
                effort,
                started_at_seconds,
                completed_at_seconds,
                updated_at_seconds,
                source,
                confidence
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                session_id = excluded.session_id,
                thread_id = excluded.thread_id,
                provider = excluded.provider,
                provider_turn_id = excluded.provider_turn_id,
                status = excluded.status,
                model = COALESCE(excluded.model, provenance_coding_agent_turns.model),
                effort = COALESCE(excluded.effort, provenance_coding_agent_turns.effort),
                started_at_seconds = COALESCE(excluded.started_at_seconds, provenance_coding_agent_turns.started_at_seconds),
                completed_at_seconds = excluded.completed_at_seconds,
                updated_at_seconds = excluded.updated_at_seconds,
                source = excluded.source,
                confidence = excluded.confidence
            """
        )
        defer { upsert.finalize() }

        try upsert.bind(turn.id, at: 1)
        try upsert.bind(turn.sessionID, at: 2)
        try upsert.bind(turn.threadID, at: 3)
        try upsert.bind(turn.provider, at: 4)
        try upsert.bind(turn.providerTurnID, at: 5)
        try upsert.bind(turn.status, at: 6)
        try upsert.bind(turn.model, at: 7)
        try upsert.bind(turn.effort, at: 8)
        try upsert.bind(startedAt?.timeIntervalSince1970, at: 9)
        try upsert.bind(turn.completedAt?.timeIntervalSince1970, at: 10)
        try upsert.bind(turn.updatedAt.timeIntervalSince1970, at: 11)
        try upsert.bind(turn.source.rawValue, at: 12)
        try upsert.bind(turn.confidence.rawValue, at: 13)

        _ = try upsert.step()
    }

    private func upsertCodingAgentPrompt(_ prompt: ProvenanceCodingAgentPromptRecord) throws {
        let upsert = try database.prepare(
            """
            INSERT INTO provenance_coding_agent_prompts (
                id,
                session_id,
                thread_id,
                turn_id,
                provider,
                text,
                submitted_at_seconds,
                source,
                confidence
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                session_id = excluded.session_id,
                thread_id = excluded.thread_id,
                turn_id = excluded.turn_id,
                provider = excluded.provider,
                text = excluded.text,
                submitted_at_seconds = excluded.submitted_at_seconds,
                source = excluded.source,
                confidence = excluded.confidence
            """
        )
        defer { upsert.finalize() }

        try upsert.bind(prompt.id, at: 1)
        try upsert.bind(prompt.sessionID, at: 2)
        try upsert.bind(prompt.threadID, at: 3)
        try upsert.bind(prompt.turnID, at: 4)
        try upsert.bind(prompt.provider, at: 5)
        try upsert.bind(prompt.text, at: 6)
        try upsert.bind(prompt.submittedAt.timeIntervalSince1970, at: 7)
        try upsert.bind(prompt.source.rawValue, at: 8)
        try upsert.bind(prompt.confidence.rawValue, at: 9)

        _ = try upsert.step()
    }

    private func upsertCodingAgentPlanUpdate(_ planUpdate: ProvenanceCodingAgentPlanUpdateRecord) throws {
        let stepsJSON = try encodedWorkspaceDisplayJSON(
            planUpdate.steps,
            failureMessage: "failed to encode coding-agent plan steps"
        )
        let upsert = try database.prepare(
            """
            INSERT INTO provenance_coding_agent_plan_updates (
                id,
                session_id,
                thread_id,
                turn_id,
                provider,
                explanation,
                steps_json,
                observed_at_seconds,
                source,
                confidence
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                session_id = excluded.session_id,
                thread_id = excluded.thread_id,
                turn_id = excluded.turn_id,
                provider = excluded.provider,
                explanation = excluded.explanation,
                steps_json = excluded.steps_json,
                observed_at_seconds = excluded.observed_at_seconds,
                source = excluded.source,
                confidence = excluded.confidence
            """
        )
        defer { upsert.finalize() }

        try upsert.bind(planUpdate.id, at: 1)
        try upsert.bind(planUpdate.sessionID, at: 2)
        try upsert.bind(planUpdate.threadID, at: 3)
        try upsert.bind(planUpdate.turnID, at: 4)
        try upsert.bind(planUpdate.provider, at: 5)
        try upsert.bind(planUpdate.explanation, at: 6)
        try upsert.bind(stepsJSON, at: 7)
        try upsert.bind(planUpdate.observedAt.timeIntervalSince1970, at: 8)
        try upsert.bind(planUpdate.source.rawValue, at: 9)
        try upsert.bind(planUpdate.confidence.rawValue, at: 10)

        _ = try upsert.step()
    }

    private func upsertCodingAgentCommand(_ command: ProvenanceCodingAgentCommandRecord) throws {
        let upsert = try database.prepare(
            """
            INSERT INTO provenance_coding_agent_commands (
                id,
                session_id,
                thread_id,
                turn_id,
                provider,
                operation_id,
                command_text,
                cwd,
                status,
                exit_code,
                output_summary,
                started_at_seconds,
                completed_at_seconds,
                source,
                confidence
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                session_id = excluded.session_id,
                thread_id = excluded.thread_id,
                turn_id = excluded.turn_id,
                provider = excluded.provider,
                operation_id = excluded.operation_id,
                command_text = excluded.command_text,
                cwd = excluded.cwd,
                status = excluded.status,
                exit_code = excluded.exit_code,
                output_summary = excluded.output_summary,
                started_at_seconds = excluded.started_at_seconds,
                completed_at_seconds = excluded.completed_at_seconds,
                source = excluded.source,
                confidence = excluded.confidence
            """
        )
        defer { upsert.finalize() }

        try upsert.bind(command.id, at: 1)
        try upsert.bind(command.sessionID, at: 2)
        try upsert.bind(command.threadID, at: 3)
        try upsert.bind(command.turnID, at: 4)
        try upsert.bind(command.provider, at: 5)
        try upsert.bind(command.operationID, at: 6)
        try upsert.bind(command.command, at: 7)
        try upsert.bind(command.cwd, at: 8)
        try upsert.bind(command.status, at: 9)
        if let exitCode = command.exitCode {
            try upsert.bind(exitCode, at: 10)
        } else {
            try upsert.bind(nil as String?, at: 10)
        }
        try upsert.bind(command.outputSummary, at: 11)
        try upsert.bind(command.startedAt?.timeIntervalSince1970, at: 12)
        try upsert.bind(command.completedAt.timeIntervalSince1970, at: 13)
        try upsert.bind(command.source.rawValue, at: 14)
        try upsert.bind(command.confidence.rawValue, at: 15)

        _ = try upsert.step()
    }

    private func upsertCodingAgentReasoningSummary(_ summary: ProvenanceCodingAgentReasoningSummaryRecord) throws {
        let upsert = try database.prepare(
            """
            INSERT INTO provenance_coding_agent_reasoning_summaries (
                id,
                session_id,
                thread_id,
                turn_id,
                provider,
                item_id,
                text,
                completed_at_seconds,
                source,
                confidence
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                session_id = excluded.session_id,
                thread_id = excluded.thread_id,
                turn_id = excluded.turn_id,
                provider = excluded.provider,
                item_id = excluded.item_id,
                text = excluded.text,
                completed_at_seconds = excluded.completed_at_seconds,
                source = excluded.source,
                confidence = excluded.confidence
            """
        )
        defer { upsert.finalize() }

        try upsert.bind(summary.id, at: 1)
        try upsert.bind(summary.sessionID, at: 2)
        try upsert.bind(summary.threadID, at: 3)
        try upsert.bind(summary.turnID, at: 4)
        try upsert.bind(summary.provider, at: 5)
        try upsert.bind(summary.itemID, at: 6)
        try upsert.bind(summary.text, at: 7)
        try upsert.bind(summary.completedAt.timeIntervalSince1970, at: 8)
        try upsert.bind(summary.source.rawValue, at: 9)
        try upsert.bind(summary.confidence.rawValue, at: 10)

        _ = try upsert.step()
    }

    private func upsertCodingAgentAssistantMessage(_ message: ProvenanceCodingAgentAssistantMessageRecord) throws {
        let upsert = try database.prepare(
            """
            INSERT INTO provenance_coding_agent_assistant_messages (
                id,
                session_id,
                thread_id,
                turn_id,
                provider,
                item_id,
                text,
                completed_at_seconds,
                source,
                confidence
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                session_id = excluded.session_id,
                thread_id = excluded.thread_id,
                turn_id = excluded.turn_id,
                provider = excluded.provider,
                item_id = excluded.item_id,
                text = excluded.text,
                completed_at_seconds = excluded.completed_at_seconds,
                source = excluded.source,
                confidence = excluded.confidence
            """
        )
        defer { upsert.finalize() }

        try upsert.bind(message.id, at: 1)
        try upsert.bind(message.sessionID, at: 2)
        try upsert.bind(message.threadID, at: 3)
        try upsert.bind(message.turnID, at: 4)
        try upsert.bind(message.provider, at: 5)
        try upsert.bind(message.itemID, at: 6)
        try upsert.bind(message.text, at: 7)
        try upsert.bind(message.completedAt.timeIntervalSince1970, at: 8)
        try upsert.bind(message.source.rawValue, at: 9)
        try upsert.bind(message.confidence.rawValue, at: 10)

        _ = try upsert.step()
    }

    private func upsertCodingAgentFileChangeAttribution(
        _ attribution: ProvenanceCodingAgentFileChangeAttributionRecord
    ) throws {
        let fileChangeIDsJSON = try encodedWorkspaceDisplayJSON(
            attribution.fileChangeIDs,
            failureMessage: "failed to encode coding-agent file-change ids"
        )
        let pathsJSON = try encodedWorkspaceDisplayJSON(
            attribution.paths,
            failureMessage: "failed to encode coding-agent file-change paths"
        )
        let upsert = try database.prepare(
            """
            INSERT INTO provenance_coding_agent_file_change_attributions (
                id,
                session_id,
                thread_id,
                turn_id,
                provider,
                operation_id,
                change_set_id,
                file_change_ids_json,
                paths_json,
                summary,
                observed_at_seconds,
                source,
                confidence
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                session_id = excluded.session_id,
                thread_id = excluded.thread_id,
                turn_id = excluded.turn_id,
                provider = excluded.provider,
                operation_id = excluded.operation_id,
                change_set_id = excluded.change_set_id,
                file_change_ids_json = excluded.file_change_ids_json,
                paths_json = excluded.paths_json,
                summary = excluded.summary,
                observed_at_seconds = excluded.observed_at_seconds,
                source = excluded.source,
                confidence = excluded.confidence
            """
        )
        defer { upsert.finalize() }

        try upsert.bind(attribution.id, at: 1)
        try upsert.bind(attribution.sessionID, at: 2)
        try upsert.bind(attribution.threadID, at: 3)
        try upsert.bind(attribution.turnID, at: 4)
        try upsert.bind(attribution.provider, at: 5)
        try upsert.bind(attribution.operationID, at: 6)
        try upsert.bind(attribution.changeSetID, at: 7)
        try upsert.bind(fileChangeIDsJSON, at: 8)
        try upsert.bind(pathsJSON, at: 9)
        try upsert.bind(attribution.summary, at: 10)
        try upsert.bind(attribution.observedAt.timeIntervalSince1970, at: 11)
        try upsert.bind(attribution.source.rawValue, at: 12)
        try upsert.bind(attribution.confidence.rawValue, at: 13)

        _ = try upsert.step()
    }

    private func insertStorageRepairAttempt(
        _ report: ProvenanceSQLiteStorageRepairReport,
        attemptedAt: Date
    ) throws {
        let insert = try database.prepare(
            """
            INSERT INTO provenance_storage_repair_attempts (
                attempted_at_seconds,
                initial_status,
                repair_recommended,
                repair_attempted,
                repaired,
                replayed_event_count,
                post_repair_status
            ) VALUES (?, ?, ?, ?, ?, ?, ?)
            """
        )
        defer { insert.finalize() }

        let projectionRepairReport = report.projectionRepairReport
        try insert.bind(attemptedAt.timeIntervalSince1970, at: 1)
        try insert.bind(report.initialIntegrityReport.status, at: 2)
        try insert.bind(report.initialIntegrityReport.repairRecommended ? 1 : 0, at: 3)
        try insert.bind(report.repairAttempted ? 1 : 0, at: 4)
        try insert.bind((projectionRepairReport?.repaired ?? false) ? 1 : 0, at: 5)
        try insert.bind(projectionRepairReport?.replayedEventCount ?? 0, at: 6)
        try insert.bind(report.postRepairIntegrityReport?.status, at: 7)

        _ = try insert.step()
    }

    private func lifecycleIdentity(
        for request: ProvenanceSessionLifecycleRequest
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
                kind: identityKind.flatMap { $0.isEmpty ? nil : $0 } ?? "session",
                value: trimmed,
                confidence: .high
            )
        }
        let sessionID = request.sessionID?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let sessionID, !sessionID.isEmpty {
            return (
                kind: "session",
                value: sessionID,
                confidence: .high
            )
        }
        if let parentSessionID = request.parentSessionID?.trimmingCharacters(in: .whitespacesAndNewlines),
           !parentSessionID.isEmpty {
            return (
                kind: "unresolved_session",
                value: "\(request.agentKind):\(parentSessionID):default",
                confidence: .low
            )
        }
        return (
            kind: "unresolved_session",
            value: "\(request.agentKind):default",
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

    static let migrations = [
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
        ProvenanceSQLiteMigration(
            version: 7,
            statements: [
                """
                CREATE TABLE provenance_storage_repair_attempts (
                    sequence INTEGER PRIMARY KEY AUTOINCREMENT,
                    attempted_at_seconds REAL NOT NULL,
                    initial_status TEXT NOT NULL,
                    repair_recommended INTEGER NOT NULL,
                    repair_attempted INTEGER NOT NULL,
                    repaired INTEGER NOT NULL,
                    replayed_event_count INTEGER NOT NULL,
                    post_repair_status TEXT
                )
                """,
                """
                CREATE INDEX provenance_storage_repair_attempts_time_index
                ON provenance_storage_repair_attempts (attempted_at_seconds, sequence)
                """,
                """
                CREATE INDEX provenance_storage_repair_attempts_status_index
                ON provenance_storage_repair_attempts (initial_status, repair_attempted, repaired)
                """,
            ]
        ),
        ProvenanceSQLiteMigration(
            version: 8,
            statements: [
                """
                CREATE TABLE provenance_schema_migrations (
                    sequence INTEGER PRIMARY KEY AUTOINCREMENT,
                    version INTEGER NOT NULL UNIQUE,
                    applied_at_seconds REAL NOT NULL
                )
                """,
                """
                CREATE INDEX provenance_schema_migrations_time_index
                ON provenance_schema_migrations (applied_at_seconds, sequence)
                """,
            ]
        ),
        ProvenanceSQLiteMigration(
            version: 9,
            statements: [
                "ALTER TABLE provenance_events ADD COLUMN evidence_origin TEXT",
                "ALTER TABLE provenance_events ADD COLUMN evidence_scope_json TEXT",
                """
                CREATE INDEX provenance_events_evidence_origin_index
                ON provenance_events (evidence_origin, sequence)
                """,
            ]
        ),
        ProvenanceSQLiteMigration(
            version: 10,
            statements: [
                """
                CREATE TABLE provenance_metadata (
                    key TEXT PRIMARY KEY NOT NULL,
                    value TEXT NOT NULL
                )
                """,
                """
                INSERT INTO provenance_metadata (key, value)
                VALUES
                    ('schema_family', 'provenance-engine'),
                    ('schema_identity_version', '1'),
                    ('schema_version', '10')
                """,
            ]
        ),
        ProvenanceSQLiteMigration(
            version: 11,
            statements: [
                """
                CREATE TABLE provenance_workspace_display (
                    id TEXT PRIMARY KEY NOT NULL,
                    workspace_id TEXT NOT NULL UNIQUE,
                    repository_id TEXT,
                    worktree_id TEXT,
                    title TEXT,
                    title_source TEXT,
                    branch TEXT,
                    pull_request_number INTEGER,
                    pull_request_url TEXT,
                    pull_request_status TEXT,
                    pull_request_branch TEXT,
                    pull_request_is_stale INTEGER NOT NULL,
                    ticket_ids_json TEXT NOT NULL,
                    observed_at_seconds REAL NOT NULL,
                    updated_at_seconds REAL NOT NULL
                )
                """,
                """
                CREATE INDEX provenance_workspace_display_workspace_index
                ON provenance_workspace_display (workspace_id, updated_at_seconds)
                """,
                """
                CREATE INDEX provenance_workspace_display_worktree_index
                ON provenance_workspace_display (worktree_id, updated_at_seconds)
                """,
                """
                UPDATE provenance_metadata
                SET value = '11'
                WHERE key = 'schema_version'
                """,
            ]
        ),
        ProvenanceSQLiteMigration(
            version: 12,
            statements: [
                "ALTER TABLE provenance_workspace_display ADD COLUMN current_directory TEXT",
                "ALTER TABLE provenance_workspace_display ADD COLUMN is_dirty INTEGER",
                "ALTER TABLE provenance_workspace_display ADD COLUMN latest_event_id TEXT",
                "ALTER TABLE provenance_workspace_display ADD COLUMN latest_event_sequence INTEGER",
                """
                UPDATE provenance_metadata
                SET value = '12'
                WHERE key = 'schema_version'
                """,
            ]
        ),
        ProvenanceSQLiteMigration(
            version: 13,
            statements: [
                "ALTER TABLE provenance_workspace_display ADD COLUMN ticket_links_json TEXT NOT NULL DEFAULT '[]'",
                """
                UPDATE provenance_metadata
                SET value = '13'
                WHERE key = 'schema_version'
                """,
            ]
        ),
        ProvenanceSQLiteMigration(
            version: 14,
            statements: [
                "ALTER TABLE provenance_workspace_display ADD COLUMN pull_request_owner_login TEXT",
                "ALTER TABLE provenance_workspace_display ADD COLUMN pull_request_owner_url TEXT",
                """
                UPDATE provenance_metadata
                SET value = '14'
                WHERE key = 'schema_version'
                """,
            ]
        ),
        ProvenanceSQLiteMigration(
            version: 15,
            statements: [
                "ALTER TABLE provenance_workspace_display ADD COLUMN current_work_summary TEXT",
                "ALTER TABLE provenance_workspace_display ADD COLUMN last_submitted_prompt TEXT",
                "ALTER TABLE provenance_workspace_display ADD COLUMN last_submitted_prompt_submitted_at_seconds REAL",
                "ALTER TABLE provenance_workspace_display ADD COLUMN last_submitted_prompt_session_id TEXT",
                "ALTER TABLE provenance_workspace_display ADD COLUMN cleared_fields_json TEXT NOT NULL DEFAULT '[]'",
                "ALTER TABLE provenance_workspace_display ADD COLUMN field_metadata_json TEXT NOT NULL DEFAULT '{}'",
                """
                UPDATE provenance_metadata
                SET value = '15'
                WHERE key = 'schema_version'
                """,
            ]
        ),
        ProvenanceSQLiteMigration(
            version: 16,
            statements: [
                "ALTER TABLE provenance_workspace_display ADD COLUMN project_links_json TEXT NOT NULL DEFAULT '[]'",
                """
                UPDATE provenance_metadata
                SET value = '16'
                WHERE key = 'schema_version'
                """,
            ]
        ),
        ProvenanceSQLiteMigration(
            version: 17,
            statements: [
                """
                CREATE TABLE provenance_coding_agent_threads (
                    id TEXT PRIMARY KEY NOT NULL,
                    session_id TEXT NOT NULL,
                    provider TEXT NOT NULL,
                    provider_thread_id TEXT NOT NULL,
                    worktree_id TEXT,
                    source TEXT NOT NULL,
                    confidence TEXT NOT NULL,
                    first_observed_at_seconds REAL NOT NULL,
                    updated_at_seconds REAL NOT NULL
                )
                """,
                """
                CREATE UNIQUE INDEX provenance_coding_agent_threads_provider_index
                ON provenance_coding_agent_threads (provider, provider_thread_id)
                """,
                """
                CREATE INDEX provenance_coding_agent_threads_session_index
                ON provenance_coding_agent_threads (session_id, updated_at_seconds)
                """,
                """
                CREATE TABLE provenance_coding_agent_turns (
                    id TEXT PRIMARY KEY NOT NULL,
                    session_id TEXT NOT NULL,
                    thread_id TEXT,
                    provider TEXT NOT NULL,
                    provider_turn_id TEXT NOT NULL,
                    status TEXT NOT NULL,
                    model TEXT,
                    effort TEXT,
                    started_at_seconds REAL,
                    completed_at_seconds REAL,
                    updated_at_seconds REAL NOT NULL,
                    source TEXT NOT NULL,
                    confidence TEXT NOT NULL
                )
                """,
                """
                CREATE UNIQUE INDEX provenance_coding_agent_turns_provider_index
                ON provenance_coding_agent_turns (provider, provider_turn_id)
                """,
                """
                CREATE INDEX provenance_coding_agent_turns_session_index
                ON provenance_coding_agent_turns (session_id, updated_at_seconds)
                """,
                """
                CREATE INDEX provenance_coding_agent_turns_thread_index
                ON provenance_coding_agent_turns (thread_id, updated_at_seconds)
                """,
                """
                CREATE TABLE provenance_coding_agent_prompts (
                    id TEXT PRIMARY KEY NOT NULL,
                    session_id TEXT NOT NULL,
                    thread_id TEXT,
                    turn_id TEXT,
                    provider TEXT NOT NULL,
                    text TEXT NOT NULL,
                    submitted_at_seconds REAL NOT NULL,
                    source TEXT NOT NULL,
                    confidence TEXT NOT NULL
                )
                """,
                """
                CREATE INDEX provenance_coding_agent_prompts_session_index
                ON provenance_coding_agent_prompts (session_id, submitted_at_seconds)
                """,
                """
                CREATE INDEX provenance_coding_agent_prompts_turn_index
                ON provenance_coding_agent_prompts (turn_id, submitted_at_seconds)
                """,
                """
                CREATE TABLE provenance_coding_agent_plan_updates (
                    id TEXT PRIMARY KEY NOT NULL,
                    session_id TEXT NOT NULL,
                    thread_id TEXT,
                    turn_id TEXT,
                    provider TEXT NOT NULL,
                    explanation TEXT,
                    steps_json TEXT NOT NULL,
                    observed_at_seconds REAL NOT NULL,
                    source TEXT NOT NULL,
                    confidence TEXT NOT NULL
                )
                """,
                """
                CREATE INDEX provenance_coding_agent_plan_updates_session_index
                ON provenance_coding_agent_plan_updates (session_id, observed_at_seconds)
                """,
                """
                CREATE INDEX provenance_coding_agent_plan_updates_turn_index
                ON provenance_coding_agent_plan_updates (turn_id, observed_at_seconds)
                """,
                """
                CREATE TABLE provenance_coding_agent_commands (
                    id TEXT PRIMARY KEY NOT NULL,
                    session_id TEXT NOT NULL,
                    thread_id TEXT,
                    turn_id TEXT,
                    provider TEXT NOT NULL,
                    operation_id TEXT,
                    command_text TEXT NOT NULL,
                    cwd TEXT,
                    status TEXT NOT NULL,
                    exit_code INTEGER,
                    output_summary TEXT,
                    started_at_seconds REAL,
                    completed_at_seconds REAL NOT NULL,
                    source TEXT NOT NULL,
                    confidence TEXT NOT NULL
                )
                """,
                """
                CREATE INDEX provenance_coding_agent_commands_session_index
                ON provenance_coding_agent_commands (session_id, completed_at_seconds)
                """,
                """
                CREATE INDEX provenance_coding_agent_commands_turn_index
                ON provenance_coding_agent_commands (turn_id, completed_at_seconds)
                """,
                """
                CREATE TABLE provenance_coding_agent_reasoning_summaries (
                    id TEXT PRIMARY KEY NOT NULL,
                    session_id TEXT NOT NULL,
                    thread_id TEXT,
                    turn_id TEXT,
                    provider TEXT NOT NULL,
                    item_id TEXT,
                    text TEXT NOT NULL,
                    completed_at_seconds REAL NOT NULL,
                    source TEXT NOT NULL,
                    confidence TEXT NOT NULL
                )
                """,
                """
                CREATE INDEX provenance_coding_agent_reasoning_summaries_session_index
                ON provenance_coding_agent_reasoning_summaries (session_id, completed_at_seconds)
                """,
                """
                CREATE INDEX provenance_coding_agent_reasoning_summaries_turn_index
                ON provenance_coding_agent_reasoning_summaries (turn_id, completed_at_seconds)
                """,
                """
                CREATE TABLE provenance_coding_agent_file_change_attributions (
                    id TEXT PRIMARY KEY NOT NULL,
                    session_id TEXT NOT NULL,
                    thread_id TEXT,
                    turn_id TEXT,
                    provider TEXT NOT NULL,
                    operation_id TEXT,
                    change_set_id TEXT,
                    file_change_ids_json TEXT NOT NULL,
                    paths_json TEXT NOT NULL,
                    summary TEXT,
                    observed_at_seconds REAL NOT NULL,
                    source TEXT NOT NULL,
                    confidence TEXT NOT NULL
                )
                """,
                """
                CREATE INDEX provenance_coding_agent_file_change_attributions_session_index
                ON provenance_coding_agent_file_change_attributions (session_id, observed_at_seconds)
                """,
                """
                CREATE INDEX provenance_coding_agent_file_change_attributions_turn_index
                ON provenance_coding_agent_file_change_attributions (turn_id, observed_at_seconds)
                """,
                """
                CREATE INDEX provenance_coding_agent_file_change_attributions_change_set_index
                ON provenance_coding_agent_file_change_attributions (change_set_id)
                """,
                """
                UPDATE provenance_metadata
                SET value = '17'
                WHERE key = 'schema_version'
                """,
            ]
        ),
        ProvenanceSQLiteMigration(
            version: 18,
            statements: [
                """
                CREATE TABLE provenance_semantic_inferences (
                    id TEXT PRIMARY KEY NOT NULL,
                    schema_version INTEGER NOT NULL,
                    inference_kind TEXT NOT NULL,
                    scope TEXT NOT NULL,
                    scope_id TEXT NOT NULL,
                    payload_json TEXT NOT NULL,
                    supporting_evidence_refs_json TEXT NOT NULL,
                    supporting_factual_revision INTEGER,
                    confidence TEXT NOT NULL,
                    specificity TEXT NOT NULL,
                    producer_type TEXT NOT NULL,
                    producer_id TEXT NOT NULL,
                    producer_version TEXT NOT NULL,
                    created_at_seconds REAL NOT NULL,
                    supersedes_json TEXT NOT NULL,
                    superseded_by TEXT,
                    status TEXT NOT NULL
                )
                """,
                """
                CREATE INDEX provenance_semantic_inferences_scope_index
                ON provenance_semantic_inferences (scope, scope_id, inference_kind, status, created_at_seconds)
                """,
                """
                CREATE INDEX provenance_semantic_inferences_superseded_by_index
                ON provenance_semantic_inferences (superseded_by)
                """,
                """
                UPDATE provenance_metadata
                SET value = '18'
                WHERE key = 'schema_version'
                """,
            ]
        ),
        ProvenanceSQLiteMigration(
            version: 19,
            statements: [
                """
                CREATE TABLE provenance_semantic_messages (
                    id TEXT PRIMARY KEY NOT NULL,
                    schema_version INTEGER NOT NULL,
                    semantic_inference_id TEXT NOT NULL,
                    semantic_inference_kind TEXT NOT NULL,
                    scope TEXT NOT NULL,
                    scope_id TEXT NOT NULL,
                    concise_phrase TEXT NOT NULL,
                    expanded_meaning TEXT NOT NULL,
                    structured_semantic_payload_json TEXT NOT NULL,
                    supporting_evidence_refs_json TEXT NOT NULL,
                    supporting_factual_revision INTEGER,
                    confidence TEXT NOT NULL,
                    specificity TEXT NOT NULL,
                    presentation_producer_type TEXT NOT NULL,
                    presentation_producer_id TEXT NOT NULL,
                    presentation_producer_version TEXT NOT NULL,
                    presentation_policy_id TEXT NOT NULL,
                    presentation_policy_version TEXT NOT NULL,
                    locale_identifier TEXT,
                    created_at_seconds REAL NOT NULL,
                    supersedes_json TEXT NOT NULL,
                    superseded_by TEXT,
                    status TEXT NOT NULL
                )
                """,
                """
                CREATE INDEX provenance_semantic_messages_scope_index
                ON provenance_semantic_messages (
                    scope,
                    scope_id,
                    semantic_inference_kind,
                    presentation_policy_id,
                    status,
                    created_at_seconds
                )
                """,
                """
                CREATE INDEX provenance_semantic_messages_inference_policy_index
                ON provenance_semantic_messages (semantic_inference_id, presentation_policy_id)
                """,
                """
                CREATE INDEX provenance_semantic_messages_superseded_by_index
                ON provenance_semantic_messages (superseded_by)
                """,
                """
                UPDATE provenance_metadata
                SET value = '19'
                WHERE key = 'schema_version'
                """,
            ]
        ),
        ProvenanceSQLiteMigration(
            version: 20,
            statements: [
                """
                CREATE TABLE provenance_coding_agent_assistant_messages (
                    id TEXT PRIMARY KEY NOT NULL,
                    session_id TEXT NOT NULL,
                    thread_id TEXT,
                    turn_id TEXT,
                    provider TEXT NOT NULL,
                    item_id TEXT,
                    text TEXT NOT NULL,
                    completed_at_seconds REAL NOT NULL,
                    source TEXT NOT NULL,
                    confidence TEXT NOT NULL
                )
                """,
                """
                CREATE INDEX provenance_coding_agent_assistant_messages_session_index
                ON provenance_coding_agent_assistant_messages (session_id, completed_at_seconds)
                """,
                """
                CREATE INDEX provenance_coding_agent_assistant_messages_turn_index
                ON provenance_coding_agent_assistant_messages (turn_id, completed_at_seconds)
                """,
                """
                UPDATE provenance_metadata
                SET value = '20'
                WHERE key = 'schema_version'
                """,
            ]
        ),
        ProvenanceSQLiteMigration(
            version: 21,
            statements: [
                """
                CREATE TABLE provenance_coding_agent_turn_outcome_revisions (
                    id TEXT PRIMARY KEY NOT NULL,
                    turn_id TEXT NOT NULL,
                    session_id TEXT NOT NULL,
                    projection_rule_id TEXT NOT NULL,
                    projection_rule_version TEXT NOT NULL,
                    source_watermark_sequence INTEGER,
                    content_fingerprint TEXT NOT NULL,
                    outcome_json TEXT NOT NULL,
                    created_at_seconds REAL
                )
                """,
                """
                CREATE INDEX provenance_coding_agent_turn_outcome_revisions_turn_index
                ON provenance_coding_agent_turn_outcome_revisions (
                    turn_id,
                    source_watermark_sequence,
                    created_at_seconds
                )
                """,
                """
                CREATE INDEX provenance_coding_agent_turn_outcome_revisions_session_index
                ON provenance_coding_agent_turn_outcome_revisions (session_id, source_watermark_sequence)
                """,
                """
                CREATE TABLE provenance_coding_agent_turn_outcomes (
                    turn_id TEXT PRIMARY KEY NOT NULL,
                    latest_revision_id TEXT NOT NULL,
                    session_id TEXT NOT NULL,
                    projection_rule_id TEXT NOT NULL,
                    projection_rule_version TEXT NOT NULL,
                    latest_evaluated_sequence INTEGER,
                    updated_at_seconds REAL
                )
                """,
                """
                CREATE INDEX provenance_coding_agent_turn_outcomes_session_index
                ON provenance_coding_agent_turn_outcomes (session_id, latest_evaluated_sequence)
                """,
                """
                UPDATE provenance_metadata
                SET value = '21'
                WHERE key = 'schema_version'
                """,
            ]
        ),
    ]
}

extension ProvenanceSQLiteRepository: ProvenanceSessionLifecycleRecording {
    func recordSessionLifecycle(
        _ request: ProvenanceSessionLifecycleRequest
    ) async -> ProvenanceSessionLifecycleResponse {
        var builtEvent: ProvenanceEvent?
        do {
            let event = try await sessionLifecycleEvent(for: request)
            builtEvent = event
            try appendEvent(event)
            return ProvenanceSessionLifecycleResponse(
                accepted: true,
                eventID: event.id,
                sessionID: event.payload.session?.id,
                relationshipSessionID: event.payload.sessionRelationship?.sessionID,
                externalIdentityID: event.payload.externalIdentities.first?.id
            )
        } catch {
            return ProvenanceSessionLifecycleResponse(
                accepted: false,
                eventID: builtEvent?.id,
                sessionID: builtEvent?.payload.session?.id,
                relationshipSessionID: builtEvent?.payload.sessionRelationship?.sessionID,
                externalIdentityID: builtEvent?.payload.externalIdentities.first?.id,
                errorDescription: boundedErrorSummary(error)
            )
        }
    }

    func sessionLifecycleEvent(
        for request: ProvenanceSessionLifecycleRequest
    ) async throws -> ProvenanceEvent {
        let identity = lifecycleIdentity(for: request)
        let sessionID = try lifecycleSessionID(for: request, identity: identity)
        let trimmedParentSessionID = request.parentSessionID?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let parentSessionID = trimmedParentSessionID?.isEmpty == false ? trimmedParentSessionID : nil
        let parentRelationship = try parentSessionID.flatMap { try parentSession(for: $0) }
        let rootSessionID = parentSessionID.map { parentRelationship?.rootSessionID ?? $0 }
        let depth = parentRelationship.map { $0.depth + 1 } ?? 1
        let existingSession = try session(id: sessionID)
        let status: String
        let eventType: ProvenanceEventType
        let startedAt: Date?
        switch request.phase {
        case .started:
            status = "active"
            eventType = .sessionStarted
            startedAt = request.timestamp
        case .stopped:
            status = "completed"
            eventType = .sessionStopped
            startedAt = existingSession?.startedAt
        }
        let session = ProvenanceSessionRecord(
            id: sessionID,
            agentKind: request.agentKind,
            workspaceID: request.workspaceID,
            surfaceID: request.surfaceID,
            worktreeID: request.worktreeID,
            cwd: request.workingDirectory,
            status: status,
            startedAt: startedAt,
            updatedAt: request.timestamp
        )
        let relationship = parentSessionID.map {
            ProvenanceSessionRelationshipRecord(
                sessionID: sessionID,
                parentSessionID: $0,
                rootSessionID: rootSessionID ?? $0,
                depth: depth,
                source: .observed,
                confidence: identity.confidence,
                createdAt: request.timestamp,
                updatedAt: request.timestamp
            )
        }
        let externalIdentity = ProvenanceExternalIdentityRecord(
            id: stableIDFactory.externalIdentityID(
                system: request.agentKind,
                kind: identity.kind,
                externalID: identity.value
            ),
            sessionID: sessionID,
            system: request.agentKind,
            kind: identity.kind,
            externalID: identity.value,
            source: .observed,
            confidence: identity.confidence,
            createdAt: request.timestamp,
            updatedAt: request.timestamp
        )
        return ProvenanceEvent(
            id: stableIDFactory.sessionLifecycleEventID(
                phase: request.phase.rawValue,
                sessionID: sessionID,
                timestamp: request.timestamp
            ),
            eventType: eventType,
            timestamp: request.timestamp,
            sessionID: sessionID,
            source: .observed,
            confidence: identity.confidence,
            payload: ProvenanceEventPayload(
                session: session,
                sessionRelationship: relationship,
                externalIdentities: [externalIdentity]
            )
        )
    }

    private func lifecycleSessionID(
        for request: ProvenanceSessionLifecycleRequest,
        identity: (kind: String, value: String, confidence: ProvenanceConfidence)
    ) throws -> String {
        let explicitSessionID = request.sessionID?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let explicitSessionID, !explicitSessionID.isEmpty {
            return explicitSessionID
        }
        if let parentSessionID = request.parentSessionID?.trimmingCharacters(in: .whitespacesAndNewlines),
           !parentSessionID.isEmpty {
            return stableIDFactory.subsessionSessionID(
                agentKind: request.agentKind,
                parentSessionID: parentSessionID,
                identityKind: identity.kind,
                identityValue: identity.value
            )
        }
        return stableIDFactory.sessionID(
            agentKind: request.agentKind,
            identityKind: identity.kind,
            identityValue: identity.value
        )
    }
}
