public import Foundation

/// Durable read-only telemetry import store for context-efficiency analysis.
public actor ContextEfficiencyStore {
    private let database: ContextEfficiencySQLiteDatabase
    private let fileManager: FileManager
    private let idFactory = ContextEfficiencyStableIDFactory()
    private let fileIdentity = CodexRolloutFileIdentity()

    /// Opens or creates a context-efficiency SQLite store.
    ///
    /// - Parameters:
    ///   - databaseURL: SQLite database file to create or open.
    ///   - fileManager: Filesystem dependency used to create the parent directory.
    /// - Throws: ``ContextEfficiencyStoreError`` or filesystem errors.
    public init(databaseURL: URL, fileManager: FileManager = .default) throws {
        try fileManager.createDirectory(
            at: databaseURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        self.fileManager = fileManager
        self.database = try ContextEfficiencySQLiteDatabase(url: databaseURL)
        try ContextEfficiencySQLiteMigration().migrateIfNeeded(database: database)
    }

    /// Incrementally imports one Codex rollout JSONL file.
    ///
    /// The importer stores compact facts and source offsets only. It does not copy
    /// raw rollout payloads into SQLite.
    ///
    /// - Parameters:
    ///   - sourceURL: Rollout JSONL file to import.
    ///   - fallbackThreadID: Thread identifier to use when a line has no thread field.
    /// - Returns: Import counts and the updated cursor.
    /// - Throws: ``ContextEfficiencyStoreError`` or filesystem errors.
    public func importRollout(
        at sourceURL: URL,
        fallbackThreadID: String? = nil,
        metadata: CodexStateThreadMetadata? = nil
    ) throws -> CodexRolloutImportResult {
        let sourcePath = sourceURL.path
        let parser = CodexRolloutTelemetryParser()
        let reader = CodexRolloutJSONLStreamReader()
        let importedAt = Date()
        let sourceInfo = try sourceFileInfo(for: sourceURL)
        var existingCursor = try cursor(forPath: sourcePath)
        var resetCursor = false
        if let cursor = existingCursor, sourceInfo.fileSize < cursor.byteOffset {
            existingCursor = nil
            resetCursor = true
        }

        let startByteOffset = existingCursor?.byteOffset ?? 0
        let startLineNumber = existingCursor?.lineNumber ?? 0
        let fallbackExternalThreadID = fallbackThreadID ?? fileIdentity.threadID(from: sourceURL)
        var rolloutEventCount = 0
        var modelCallCount = 0
        var duplicateTokenTelemetryCount = 0
        var parserErrorCount = 0
        var toolCallCount = 0
        var toolOutputCount = 0
        var compactionCount = 0

        try database.execute("BEGIN IMMEDIATE TRANSACTION")
        do {
            if resetCursor {
                try removeImportedRows(forSourcePath: sourcePath, importedAt: importedAt)
            }
            try upsertImportSource(
                sourcePath: sourcePath,
                fileSize: sourceInfo.fileSize,
                modifiedAt: sourceInfo.modifiedAt,
                importedAt: importedAt
            )
            try upsertEvidenceArtifact(
                sourcePath: sourcePath,
                fileSize: sourceInfo.fileSize,
                importedAt: importedAt
            )
            if let metadata {
                let metadataThreadID = idFactory.normalizedThreadID(metadata.id)
                let metadataReferences = ContextEfficiencyWorkItemReferenceExtractor()
                    .references(from: metadata, sourcePath: sourcePath)
                for reference in metadataReferences {
                    try insertWorkItemReference(
                        reference,
                        threadID: metadataThreadID,
                        importedAt: importedAt
                    )
                }
            }

            let readResult = try reader.readLines(
                from: sourceURL,
                sourcePath: sourcePath,
                startingByteOffset: startByteOffset,
                startingLineNumber: startLineNumber
            ) { line in
                let parsed = parser.parse(line: line, fallbackThreadID: fallbackExternalThreadID)
                let threadID = idFactory.normalizedThreadID(parsed.threadID)
                let eventTimestamp = parsed.timestamp ?? importedAt
                try upsertThread(
                    id: threadID,
                    externalThreadID: parsed.threadID,
                    rolloutPath: sourcePath,
                    model: parsed.model,
                    reasoningEffort: parsed.reasoningEffort,
                    cwd: parsed.cwd,
                    observedAt: eventTimestamp,
                    importedAt: importedAt
                )
                try insertRolloutEvent(parsed, threadID: threadID, importedAt: importedAt)
                rolloutEventCount += 1

                if let message = parsed.parserErrorMessage {
                    try insertParserError(parsed, threadID: threadID, message: message, importedAt: importedAt)
                    parserErrorCount += 1
                }

                if parsed.kind == .compactionObserved {
                    compactionCount += 1
                    try refreshThreadCounters(threadID: threadID, tokenUsage: nil, importedAt: importedAt)
                }

                if let tokenUsage = parsed.tokenUsage, tokenUsage.hasAnyTokenCount {
                    if try isDuplicateTokenTelemetry(threadID: threadID, tokenUsage: tokenUsage) {
                        duplicateTokenTelemetryCount += 1
                    } else {
                        try insertTokenTelemetry(parsed, threadID: threadID, tokenUsage: tokenUsage, importedAt: importedAt)
                        try insertModelCall(parsed, threadID: threadID, tokenUsage: tokenUsage, importedAt: importedAt)
                        try refreshThreadCounters(
                            threadID: threadID,
                            tokenUsage: tokenUsage,
                            importedAt: importedAt
                        )
                        modelCallCount += 1
                    }
                }

                if let toolCall = parsed.toolCall {
                    try insertToolCall(
                        toolCall,
                        parsed: parsed,
                        threadID: threadID,
                        importedAt: importedAt
                    )
                    toolCallCount += 1
                }

                if let toolOutput = parsed.toolOutput {
                    try insertToolOutput(
                        toolOutput,
                        parsed: parsed,
                        threadID: threadID,
                        importedAt: importedAt
                    )
                    toolOutputCount += 1
                }

                for reference in parsed.workItemReferences {
                    try insertWorkItemReference(
                        reference,
                        threadID: threadID,
                        importedAt: importedAt
                    )
                }
            }

            let cursor = CodexRolloutImportCursor(
                sourcePath: sourcePath,
                byteOffset: readResult.nextByteOffset,
                lineNumber: readResult.nextLineNumber,
                fileSize: readResult.fileSize,
                parserVersion: CodexRolloutTelemetryParser.parserVersion,
                updatedAt: importedAt
            )
            try upsertCursor(cursor)
            try database.execute("COMMIT")
            return CodexRolloutImportResult(
                sourcePath: sourcePath,
                lineCount: readResult.lineCount,
                rolloutEventCount: rolloutEventCount,
                modelCallCount: modelCallCount,
                duplicateTokenTelemetryCount: duplicateTokenTelemetryCount,
                parserErrorCount: parserErrorCount,
                toolCallCount: toolCallCount,
                toolOutputCount: toolOutputCount,
                compactionCount: compactionCount,
                resetCursor: resetCursor,
                cursor: cursor
            )
        } catch {
            try? database.execute("ROLLBACK")
            throw error
        }
    }

    /// Returns the current incremental cursor for a rollout source.
    ///
    /// - Parameter sourceURL: Rollout source URL.
    /// - Returns: Stored cursor, or `nil` when the source has not been imported.
    public func cursor(for sourceURL: URL) throws -> CodexRolloutImportCursor? {
        try cursor(forPath: sourceURL.path)
    }

    /// Returns a read-only inspection report for one imported thread.
    ///
    /// - Parameter threadID: Context-efficiency thread identifier.
    /// - Returns: Thread facts and related telemetry rows.
    public func inspectThread(_ threadID: String) throws -> ContextEfficiencyThreadInspection {
        let modelCalls = try modelCallRecords(threadID: threadID)
        let toolCalls = try toolCallRecords(threadID: threadID)
        let toolOutputs = try toolOutputRecords(threadID: threadID)
        let commandExecutions = ContextEfficiencyCommandAttributor().commandExecutions(
            toolCalls: toolCalls,
            toolOutputs: toolOutputs,
            modelCalls: modelCalls
        )
        return ContextEfficiencyThreadInspection(
            thread: try threadRecord(id: threadID),
            modelCalls: modelCalls,
            tokenTelemetryEvents: try tokenTelemetryRecords(threadID: threadID),
            toolCalls: toolCalls,
            toolOutputs: toolOutputs,
            commandExecutions: commandExecutions,
            commandCategoryCounts: ContextEfficiencyCommandCategoryCounter().counts(for: commandExecutions),
            workItemReferences: try workItemReferenceRecords(threadID: threadID),
            parserErrors: try parserErrorRecords(threadID: threadID)
        )
    }

    /// Returns aggregate imported telemetry for one UTC day.
    ///
    /// - Parameter day: Day in `YYYY-MM-DD` form.
    /// - Returns: Aggregate counts and token totals for the day.
    public func summarizeDay(_ day: String) throws -> ContextEfficiencyDaySummary {
        let range = try dayRange(for: day)
        let telemetryStatement = try database.prepare(
            """
            SELECT COUNT(DISTINCT thread_id), COUNT(*),
                   COALESCE(SUM(total_tokens), 0),
                   COALESCE(SUM(cached_input_tokens), 0),
                   COALESCE(SUM(output_tokens), 0)
            FROM model_calls
            WHERE timestamp >= ? AND timestamp < ?
            """
        )
        defer { telemetryStatement.finalize() }
        try telemetryStatement.bind(range.start, at: 1)
        try telemetryStatement.bind(range.end, at: 2)
        guard try telemetryStatement.step() else {
            throw ContextEfficiencyStoreError.invalidRow("missing day summary row")
        }

        let parserErrorStatement = try database.prepare(
            """
            SELECT COUNT(*)
            FROM parser_errors
            WHERE EXISTS (
                SELECT 1
                FROM rollout_events
                WHERE rollout_events.source_path = parser_errors.source_path
                  AND rollout_events.timestamp >= ?
                  AND rollout_events.timestamp < ?
            )
            """
        )
        defer { parserErrorStatement.finalize() }
        try parserErrorStatement.bind(range.start, at: 1)
        try parserErrorStatement.bind(range.end, at: 2)
        let parserErrorCount: Int
        if try parserErrorStatement.step() {
            parserErrorCount = parserErrorStatement.int(at: 0)
        } else {
            parserErrorCount = 0
        }

        return ContextEfficiencyDaySummary(
            day: day,
            threadCount: telemetryStatement.int(at: 0),
            modelCallCount: telemetryStatement.int(at: 1),
            totalTokens: telemetryStatement.int64(at: 2),
            cachedInputTokens: telemetryStatement.int64(at: 3),
            outputTokens: telemetryStatement.int64(at: 4),
            parserErrorCount: parserErrorCount,
            commandCategoryCounts: ContextEfficiencyCommandCategoryCounter().counts(
                for: try toolCallRecords(startTimestamp: range.start, endTimestamp: range.end)
            )
        )
    }

    private func sourceFileInfo(for url: URL) throws -> (fileSize: Int64, modifiedAt: Date?) {
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        let fileSize = (attributes[.size] as? NSNumber)?.int64Value ?? 0
        let modifiedAt = attributes[.modificationDate] as? Date
        return (fileSize, modifiedAt)
    }

    private func removeImportedRows(forSourcePath sourcePath: String, importedAt: Date) throws {
        let affectedThreadIDs = try threadIDsReferencedBySource(sourcePath)
        for statementText in [
            "DELETE FROM rollout_events WHERE source_path = ?",
            "DELETE FROM parser_errors WHERE source_path = ?",
            "DELETE FROM token_telemetry_events WHERE source_path = ?",
            "DELETE FROM model_calls WHERE source_path = ?",
            "DELETE FROM tool_calls WHERE source_path = ?",
            "DELETE FROM tool_outputs WHERE source_path = ?",
            "DELETE FROM work_item_references WHERE source_path = ?",
        ] {
            let statement = try database.prepare(statementText)
            defer { statement.finalize() }
            try statement.bind(sourcePath, at: 1)
            _ = try statement.step()
        }
        for threadID in affectedThreadIDs {
            if try hasImportedRows(threadID: threadID) {
                try refreshThreadCountersFromStoredRows(threadID: threadID, importedAt: importedAt)
            } else {
                try deleteThread(id: threadID)
            }
        }
    }

    private func threadIDsReferencedBySource(_ sourcePath: String) throws -> [String] {
        let statement = try database.prepare(
            """
            SELECT DISTINCT thread_id FROM (
                SELECT thread_id FROM rollout_events WHERE source_path = ?
                UNION
                SELECT thread_id FROM parser_errors WHERE source_path = ?
                UNION
                SELECT thread_id FROM token_telemetry_events WHERE source_path = ?
                UNION
                SELECT thread_id FROM model_calls WHERE source_path = ?
                UNION
                SELECT thread_id FROM tool_calls WHERE source_path = ?
                UNION
                SELECT thread_id FROM tool_outputs WHERE source_path = ?
                UNION
                SELECT thread_id FROM work_item_references WHERE source_path = ?
            )
            """
        )
        defer { statement.finalize() }
        for index in 1...7 {
            try statement.bind(sourcePath, at: Int32(index))
        }
        var threadIDs: [String] = []
        while try statement.step() {
            if let threadID = statement.string(at: 0) {
                threadIDs.append(threadID)
            }
        }
        return threadIDs
    }

    private func hasImportedRows(threadID: String) throws -> Bool {
        let statement = try database.prepare(
            """
            SELECT EXISTS(
                SELECT 1 FROM rollout_events WHERE thread_id = ?
            )
            """
        )
        defer { statement.finalize() }
        try statement.bind(threadID, at: 1)
        guard try statement.step() else {
            return false
        }
        return statement.int(at: 0) != 0
    }

    private func deleteThread(id threadID: String) throws {
        let statement = try database.prepare("DELETE FROM agent_threads WHERE id = ?")
        defer { statement.finalize() }
        try statement.bind(threadID, at: 1)
        _ = try statement.step()
    }

    private func refreshThreadCountersFromStoredRows(threadID: String, importedAt: Date) throws {
        let tokenUsage = try latestStoredTokenUsage(threadID: threadID)
        let statement = try database.prepare(
            """
            UPDATE agent_threads SET
                first_observed_at = (
                    SELECT MIN(timestamp) FROM rollout_events WHERE thread_id = ?
                ),
                last_observed_at = (
                    SELECT MAX(timestamp) FROM rollout_events WHERE thread_id = ?
                ),
                cumulative_input_tokens = ?,
                cumulative_cached_input_tokens = ?,
                cumulative_non_cached_input_tokens = ?,
                cumulative_output_tokens = ?,
                cumulative_reasoning_output_tokens = ?,
                cumulative_total_tokens = ?,
                estimated_context_tokens = ?,
                context_window_tokens = ?,
                model_call_count = (
                    SELECT COUNT(*) FROM model_calls WHERE thread_id = ?
                ),
                compaction_count = (
                    SELECT COUNT(*) FROM rollout_events
                    WHERE thread_id = ? AND kind = ?
                ),
                updated_at = ?
            WHERE id = ?
            """
        )
        defer { statement.finalize() }
        try statement.bind(threadID, at: 1)
        try statement.bind(threadID, at: 2)
        try statement.bind(tokenUsage?.inputTokens, at: 3)
        try statement.bind(tokenUsage?.cachedInputTokens, at: 4)
        try statement.bind(tokenUsage?.nonCachedInputTokens, at: 5)
        try statement.bind(tokenUsage?.outputTokens, at: 6)
        try statement.bind(tokenUsage?.reasoningOutputTokens, at: 7)
        try statement.bind(tokenUsage?.totalTokens, at: 8)
        try statement.bind(tokenUsage?.estimatedContextTokens, at: 9)
        try statement.bind(tokenUsage?.contextWindowTokens, at: 10)
        try statement.bind(threadID, at: 11)
        try statement.bind(threadID, at: 12)
        try statement.bind(CodexRolloutEventKind.compactionObserved.rawValue, at: 13)
        try statement.bind(timestamp(importedAt), at: 14)
        try statement.bind(threadID, at: 15)
        _ = try statement.step()
    }

    private func latestStoredTokenUsage(threadID: String) throws -> ContextEfficiencyTokenUsage? {
        let statement = try database.prepare(
            """
            SELECT input_tokens, cached_input_tokens, non_cached_input_tokens,
                   output_tokens, reasoning_output_tokens, total_tokens,
                   estimated_context_tokens, context_window_tokens
            FROM token_telemetry_events
            WHERE thread_id = ?
            ORDER BY rowid DESC
            LIMIT 1
            """
        )
        defer { statement.finalize() }
        try statement.bind(threadID, at: 1)
        guard try statement.step() else {
            return nil
        }
        return tokenUsage(statement: statement, startingAt: 0)
    }

    private func upsertImportSource(
        sourcePath: String,
        fileSize: Int64,
        modifiedAt: Date?,
        importedAt: Date
    ) throws {
        let statement = try database.prepare(
            """
            INSERT INTO import_sources (
                source_path, source_type, file_size, modified_at,
                first_seen_at, last_seen_at, parser_version
            ) VALUES (?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(source_path) DO UPDATE SET
                file_size = excluded.file_size,
                modified_at = excluded.modified_at,
                last_seen_at = excluded.last_seen_at,
                parser_version = excluded.parser_version
            """
        )
        defer { statement.finalize() }
        try statement.bind(sourcePath, at: 1)
        try statement.bind("codex_rollout_jsonl", at: 2)
        try statement.bind(fileSize, at: 3)
        try statement.bind(timestamp(modifiedAt), at: 4)
        try statement.bind(timestamp(importedAt), at: 5)
        try statement.bind(timestamp(importedAt), at: 6)
        try statement.bind(CodexRolloutTelemetryParser.parserVersion, at: 7)
        _ = try statement.step()
    }

    private func upsertEvidenceArtifact(sourcePath: String, fileSize: Int64, importedAt: Date) throws {
        let statement = try database.prepare(
            """
            INSERT INTO evidence_artifacts (
                id, type, storage_location, content_hash, byte_count,
                estimated_tokens, producer_event_id, created_at, retention_policy
            ) VALUES (?, ?, ?, NULL, ?, NULL, NULL, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                storage_location = excluded.storage_location,
                byte_count = excluded.byte_count,
                created_at = excluded.created_at
            """
        )
        defer { statement.finalize() }
        try statement.bind(idFactory.artifactID(sourcePath: sourcePath), at: 1)
        try statement.bind("codex_rollout_jsonl", at: 2)
        try statement.bind(sourcePath, at: 3)
        try statement.bind(fileSize, at: 4)
        try statement.bind(timestamp(importedAt), at: 5)
        try statement.bind("external_file_reference", at: 6)
        _ = try statement.step()
    }

    private func upsertThread(
        id: String,
        externalThreadID: String,
        rolloutPath: String,
        model: String?,
        reasoningEffort: String?,
        cwd: String?,
        observedAt: Date,
        importedAt: Date
    ) throws {
        let statement = try database.prepare(
            """
            INSERT INTO agent_threads (
                id, external_thread_id, rollout_path, model, reasoning_effort,
                cwd, first_observed_at, last_observed_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                external_thread_id = COALESCE(excluded.external_thread_id, agent_threads.external_thread_id),
                rollout_path = COALESCE(excluded.rollout_path, agent_threads.rollout_path),
                model = COALESCE(excluded.model, agent_threads.model),
                reasoning_effort = COALESCE(excluded.reasoning_effort, agent_threads.reasoning_effort),
                cwd = COALESCE(excluded.cwd, agent_threads.cwd),
                first_observed_at = CASE
                    WHEN agent_threads.first_observed_at IS NULL THEN excluded.first_observed_at
                    WHEN excluded.first_observed_at IS NULL THEN agent_threads.first_observed_at
                    ELSE MIN(agent_threads.first_observed_at, excluded.first_observed_at)
                END,
                last_observed_at = CASE
                    WHEN agent_threads.last_observed_at IS NULL THEN excluded.last_observed_at
                    WHEN excluded.last_observed_at IS NULL THEN agent_threads.last_observed_at
                    ELSE MAX(agent_threads.last_observed_at, excluded.last_observed_at)
                END,
                updated_at = excluded.updated_at
            """
        )
        defer { statement.finalize() }
        try statement.bind(id, at: 1)
        try statement.bind(externalThreadID, at: 2)
        try statement.bind(rolloutPath, at: 3)
        try statement.bind(model, at: 4)
        try statement.bind(reasoningEffort, at: 5)
        try statement.bind(cwd, at: 6)
        try statement.bind(timestamp(observedAt), at: 7)
        try statement.bind(timestamp(observedAt), at: 8)
        try statement.bind(timestamp(importedAt), at: 9)
        _ = try statement.step()
    }

    private func insertRolloutEvent(
        _ parsed: CodexRolloutParsedEvent,
        threadID: String,
        importedAt: Date
    ) throws {
        let statement = try database.prepare(
            """
            INSERT OR IGNORE INTO rollout_events (
                id, source_path, byte_offset, line_number, parser_version,
                thread_id, kind, rollout_type, payload_type, timestamp,
                imported_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """
        )
        defer { statement.finalize() }
        let sourceReference = parsed.sourceReference
        try statement.bind(idFactory.recordID(kind: "rollout-event", sourceReference: sourceReference), at: 1)
        try bind(sourceReference, statement: statement, startingAt: 2)
        try statement.bind(threadID, at: 6)
        try statement.bind(parsed.kind.rawValue, at: 7)
        try statement.bind(parsed.rolloutType, at: 8)
        try statement.bind(parsed.payloadType, at: 9)
        try statement.bind(timestamp(parsed.timestamp), at: 10)
        try statement.bind(timestamp(importedAt), at: 11)
        _ = try statement.step()
    }

    private func insertParserError(
        _ parsed: CodexRolloutParsedEvent,
        threadID: String,
        message: String,
        importedAt: Date
    ) throws {
        let statement = try database.prepare(
            """
            INSERT OR IGNORE INTO parser_errors (
                id, source_path, byte_offset, line_number, parser_version,
                thread_id, rollout_type, message, imported_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """
        )
        defer { statement.finalize() }
        let sourceReference = parsed.sourceReference
        try statement.bind(idFactory.recordID(kind: "parser-error", sourceReference: sourceReference), at: 1)
        try bind(sourceReference, statement: statement, startingAt: 2)
        try statement.bind(threadID, at: 6)
        try statement.bind(parsed.rolloutType, at: 7)
        try statement.bind(message, at: 8)
        try statement.bind(timestamp(importedAt), at: 9)
        _ = try statement.step()
    }

    private func isDuplicateTokenTelemetry(
        threadID: String,
        tokenUsage: ContextEfficiencyTokenUsage
    ) throws -> Bool {
        let statement = try database.prepare(
            """
            SELECT duplicate_fingerprint
            FROM token_telemetry_events
            WHERE thread_id = ?
            ORDER BY rowid DESC
            LIMIT 1
            """
        )
        defer { statement.finalize() }
        try statement.bind(threadID, at: 1)
        guard try statement.step(), let fingerprint = statement.string(at: 0) else {
            return false
        }
        return fingerprint == tokenUsage.duplicateFingerprint
    }

    private func insertTokenTelemetry(
        _ parsed: CodexRolloutParsedEvent,
        threadID: String,
        tokenUsage: ContextEfficiencyTokenUsage,
        importedAt: Date
    ) throws {
        let statement = try database.prepare(
            """
            INSERT OR IGNORE INTO token_telemetry_events (
                id, thread_id, timestamp, source_path, byte_offset,
                line_number, parser_version, input_tokens, cached_input_tokens,
                non_cached_input_tokens, output_tokens, reasoning_output_tokens,
                total_tokens, estimated_context_tokens, context_window_tokens,
                duplicate_fingerprint, imported_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """
        )
        defer { statement.finalize() }
        let sourceReference = parsed.sourceReference
        try statement.bind(idFactory.recordID(kind: "token-telemetry", sourceReference: sourceReference), at: 1)
        try statement.bind(threadID, at: 2)
        try statement.bind(timestamp(parsed.timestamp), at: 3)
        try bind(sourceReference, statement: statement, startingAt: 4)
        try bind(tokenUsage, statement: statement, startingAt: 8)
        try statement.bind(tokenUsage.duplicateFingerprint, at: 16)
        try statement.bind(timestamp(importedAt), at: 17)
        _ = try statement.step()
    }

    private func insertModelCall(
        _ parsed: CodexRolloutParsedEvent,
        threadID: String,
        tokenUsage: ContextEfficiencyTokenUsage,
        importedAt: Date
    ) throws {
        let statement = try database.prepare(
            """
            INSERT OR IGNORE INTO model_calls (
                id, thread_id, timestamp, source_path, byte_offset,
                line_number, parser_version, input_tokens, cached_input_tokens,
                non_cached_input_tokens, output_tokens, reasoning_output_tokens,
                total_tokens, estimated_context_tokens, context_window_tokens,
                telemetry_source, telemetry_confidence, imported_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """
        )
        defer { statement.finalize() }
        let sourceReference = parsed.sourceReference
        try statement.bind(idFactory.recordID(kind: "model-call", sourceReference: sourceReference), at: 1)
        try statement.bind(threadID, at: 2)
        try statement.bind(timestamp(parsed.timestamp), at: 3)
        try bind(sourceReference, statement: statement, startingAt: 4)
        try bind(tokenUsage, statement: statement, startingAt: 8)
        try statement.bind("codex_rollout_jsonl", at: 16)
        try statement.bind("observed", at: 17)
        try statement.bind(timestamp(importedAt), at: 18)
        _ = try statement.step()
    }

    private func insertToolCall(
        _ toolCall: CodexRolloutParsedToolCall,
        parsed: CodexRolloutParsedEvent,
        threadID: String,
        importedAt: Date
    ) throws {
        let statement = try database.prepare(
            """
            INSERT OR IGNORE INTO tool_calls (
                id, thread_id, call_id, tool_name, command_summary,
                arguments_byte_count, timestamp, source_path, byte_offset,
                line_number, parser_version, imported_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """
        )
        defer { statement.finalize() }
        let sourceReference = parsed.sourceReference
        try statement.bind(idFactory.recordID(kind: "tool-call", sourceReference: sourceReference), at: 1)
        try statement.bind(threadID, at: 2)
        try statement.bind(toolCall.callID, at: 3)
        try statement.bind(toolCall.toolName, at: 4)
        try statement.bind(toolCall.commandSummary, at: 5)
        try statement.bind(toolCall.argumentsByteCount, at: 6)
        try statement.bind(timestamp(parsed.timestamp), at: 7)
        try bind(sourceReference, statement: statement, startingAt: 8)
        try statement.bind(timestamp(importedAt), at: 12)
        _ = try statement.step()
    }

    private func insertToolOutput(
        _ toolOutput: CodexRolloutParsedToolOutput,
        parsed: CodexRolloutParsedEvent,
        threadID: String,
        importedAt: Date
    ) throws {
        let statement = try database.prepare(
            """
            INSERT OR IGNORE INTO tool_outputs (
                id, thread_id, call_id, output_byte_count,
                estimated_original_tokens, raw_output_reference_count,
                timestamp, source_path, byte_offset, line_number,
                parser_version, imported_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """
        )
        defer { statement.finalize() }
        let sourceReference = parsed.sourceReference
        try statement.bind(idFactory.recordID(kind: "tool-output", sourceReference: sourceReference), at: 1)
        try statement.bind(threadID, at: 2)
        try statement.bind(toolOutput.callID, at: 3)
        try statement.bind(toolOutput.outputByteCount, at: 4)
        try statement.bind(toolOutput.estimatedOriginalTokens, at: 5)
        try statement.bind(toolOutput.rawOutputReferenceCount, at: 6)
        try statement.bind(timestamp(parsed.timestamp), at: 7)
        try bind(sourceReference, statement: statement, startingAt: 8)
        try statement.bind(timestamp(importedAt), at: 12)
        _ = try statement.step()
    }

    private func insertWorkItemReference(
        _ reference: CodexRolloutParsedWorkItemReference,
        threadID: String,
        importedAt: Date
    ) throws {
        let statement = try database.prepare(
            """
            INSERT OR IGNORE INTO work_item_references (
                id, thread_id, kind, reference, repository_slug, number,
                url_string, branch_name, ticket_key, source_kind, confidence,
                source_path, byte_offset, line_number, parser_version,
                observed_at, imported_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """
        )
        defer { statement.finalize() }
        try statement.bind(workItemReferenceID(reference, threadID: threadID), at: 1)
        try statement.bind(threadID, at: 2)
        try statement.bind(reference.kind.rawValue, at: 3)
        try statement.bind(reference.reference, at: 4)
        try statement.bind(reference.repositorySlug, at: 5)
        try statement.bind(reference.number.map(Int64.init), at: 6)
        try statement.bind(reference.urlString, at: 7)
        try statement.bind(reference.branchName, at: 8)
        try statement.bind(reference.ticketKey, at: 9)
        try statement.bind(reference.sourceKind.rawValue, at: 10)
        try statement.bind(reference.confidence.rawValue, at: 11)
        try statement.bind(reference.sourcePath, at: 12)
        try statement.bind(reference.sourceReference?.byteOffset, at: 13)
        try statement.bind((reference.sourceReference?.lineNumber).map(Int64.init), at: 14)
        try statement.bind((reference.sourceReference?.parserVersion).map(Int64.init), at: 15)
        try statement.bind(timestamp(reference.observedAt), at: 16)
        try statement.bind(timestamp(importedAt), at: 17)
        _ = try statement.step()
    }

    private func refreshThreadCounters(
        threadID: String,
        tokenUsage: ContextEfficiencyTokenUsage?,
        importedAt: Date
    ) throws {
        let statement = try database.prepare(
            """
            UPDATE agent_threads SET
                cumulative_input_tokens = COALESCE(?, cumulative_input_tokens),
                cumulative_cached_input_tokens = COALESCE(?, cumulative_cached_input_tokens),
                cumulative_non_cached_input_tokens = COALESCE(?, cumulative_non_cached_input_tokens),
                cumulative_output_tokens = COALESCE(?, cumulative_output_tokens),
                cumulative_reasoning_output_tokens = COALESCE(?, cumulative_reasoning_output_tokens),
                cumulative_total_tokens = COALESCE(?, cumulative_total_tokens),
                estimated_context_tokens = COALESCE(?, estimated_context_tokens),
                context_window_tokens = COALESCE(?, context_window_tokens),
                model_call_count = (
                    SELECT COUNT(*) FROM model_calls WHERE thread_id = ?
                ),
                compaction_count = (
                    SELECT COUNT(*) FROM rollout_events
                    WHERE thread_id = ? AND kind = ?
                ),
                updated_at = ?
            WHERE id = ?
            """
        )
        defer { statement.finalize() }
        try statement.bind(tokenUsage?.inputTokens, at: 1)
        try statement.bind(tokenUsage?.cachedInputTokens, at: 2)
        try statement.bind(tokenUsage?.nonCachedInputTokens, at: 3)
        try statement.bind(tokenUsage?.outputTokens, at: 4)
        try statement.bind(tokenUsage?.reasoningOutputTokens, at: 5)
        try statement.bind(tokenUsage?.totalTokens, at: 6)
        try statement.bind(tokenUsage?.estimatedContextTokens, at: 7)
        try statement.bind(tokenUsage?.contextWindowTokens, at: 8)
        try statement.bind(threadID, at: 9)
        try statement.bind(threadID, at: 10)
        try statement.bind(CodexRolloutEventKind.compactionObserved.rawValue, at: 11)
        try statement.bind(timestamp(importedAt), at: 12)
        try statement.bind(threadID, at: 13)
        _ = try statement.step()
    }

    private func upsertCursor(_ cursor: CodexRolloutImportCursor) throws {
        let statement = try database.prepare(
            """
            INSERT INTO import_cursors (
                source_path, byte_offset, line_number, file_size,
                parser_version, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?)
            ON CONFLICT(source_path) DO UPDATE SET
                byte_offset = excluded.byte_offset,
                line_number = excluded.line_number,
                file_size = excluded.file_size,
                parser_version = excluded.parser_version,
                updated_at = excluded.updated_at
            """
        )
        defer { statement.finalize() }
        try statement.bind(cursor.sourcePath, at: 1)
        try statement.bind(cursor.byteOffset, at: 2)
        try statement.bind(cursor.lineNumber, at: 3)
        try statement.bind(cursor.fileSize, at: 4)
        try statement.bind(cursor.parserVersion, at: 5)
        try statement.bind(timestamp(cursor.updatedAt), at: 6)
        _ = try statement.step()
    }

    private func cursor(forPath sourcePath: String) throws -> CodexRolloutImportCursor? {
        let statement = try database.prepare(
            """
            SELECT source_path, byte_offset, line_number, file_size,
                   parser_version, updated_at
            FROM import_cursors
            WHERE source_path = ?
            """
        )
        defer { statement.finalize() }
        try statement.bind(sourcePath, at: 1)
        guard try statement.step(), let path = statement.string(at: 0) else {
            return nil
        }
        return CodexRolloutImportCursor(
            sourcePath: path,
            byteOffset: statement.int64(at: 1),
            lineNumber: statement.int(at: 2),
            fileSize: statement.int64(at: 3),
            parserVersion: statement.int(at: 4),
            updatedAt: date(from: statement.double(at: 5)) ?? Date(timeIntervalSince1970: 0)
        )
    }

    private func threadRecord(id: String) throws -> ContextEfficiencyAgentThreadRecord? {
        let statement = try database.prepare(
            """
            SELECT id, external_thread_id, rollout_path, model, reasoning_effort,
                   cwd, first_observed_at, last_observed_at,
                   cumulative_total_tokens, model_call_count, compaction_count
            FROM agent_threads
            WHERE id = ?
            """
        )
        defer { statement.finalize() }
        try statement.bind(id, at: 1)
        guard try statement.step(), let id = statement.string(at: 0) else {
            return nil
        }
        return ContextEfficiencyAgentThreadRecord(
            id: id,
            externalThreadID: statement.string(at: 1),
            rolloutPath: statement.string(at: 2),
            model: statement.string(at: 3),
            reasoningEffort: statement.string(at: 4),
            cwd: statement.string(at: 5),
            firstObservedAt: date(from: statement.double(at: 6)),
            lastObservedAt: date(from: statement.double(at: 7)),
            cumulativeTotalTokens: statement.optionalInt64(at: 8),
            modelCallCount: statement.int(at: 9),
            compactionCount: statement.int(at: 10)
        )
    }

    private func modelCallRecords(threadID: String) throws -> [ContextEfficiencyModelCallRecord] {
        let statement = try database.prepare(
            """
            SELECT id, thread_id, timestamp, input_tokens, cached_input_tokens,
                   non_cached_input_tokens, output_tokens, reasoning_output_tokens,
                   total_tokens, estimated_context_tokens, context_window_tokens,
                   source_path, byte_offset, line_number, parser_version,
                   telemetry_confidence
            FROM model_calls
            WHERE thread_id = ?
            ORDER BY rowid ASC
            """
        )
        defer { statement.finalize() }
        try statement.bind(threadID, at: 1)
        var records: [ContextEfficiencyModelCallRecord] = []
        while try statement.step() {
            guard let id = statement.string(at: 0),
                  let threadID = statement.string(at: 1),
                  let sourceReference = sourceReference(statement: statement, startingAt: 11),
                  let telemetryConfidence = statement.string(at: 15) else {
                throw ContextEfficiencyStoreError.invalidRow("invalid model call row")
            }
            records.append(ContextEfficiencyModelCallRecord(
                id: id,
                threadID: threadID,
                timestamp: date(from: statement.double(at: 2)),
                tokenUsage: tokenUsage(statement: statement, startingAt: 3),
                sourceReference: sourceReference,
                telemetryConfidence: telemetryConfidence
            ))
        }
        return records
    }

    private func tokenTelemetryRecords(threadID: String) throws -> [ContextEfficiencyTokenTelemetryRecord] {
        let statement = try database.prepare(
            """
            SELECT id, thread_id, timestamp, input_tokens, cached_input_tokens,
                   non_cached_input_tokens, output_tokens, reasoning_output_tokens,
                   total_tokens, estimated_context_tokens, context_window_tokens,
                   source_path, byte_offset, line_number, parser_version
            FROM token_telemetry_events
            WHERE thread_id = ?
            ORDER BY rowid ASC
            """
        )
        defer { statement.finalize() }
        try statement.bind(threadID, at: 1)
        var records: [ContextEfficiencyTokenTelemetryRecord] = []
        while try statement.step() {
            guard let id = statement.string(at: 0),
                  let threadID = statement.string(at: 1),
                  let sourceReference = sourceReference(statement: statement, startingAt: 11) else {
                throw ContextEfficiencyStoreError.invalidRow("invalid token telemetry row")
            }
            records.append(ContextEfficiencyTokenTelemetryRecord(
                id: id,
                threadID: threadID,
                timestamp: date(from: statement.double(at: 2)),
                tokenUsage: tokenUsage(statement: statement, startingAt: 3),
                sourceReference: sourceReference
            ))
        }
        return records
    }

    private func toolCallRecords(threadID: String) throws -> [ContextEfficiencyToolCallRecord] {
        let statement = try database.prepare(
            """
            SELECT id, thread_id, call_id, tool_name, command_summary,
                   arguments_byte_count, timestamp, source_path, byte_offset,
                   line_number, parser_version
            FROM tool_calls
            WHERE thread_id = ?
            ORDER BY rowid ASC
            """
        )
        defer { statement.finalize() }
        try statement.bind(threadID, at: 1)
        var records: [ContextEfficiencyToolCallRecord] = []
        while try statement.step() {
            guard let id = statement.string(at: 0),
                  let threadID = statement.string(at: 1),
                  let sourceReference = sourceReference(statement: statement, startingAt: 7) else {
                throw ContextEfficiencyStoreError.invalidRow("invalid tool call row")
            }
            records.append(ContextEfficiencyToolCallRecord(
                id: id,
                threadID: threadID,
                callID: statement.string(at: 2),
                toolName: statement.string(at: 3),
                commandSummary: statement.string(at: 4),
                argumentsByteCount: statement.int64(at: 5),
                timestamp: date(from: statement.double(at: 6)),
                sourceReference: sourceReference
            ))
        }
        return records
    }

    private func toolCallRecords(startTimestamp: Double, endTimestamp: Double) throws -> [ContextEfficiencyToolCallRecord] {
        let statement = try database.prepare(
            """
            SELECT id, thread_id, call_id, tool_name, command_summary,
                   arguments_byte_count, timestamp, source_path, byte_offset,
                   line_number, parser_version
            FROM tool_calls
            WHERE timestamp >= ? AND timestamp < ?
            ORDER BY timestamp ASC, rowid ASC
            """
        )
        defer { statement.finalize() }
        try statement.bind(startTimestamp, at: 1)
        try statement.bind(endTimestamp, at: 2)
        var records: [ContextEfficiencyToolCallRecord] = []
        while try statement.step() {
            guard let id = statement.string(at: 0),
                  let threadID = statement.string(at: 1),
                  let sourceReference = sourceReference(statement: statement, startingAt: 7) else {
                throw ContextEfficiencyStoreError.invalidRow("invalid dated tool call row")
            }
            records.append(ContextEfficiencyToolCallRecord(
                id: id,
                threadID: threadID,
                callID: statement.string(at: 2),
                toolName: statement.string(at: 3),
                commandSummary: statement.string(at: 4),
                argumentsByteCount: statement.int64(at: 5),
                timestamp: date(from: statement.double(at: 6)),
                sourceReference: sourceReference
            ))
        }
        return records
    }

    private func toolOutputRecords(threadID: String) throws -> [ContextEfficiencyToolOutputRecord] {
        let statement = try database.prepare(
            """
            SELECT id, thread_id, call_id, output_byte_count,
                   estimated_original_tokens, raw_output_reference_count,
                   timestamp, source_path, byte_offset, line_number, parser_version
            FROM tool_outputs
            WHERE thread_id = ?
            ORDER BY rowid ASC
            """
        )
        defer { statement.finalize() }
        try statement.bind(threadID, at: 1)
        var records: [ContextEfficiencyToolOutputRecord] = []
        while try statement.step() {
            guard let id = statement.string(at: 0),
                  let threadID = statement.string(at: 1),
                  let sourceReference = sourceReference(statement: statement, startingAt: 7) else {
                throw ContextEfficiencyStoreError.invalidRow("invalid tool output row")
            }
            records.append(ContextEfficiencyToolOutputRecord(
                id: id,
                threadID: threadID,
                callID: statement.string(at: 2),
                outputByteCount: statement.int64(at: 3),
                estimatedOriginalTokens: statement.int64(at: 4),
                rawOutputReferenceCount: statement.int(at: 5),
                timestamp: date(from: statement.double(at: 6)),
                sourceReference: sourceReference
            ))
        }
        return records
    }

    private func parserErrorRecords(threadID: String) throws -> [ContextEfficiencyParserErrorRecord] {
        let statement = try database.prepare(
            """
            SELECT id, message, rollout_type, source_path, byte_offset,
                   line_number, parser_version, imported_at
            FROM parser_errors
            WHERE thread_id = ?
            ORDER BY rowid ASC
            """
        )
        defer { statement.finalize() }
        try statement.bind(threadID, at: 1)
        var records: [ContextEfficiencyParserErrorRecord] = []
        while try statement.step() {
            guard let id = statement.string(at: 0),
                  let message = statement.string(at: 1),
                  let sourceReference = sourceReference(statement: statement, startingAt: 3),
                  let importedAt = date(from: statement.double(at: 7)) else {
                throw ContextEfficiencyStoreError.invalidRow("invalid parser error row")
            }
            records.append(ContextEfficiencyParserErrorRecord(
                id: id,
                message: message,
                rolloutType: statement.string(at: 2),
                sourceReference: sourceReference,
                importedAt: importedAt
            ))
        }
        return records
    }

    private func workItemReferenceRecords(threadID: String) throws -> [ContextEfficiencyWorkItemReferenceRecord] {
        let statement = try database.prepare(
            """
            SELECT id, thread_id, kind, reference, repository_slug, number,
                   url_string, branch_name, ticket_key, source_kind, confidence,
                   source_path, byte_offset, line_number, parser_version,
                   observed_at
            FROM work_item_references
            WHERE thread_id = ?
            ORDER BY rowid ASC
            """
        )
        defer { statement.finalize() }
        try statement.bind(threadID, at: 1)
        var records: [ContextEfficiencyWorkItemReferenceRecord] = []
        while try statement.step() {
            guard let id = statement.string(at: 0),
                  let threadID = statement.string(at: 1),
                  let kindRawValue = statement.string(at: 2),
                  let kind = ContextEfficiencyWorkItemReferenceKind(rawValue: kindRawValue),
                  let reference = statement.string(at: 3),
                  let sourceKindRawValue = statement.string(at: 9),
                  let sourceKind = ContextEfficiencyWorkItemReferenceSource(rawValue: sourceKindRawValue),
                  let confidenceRawValue = statement.string(at: 10),
                  let confidence = ContextEfficiencyWorkItemReferenceConfidence(rawValue: confidenceRawValue),
                  let sourcePath = statement.string(at: 11) else {
                throw ContextEfficiencyStoreError.invalidRow("invalid work item reference row")
            }
            let sourceReference: ContextEfficiencySourceReference?
            if let byteOffset = statement.optionalInt64(at: 12),
               let lineNumber = statement.optionalInt64(at: 13).map(Int.init),
               let parserVersion = statement.optionalInt64(at: 14).map(Int.init) {
                sourceReference = ContextEfficiencySourceReference(
                    sourcePath: sourcePath,
                    byteOffset: byteOffset,
                    lineNumber: lineNumber,
                    parserVersion: parserVersion
                )
            } else {
                sourceReference = nil
            }
            records.append(ContextEfficiencyWorkItemReferenceRecord(
                id: id,
                threadID: threadID,
                kind: kind,
                reference: reference,
                repositorySlug: statement.string(at: 4),
                number: statement.optionalInt64(at: 5).map(Int.init),
                urlString: statement.string(at: 6),
                branchName: statement.string(at: 7),
                ticketKey: statement.string(at: 8),
                sourceKind: sourceKind,
                confidence: confidence,
                sourcePath: sourcePath,
                sourceReference: sourceReference,
                observedAt: date(from: statement.double(at: 15))
            ))
        }
        return records
    }

    private func bind(
        _ sourceReference: ContextEfficiencySourceReference,
        statement: ContextEfficiencySQLiteStatement,
        startingAt index: Int32
    ) throws {
        try statement.bind(sourceReference.sourcePath, at: index)
        try statement.bind(sourceReference.byteOffset, at: index + 1)
        try statement.bind(sourceReference.lineNumber, at: index + 2)
        try statement.bind(sourceReference.parserVersion, at: index + 3)
    }

    private func bind(
        _ tokenUsage: ContextEfficiencyTokenUsage,
        statement: ContextEfficiencySQLiteStatement,
        startingAt index: Int32
    ) throws {
        try statement.bind(tokenUsage.inputTokens, at: index)
        try statement.bind(tokenUsage.cachedInputTokens, at: index + 1)
        try statement.bind(tokenUsage.nonCachedInputTokens, at: index + 2)
        try statement.bind(tokenUsage.outputTokens, at: index + 3)
        try statement.bind(tokenUsage.reasoningOutputTokens, at: index + 4)
        try statement.bind(tokenUsage.totalTokens, at: index + 5)
        try statement.bind(tokenUsage.estimatedContextTokens, at: index + 6)
        try statement.bind(tokenUsage.contextWindowTokens, at: index + 7)
    }

    private func sourceReference(
        statement: ContextEfficiencySQLiteStatement,
        startingAt index: Int32
    ) -> ContextEfficiencySourceReference? {
        guard let sourcePath = statement.string(at: index) else {
            return nil
        }
        return ContextEfficiencySourceReference(
            sourcePath: sourcePath,
            byteOffset: statement.int64(at: index + 1),
            lineNumber: statement.int(at: index + 2),
            parserVersion: statement.int(at: index + 3)
        )
    }

    private func tokenUsage(
        statement: ContextEfficiencySQLiteStatement,
        startingAt index: Int32
    ) -> ContextEfficiencyTokenUsage {
        ContextEfficiencyTokenUsage(
            inputTokens: statement.optionalInt64(at: index),
            cachedInputTokens: statement.optionalInt64(at: index + 1),
            nonCachedInputTokens: statement.optionalInt64(at: index + 2),
            outputTokens: statement.optionalInt64(at: index + 3),
            reasoningOutputTokens: statement.optionalInt64(at: index + 4),
            totalTokens: statement.optionalInt64(at: index + 5),
            estimatedContextTokens: statement.optionalInt64(at: index + 6),
            contextWindowTokens: statement.optionalInt64(at: index + 7)
        )
    }

    private func timestamp(_ date: Date?) -> Double? {
        date?.timeIntervalSince1970
    }

    private func workItemReferenceID(
        _ reference: CodexRolloutParsedWorkItemReference,
        threadID: String
    ) -> String {
        let sourceIdentity: String
        if let sourceReference = reference.sourceReference {
            sourceIdentity = "\(sourceReference.sourcePath):\(sourceReference.lineNumber):\(sourceReference.byteOffset)"
        } else {
            sourceIdentity = reference.sourcePath
        }
        let raw = [
            threadID,
            reference.kind.rawValue,
            reference.reference,
            reference.sourceKind.rawValue,
            sourceIdentity,
        ].joined(separator: "|")
        return "work-item-reference:\(Data(raw.utf8).base64EncodedString())"
    }

    private func date(from timestamp: Double?) -> Date? {
        timestamp.map { Date(timeIntervalSince1970: $0) }
    }

    private func dayRange(for day: String) throws -> (start: Double, end: Double) {
        let parts = day.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else {
            throw ContextEfficiencyStoreError.invalidRow("day must be YYYY-MM-DD")
        }
        var calendar = Calendar(identifier: .gregorian)
        guard let timeZone = TimeZone(secondsFromGMT: 0) else {
            throw ContextEfficiencyStoreError.invalidRow("UTC time zone unavailable")
        }
        calendar.timeZone = timeZone
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = timeZone
        components.year = parts[0]
        components.month = parts[1]
        components.day = parts[2]
        guard let start = calendar.date(from: components),
              let end = calendar.date(byAdding: .day, value: 1, to: start) else {
            throw ContextEfficiencyStoreError.invalidRow("invalid day")
        }
        return (start.timeIntervalSince1970, end.timeIntervalSince1970)
    }
}
