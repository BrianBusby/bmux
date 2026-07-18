import BmuxContextEfficiency
import Dispatch
import Foundation

extension BMUXCLI {
    func runContextEfficiencyCommand(
        commandArgs: [String],
        jsonOutput: Bool,
        processEnv: [String: String] = ProcessInfo.processInfo.environment
    ) throws {
        let subcommand = commandArgs.first?.lowercased()
        switch subcommand {
        case "import":
            try runContextEfficiencyImport(
                commandArgs: Array(commandArgs.dropFirst()),
                jsonOutput: jsonOutput,
                processEnv: processEnv
            )
        case "inspect-thread":
            try runContextEfficiencyInspectThread(
                commandArgs: Array(commandArgs.dropFirst()),
                jsonOutput: jsonOutput
            )
        case "summarize-day":
            try runContextEfficiencySummarizeDay(
                commandArgs: Array(commandArgs.dropFirst()),
                jsonOutput: jsonOutput
            )
        case "help", "--help", "-h", nil:
            print(contextEfficiencyUsage())
        default:
            throw CLIError(message: String.localizedStringWithFormat(
                String(
                    localized: "cli.contextEfficiency.error.unknownSubcommand",
                    defaultValue: "context-efficiency: unknown subcommand '%@'\n\n%@"
                ),
                subcommand ?? "",
                contextEfficiencyUsage()
            ))
        }
    }

    private func runContextEfficiencyImport(
        commandArgs: [String],
        jsonOutput: Bool,
        processEnv: [String: String]
    ) throws {
        let commandName = "context-efficiency import"
        let (databasePath, afterDatabase) = parseOption(commandArgs, name: "--database")
        let (codexHomePath, remainingAfterCodexHome) = parseOption(afterDatabase, name: "--codex-home")
        var remaining = remainingAfterCodexHome
        try rejectContextEfficiencyUnknownFlags(remaining, commandName: commandName)
        guard let rolloutPath = remaining.first else {
            throw CLIError(message: String(localized: "cli.contextEfficiency.error.importRequiresPath", defaultValue: "Usage: bmux context-efficiency import <rollout-path> [--database <path>] [--codex-home <path>] [--json]"))
        }
        remaining.removeFirst()
        guard remaining.isEmpty else {
            throw CLIError(message: contextEfficiencyUnexpectedArgumentMessage(commandName: commandName, argument: remaining[0]))
        }

        let rolloutURL = expandedFileURL(rolloutPath, isDirectory: false)
        guard FileManager.default.fileExists(atPath: rolloutURL.path) else {
            throw CLIError(message: String.localizedStringWithFormat(
                String(localized: "cli.contextEfficiency.error.rolloutMissing", defaultValue: "No rollout JSONL file found at %@"),
                rolloutURL.path
            ), exitCode: 2)
        }

        let metadata = try? contextEfficiencyWait {
            try await contextEfficiencyCodexReader(codexHomePath: codexHomePath, processEnv: processEnv)
                .threadMetadata(forRollout: rolloutURL)
        }
        let databaseURL = contextEfficiencyDatabaseURL(databasePath: databasePath)
        let store = try ContextEfficiencyStore(databaseURL: databaseURL)
        let result = try contextEfficiencyWait {
            try await store.importRollout(at: rolloutURL, fallbackThreadID: metadata?.id, metadata: metadata)
        }
        printContextEfficiencyImportResult(
            result,
            databaseURL: databaseURL,
            metadata: metadata,
            jsonOutput: jsonOutput
        )
    }

    private func runContextEfficiencyInspectThread(commandArgs: [String], jsonOutput: Bool) throws {
        let commandName = "context-efficiency inspect-thread"
        let (databasePath, remainingAfterDatabase) = parseOption(commandArgs, name: "--database")
        var remaining = remainingAfterDatabase
        try rejectContextEfficiencyUnknownFlags(remaining, commandName: commandName)
        guard let threadID = remaining.first else {
            throw CLIError(message: String(localized: "cli.contextEfficiency.error.inspectRequiresThread", defaultValue: "Usage: bmux context-efficiency inspect-thread <thread-id> [--database <path>] [--json]"))
        }
        remaining.removeFirst()
        guard remaining.isEmpty else {
            throw CLIError(message: contextEfficiencyUnexpectedArgumentMessage(commandName: commandName, argument: remaining[0]))
        }

        let databaseURL = contextEfficiencyDatabaseURL(databasePath: databasePath)
        let store = try ContextEfficiencyStore(databaseURL: databaseURL)
        let inspection = try contextEfficiencyWait {
            try await store.inspectThread(contextEfficiencyThreadID(threadID))
        }
        printContextEfficiencyThreadInspection(
            inspection,
            databaseURL: databaseURL,
            jsonOutput: jsonOutput
        )
    }

    private func runContextEfficiencySummarizeDay(commandArgs: [String], jsonOutput: Bool) throws {
        let commandName = "context-efficiency summarize-day"
        let (databasePath, remainingAfterDatabase) = parseOption(commandArgs, name: "--database")
        var remaining = remainingAfterDatabase
        try rejectContextEfficiencyUnknownFlags(remaining, commandName: commandName)
        guard let day = remaining.first else {
            throw CLIError(message: String(localized: "cli.contextEfficiency.error.summarizeRequiresDay", defaultValue: "Usage: bmux context-efficiency summarize-day YYYY-MM-DD [--database <path>] [--json]"))
        }
        remaining.removeFirst()
        guard remaining.isEmpty else {
            throw CLIError(message: contextEfficiencyUnexpectedArgumentMessage(commandName: commandName, argument: remaining[0]))
        }

        let databaseURL = contextEfficiencyDatabaseURL(databasePath: databasePath)
        let store = try ContextEfficiencyStore(databaseURL: databaseURL)
        let summary = try contextEfficiencyWait {
            try await store.summarizeDay(day)
        }
        printContextEfficiencyDaySummary(
            summary,
            databaseURL: databaseURL,
            jsonOutput: jsonOutput
        )
    }

    private func rejectContextEfficiencyUnknownFlags(_ args: [String], commandName: String) throws {
        if let unknown = args.first(where: { $0.hasPrefix("--") }) {
            throw CLIError(message: String.localizedStringWithFormat(
                String(localized: "cli.contextEfficiency.error.unknownFlag", defaultValue: "%@: unknown flag '%@'"),
                commandName,
                unknown
            ))
        }
    }

    private func contextEfficiencyUnexpectedArgumentMessage(commandName: String, argument: String) -> String {
        String.localizedStringWithFormat(
            String(localized: "cli.contextEfficiency.error.unexpectedArgument", defaultValue: "%@: unexpected argument '%@'"),
            commandName,
            argument
        )
    }

    private func contextEfficiencyDatabaseURL(databasePath: String?) -> URL {
        if let databasePath = databasePath?.trimmingCharacters(in: .whitespacesAndNewlines),
           !databasePath.isEmpty {
            return expandedFileURL(databasePath, isDirectory: false)
        }
        return ContextEfficiencyStorageLocation(
            homeDirectory: FileManager.default.homeDirectoryForCurrentUser
        ).databaseURL
    }

    private func contextEfficiencyCodexReader(
        codexHomePath: String?,
        processEnv: [String: String]
    ) -> CodexStateMetadataReader {
        let codexHome = codexHomePath?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            ?? processEnv["CODEX_HOME"]?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        return CodexStateMetadataReader(
            codexHomeURL: codexHome.map { expandedFileURL($0, isDirectory: true) }
        )
    }

    private func expandedFileURL(_ path: String, isDirectory: Bool) -> URL {
        URL(fileURLWithPath: (path as NSString).expandingTildeInPath, isDirectory: isDirectory)
            .standardizedFileURL
    }

    private func contextEfficiencyThreadID(_ rawValue: String) -> String {
        rawValue.hasPrefix("codex:") ? rawValue : "codex:\(rawValue)"
    }

    private func contextEfficiencyWait<Success: Sendable>(
        _ operation: @escaping @Sendable () async throws -> Success
    ) throws -> Success {
        let resultBox = ContextEfficiencyAsyncResultBox<Success>()
        let semaphore = DispatchSemaphore(value: 0)
        Task {
            do {
                resultBox.set(.success(try await operation()))
            } catch {
                resultBox.set(.failure(error))
            }
            semaphore.signal()
        }
        semaphore.wait()
        return try resultBox.value().get()
    }

    private func printContextEfficiencyImportResult(
        _ result: CodexRolloutImportResult,
        databaseURL: URL,
        metadata: CodexStateThreadMetadata?,
        jsonOutput: Bool
    ) {
        if jsonOutput {
            print(jsonString([
                "database_path": databaseURL.path,
                "thread": metadataPayload(metadata),
                "import": importPayload(result),
            ]))
            return
        }

        var lines = [
            String(localized: "cli.contextEfficiency.output.importTitle", defaultValue: "# Context efficiency import"),
            String.localizedStringWithFormat(
                String(localized: "cli.contextEfficiency.output.database", defaultValue: "Database: %@"),
                databaseURL.path
            ),
            String.localizedStringWithFormat(
                String(localized: "cli.contextEfficiency.output.source", defaultValue: "Source: %@"),
                result.sourcePath
            ),
            String.localizedStringWithFormat(
                String(localized: "cli.contextEfficiency.output.thread", defaultValue: "Thread: %@"),
                metadata?.normalizedThreadID ?? String(localized: "cli.contextEfficiency.output.unknown", defaultValue: "unknown")
            ),
            String.localizedStringWithFormat(
                String(localized: "cli.contextEfficiency.output.lines", defaultValue: "Lines imported: %d"),
                result.lineCount
            ),
            String.localizedStringWithFormat(
                String(localized: "cli.contextEfficiency.output.rolloutEvents", defaultValue: "Rollout events: %d"),
                result.rolloutEventCount
            ),
            String.localizedStringWithFormat(
                String(localized: "cli.contextEfficiency.output.modelCalls", defaultValue: "Model calls: %d"),
                result.modelCallCount
            ),
            String.localizedStringWithFormat(
                String(localized: "cli.contextEfficiency.output.duplicates", defaultValue: "Duplicate token telemetry skipped: %d"),
                result.duplicateTokenTelemetryCount
            ),
            String.localizedStringWithFormat(
                String(localized: "cli.contextEfficiency.output.parserErrors", defaultValue: "Parser errors: %d"),
                result.parserErrorCount
            ),
            String.localizedStringWithFormat(
                String(localized: "cli.contextEfficiency.output.toolFacts", defaultValue: "Tool facts: %d calls, %d outputs"),
                result.toolCallCount,
                result.toolOutputCount
            ),
            String.localizedStringWithFormat(
                String(localized: "cli.contextEfficiency.output.compactions", defaultValue: "Compactions: %d"),
                result.compactionCount
            ),
            String.localizedStringWithFormat(
                String(localized: "cli.contextEfficiency.output.cursor", defaultValue: "Cursor: line %d, byte %@"),
                result.cursor.lineNumber,
                contextEfficiencyInteger(result.cursor.byteOffset)
            ),
        ]
        if result.resetCursor {
            lines.append(String(localized: "cli.contextEfficiency.output.cursorReset", defaultValue: "Cursor was reset because the source file shrank."))
        }
        lines.append(String(localized: "cli.contextEfficiency.output.evidenceNote", defaultValue: "Raw rollout content was not copied; source path, line, and byte offsets are stored for recovery."))
        print(lines.joined(separator: "\n"))
    }

    private func printContextEfficiencyThreadInspection(
        _ inspection: ContextEfficiencyThreadInspection,
        databaseURL: URL,
        jsonOutput: Bool
    ) {
        if jsonOutput {
            print(jsonString([
                "database_path": databaseURL.path,
                "thread": inspection.thread.map(threadPayload) as Any,
                "model_calls": inspection.modelCalls.map(modelCallPayload),
                "token_telemetry_events": inspection.tokenTelemetryEvents.map(tokenTelemetryPayload),
                "tool_calls": inspection.toolCalls.map(toolCallPayload),
                "tool_outputs": inspection.toolOutputs.map(toolOutputPayload),
                "command_executions": inspection.commandExecutions.map(commandExecutionPayload),
                "work_item_references": inspection.workItemReferences.map(workItemReferencePayload),
                "parser_errors": inspection.parserErrors.map(parserErrorPayload),
            ]))
            return
        }

        guard let thread = inspection.thread else {
            print(String(localized: "cli.contextEfficiency.output.threadNotFound", defaultValue: "No imported context-efficiency thread found."))
            return
        }

        var lines = [
            String(localized: "cli.contextEfficiency.output.threadTitle", defaultValue: "# Context efficiency thread"),
            String.localizedStringWithFormat(
                String(localized: "cli.contextEfficiency.output.database", defaultValue: "Database: %@"),
                databaseURL.path
            ),
            String.localizedStringWithFormat(
                String(localized: "cli.contextEfficiency.output.thread", defaultValue: "Thread: %@"),
                thread.id
            ),
        ]
        if let rolloutPath = thread.rolloutPath {
            lines.append(String.localizedStringWithFormat(
                String(localized: "cli.contextEfficiency.output.rollout", defaultValue: "Rollout: %@"),
                rolloutPath
            ))
        }
        if let model = thread.model {
            lines.append(String.localizedStringWithFormat(
                String(localized: "cli.contextEfficiency.output.model", defaultValue: "Model: %@"),
                model
            ))
        }
        if let reasoningEffort = thread.reasoningEffort {
            lines.append(String.localizedStringWithFormat(
                String(localized: "cli.contextEfficiency.output.reasoning", defaultValue: "Reasoning: %@"),
                reasoningEffort
            ))
        }
        if let cwd = thread.cwd {
            lines.append(String.localizedStringWithFormat(
                String(localized: "cli.contextEfficiency.output.cwd", defaultValue: "CWD: %@"),
                cwd
            ))
        }
        lines.append(String.localizedStringWithFormat(
            String(localized: "cli.contextEfficiency.output.totals", defaultValue: "Totals: %@ tokens, %d model calls, %d compactions"),
            contextEfficiencyInteger(thread.cumulativeTotalTokens ?? 0),
            thread.modelCallCount,
            thread.compactionCount
        ))
        lines.append(String(localized: "cli.contextEfficiency.output.sourcesHeader", defaultValue: "## Source evidence"))
        appendModelCallRows(inspection.modelCalls, to: &lines)
        appendToolCallRows(inspection.toolCalls, to: &lines)
        appendToolOutputRows(inspection.toolOutputs, to: &lines)
        appendParserErrorRows(inspection.parserErrors, to: &lines)
        print(lines.joined(separator: "\n"))
    }

    private func printContextEfficiencyDaySummary(
        _ summary: ContextEfficiencyDaySummary,
        databaseURL: URL,
        jsonOutput: Bool
    ) {
        if jsonOutput {
            print(jsonString([
                "database_path": databaseURL.path,
                "summary": [
                    "day": summary.day,
                    "thread_count": summary.threadCount,
                    "model_call_count": summary.modelCallCount,
                    "total_tokens": summary.totalTokens,
                    "cached_input_tokens": summary.cachedInputTokens,
                    "output_tokens": summary.outputTokens,
                    "parser_error_count": summary.parserErrorCount,
                ],
            ]))
            return
        }

        print([
            String.localizedStringWithFormat(
                String(localized: "cli.contextEfficiency.output.dayTitle", defaultValue: "# Context efficiency day %@"),
                summary.day
            ),
            String.localizedStringWithFormat(
                String(localized: "cli.contextEfficiency.output.database", defaultValue: "Database: %@"),
                databaseURL.path
            ),
            String.localizedStringWithFormat(
                String(localized: "cli.contextEfficiency.output.threads", defaultValue: "Threads: %d"),
                summary.threadCount
            ),
            String.localizedStringWithFormat(
                String(localized: "cli.contextEfficiency.output.modelCalls", defaultValue: "Model calls: %d"),
                summary.modelCallCount
            ),
            String.localizedStringWithFormat(
                String(localized: "cli.contextEfficiency.output.totalTokens", defaultValue: "Total tokens: %@"),
                contextEfficiencyInteger(summary.totalTokens)
            ),
            String.localizedStringWithFormat(
                String(localized: "cli.contextEfficiency.output.cachedInput", defaultValue: "Cached input tokens: %@"),
                contextEfficiencyInteger(summary.cachedInputTokens)
            ),
            String.localizedStringWithFormat(
                String(localized: "cli.contextEfficiency.output.outputTokens", defaultValue: "Output tokens: %@"),
                contextEfficiencyInteger(summary.outputTokens)
            ),
            String.localizedStringWithFormat(
                String(localized: "cli.contextEfficiency.output.parserErrors", defaultValue: "Parser errors: %d"),
                summary.parserErrorCount
            ),
        ].joined(separator: "\n"))
    }

    private func appendModelCallRows(_ records: [ContextEfficiencyModelCallRecord], to lines: inout [String]) {
        guard !records.isEmpty else { return }
        lines.append(String(localized: "cli.contextEfficiency.output.modelCallHeader", defaultValue: "Model-call evidence:"))
        for record in records.prefix(10) {
            lines.append(String.localizedStringWithFormat(
                String(localized: "cli.contextEfficiency.output.modelCallRow", defaultValue: "  line %d byte %@ total %@ cached %@ output %@"),
                record.sourceReference.lineNumber,
                contextEfficiencyInteger(record.sourceReference.byteOffset),
                contextEfficiencyInteger(record.tokenUsage.totalTokens ?? 0),
                contextEfficiencyInteger(record.tokenUsage.cachedInputTokens ?? 0),
                contextEfficiencyInteger(record.tokenUsage.outputTokens ?? 0)
            ))
        }
    }

    private func appendToolCallRows(_ records: [ContextEfficiencyToolCallRecord], to lines: inout [String]) {
        guard !records.isEmpty else { return }
        lines.append(String(localized: "cli.contextEfficiency.output.toolCallHeader", defaultValue: "Tool-call evidence:"))
        for record in records.prefix(10) {
            lines.append(String.localizedStringWithFormat(
                String(localized: "cli.contextEfficiency.output.toolCallRow", defaultValue: "  line %d byte %@ %@ args %@ bytes"),
                record.sourceReference.lineNumber,
                contextEfficiencyInteger(record.sourceReference.byteOffset),
                record.commandSummary ?? record.toolName ?? String(localized: "cli.contextEfficiency.output.unknown", defaultValue: "unknown"),
                contextEfficiencyInteger(record.argumentsByteCount)
            ))
        }
    }

    private func appendToolOutputRows(_ records: [ContextEfficiencyToolOutputRecord], to lines: inout [String]) {
        guard !records.isEmpty else { return }
        lines.append(String(localized: "cli.contextEfficiency.output.toolOutputHeader", defaultValue: "Tool-output evidence:"))
        for record in records.prefix(10) {
            lines.append(String.localizedStringWithFormat(
                String(localized: "cli.contextEfficiency.output.toolOutputRow", defaultValue: "  line %d byte %@ output %@ bytes estimated-original %@ tokens raw refs %d"),
                record.sourceReference.lineNumber,
                contextEfficiencyInteger(record.sourceReference.byteOffset),
                contextEfficiencyInteger(record.outputByteCount),
                contextEfficiencyInteger(record.estimatedOriginalTokens),
                record.rawOutputReferenceCount
            ))
        }
    }

    private func appendParserErrorRows(_ records: [ContextEfficiencyParserErrorRecord], to lines: inout [String]) {
        guard !records.isEmpty else { return }
        lines.append(String(localized: "cli.contextEfficiency.output.parserErrorHeader", defaultValue: "Parser errors:"))
        for record in records.prefix(10) {
            lines.append(String.localizedStringWithFormat(
                String(localized: "cli.contextEfficiency.output.parserErrorRow", defaultValue: "  line %d byte %@ %@"),
                record.sourceReference.lineNumber,
                contextEfficiencyInteger(record.sourceReference.byteOffset),
                record.message
            ))
        }
    }

    private func importPayload(_ result: CodexRolloutImportResult) -> [String: Any] {
        [
            "source_path": result.sourcePath,
            "line_count": result.lineCount,
            "rollout_event_count": result.rolloutEventCount,
            "model_call_count": result.modelCallCount,
            "duplicate_token_telemetry_count": result.duplicateTokenTelemetryCount,
            "parser_error_count": result.parserErrorCount,
            "tool_call_count": result.toolCallCount,
            "tool_output_count": result.toolOutputCount,
            "compaction_count": result.compactionCount,
            "reset_cursor": result.resetCursor,
            "cursor": cursorPayload(result.cursor),
        ]
    }

    private func metadataPayload(_ metadata: CodexStateThreadMetadata?) -> [String: Any] {
        guard let metadata else { return [:] }
        return [
            "id": metadata.id,
            "normalized_thread_id": metadata.normalizedThreadID,
            "rollout_path": metadata.rolloutPath as Any,
            "cwd": metadata.cwd as Any,
            "title": metadata.title as Any,
            "model_provider": metadata.modelProvider as Any,
            "model": metadata.model as Any,
            "reasoning_effort": metadata.reasoningEffort as Any,
            "approval_mode": metadata.approvalMode as Any,
            "sandbox_policy_type": metadata.sandboxPolicyType as Any,
            "git_branch": metadata.gitBranch as Any,
            "tokens_used": metadata.tokensUsed as Any,
            "created_at": metadata.createdAt.map(contextEfficiencyDateString) as Any,
            "updated_at": metadata.updatedAt.map(contextEfficiencyDateString) as Any,
        ].compactMapValues(contextEfficiencyUnwrappedValue)
    }

    private func threadPayload(_ thread: ContextEfficiencyAgentThreadRecord) -> [String: Any] {
        [
            "id": thread.id,
            "external_thread_id": thread.externalThreadID as Any,
            "rollout_path": thread.rolloutPath as Any,
            "model": thread.model as Any,
            "reasoning_effort": thread.reasoningEffort as Any,
            "cwd": thread.cwd as Any,
            "first_observed_at": thread.firstObservedAt.map(contextEfficiencyDateString) as Any,
            "last_observed_at": thread.lastObservedAt.map(contextEfficiencyDateString) as Any,
            "cumulative_total_tokens": thread.cumulativeTotalTokens as Any,
            "model_call_count": thread.modelCallCount,
            "compaction_count": thread.compactionCount,
        ].compactMapValues(contextEfficiencyUnwrappedValue)
    }

    private func modelCallPayload(_ record: ContextEfficiencyModelCallRecord) -> [String: Any] {
        [
            "id": record.id,
            "thread_id": record.threadID,
            "timestamp": record.timestamp.map(contextEfficiencyDateString) as Any,
            "token_usage": tokenUsagePayload(record.tokenUsage),
            "source_reference": sourceReferencePayload(record.sourceReference),
            "telemetry_confidence": record.telemetryConfidence,
        ].compactMapValues(contextEfficiencyUnwrappedValue)
    }

    private func tokenTelemetryPayload(_ record: ContextEfficiencyTokenTelemetryRecord) -> [String: Any] {
        [
            "id": record.id,
            "thread_id": record.threadID,
            "timestamp": record.timestamp.map(contextEfficiencyDateString) as Any,
            "token_usage": tokenUsagePayload(record.tokenUsage),
            "source_reference": sourceReferencePayload(record.sourceReference),
        ].compactMapValues(contextEfficiencyUnwrappedValue)
    }

    private func toolCallPayload(_ record: ContextEfficiencyToolCallRecord) -> [String: Any] {
        [
            "id": record.id,
            "thread_id": record.threadID,
            "call_id": record.callID as Any,
            "tool_name": record.toolName as Any,
            "command_summary": record.commandSummary as Any,
            "arguments_byte_count": record.argumentsByteCount,
            "timestamp": record.timestamp.map(contextEfficiencyDateString) as Any,
            "source_reference": sourceReferencePayload(record.sourceReference),
        ].compactMapValues(contextEfficiencyUnwrappedValue)
    }

    private func toolOutputPayload(_ record: ContextEfficiencyToolOutputRecord) -> [String: Any] {
        [
            "id": record.id,
            "thread_id": record.threadID,
            "call_id": record.callID as Any,
            "output_byte_count": record.outputByteCount,
            "estimated_original_tokens": record.estimatedOriginalTokens,
            "raw_output_reference_count": record.rawOutputReferenceCount,
            "timestamp": record.timestamp.map(contextEfficiencyDateString) as Any,
            "source_reference": sourceReferencePayload(record.sourceReference),
        ].compactMapValues(contextEfficiencyUnwrappedValue)
    }

    private func commandExecutionPayload(_ record: ContextEfficiencyCommandExecutionRecord) -> [String: Any] {
        [
            "id": record.id,
            "thread_id": record.threadID,
            "call_id": record.callID as Any,
            "tool_name": record.toolName as Any,
            "command_summary": record.commandSummary as Any,
            "normalized_executable": record.normalizedExecutable as Any,
            "category": record.category.rawValue,
            "arguments_byte_count": record.argumentsByteCount,
            "output_byte_count": record.outputByteCount as Any,
            "estimated_original_output_tokens": record.estimatedOriginalOutputTokens as Any,
            "raw_output_reference_count": record.rawOutputReferenceCount,
            "started_at": record.startedAt.map(contextEfficiencyDateString) as Any,
            "completed_at": record.completedAt.map(contextEfficiencyDateString) as Any,
            "elapsed_seconds": record.elapsedSeconds as Any,
            "tool_call_source_reference": sourceReferencePayload(record.toolCallSourceReference),
            "tool_output_source_reference": record.toolOutputSourceReference.map(sourceReferencePayload) as Any,
            "output_attribution_confidence": record.outputAttributionConfidence.rawValue,
            "attributed_model_call": record.attributedModelCall.map(modelCallAttributionPayload) as Any,
        ].compactMapValues(contextEfficiencyUnwrappedValue)
    }

    private func workItemReferencePayload(_ record: ContextEfficiencyWorkItemReferenceRecord) -> [String: Any] {
        [
            "id": record.id,
            "thread_id": record.threadID,
            "kind": record.kind.rawValue,
            "reference": record.reference,
            "repository_slug": record.repositorySlug as Any,
            "number": record.number as Any,
            "url_string": record.urlString as Any,
            "branch_name": record.branchName as Any,
            "ticket_key": record.ticketKey as Any,
            "source_kind": record.sourceKind.rawValue,
            "confidence": record.confidence.rawValue,
            "source_path": record.sourcePath,
            "source_reference": record.sourceReference.map(sourceReferencePayload) as Any,
            "observed_at": record.observedAt.map(contextEfficiencyDateString) as Any,
        ].compactMapValues(contextEfficiencyUnwrappedValue)
    }

    private func modelCallAttributionPayload(_ record: ContextEfficiencyModelCallAttribution) -> [String: Any] {
        [
            "model_call_id": record.modelCallID,
            "confidence": record.confidence.rawValue,
            "model_call_source_reference": sourceReferencePayload(record.modelCallSourceReference),
        ]
    }

    private func parserErrorPayload(_ record: ContextEfficiencyParserErrorRecord) -> [String: Any] {
        [
            "id": record.id,
            "message": record.message,
            "rollout_type": record.rolloutType as Any,
            "source_reference": sourceReferencePayload(record.sourceReference),
            "imported_at": contextEfficiencyDateString(record.importedAt),
        ].compactMapValues(contextEfficiencyUnwrappedValue)
    }

    private func cursorPayload(_ cursor: CodexRolloutImportCursor) -> [String: Any] {
        [
            "source_path": cursor.sourcePath,
            "byte_offset": cursor.byteOffset,
            "line_number": cursor.lineNumber,
            "file_size": cursor.fileSize,
            "parser_version": cursor.parserVersion,
            "updated_at": contextEfficiencyDateString(cursor.updatedAt),
        ]
    }

    private func sourceReferencePayload(_ reference: ContextEfficiencySourceReference) -> [String: Any] {
        [
            "source_path": reference.sourcePath,
            "byte_offset": reference.byteOffset,
            "line_number": reference.lineNumber,
            "parser_version": reference.parserVersion,
        ]
    }

    private func tokenUsagePayload(_ usage: ContextEfficiencyTokenUsage) -> [String: Any] {
        [
            "input_tokens": usage.inputTokens as Any,
            "cached_input_tokens": usage.cachedInputTokens as Any,
            "non_cached_input_tokens": usage.nonCachedInputTokens as Any,
            "output_tokens": usage.outputTokens as Any,
            "reasoning_output_tokens": usage.reasoningOutputTokens as Any,
            "total_tokens": usage.totalTokens as Any,
            "estimated_context_tokens": usage.estimatedContextTokens as Any,
            "context_window_tokens": usage.contextWindowTokens as Any,
        ].compactMapValues(contextEfficiencyUnwrappedValue)
    }

    private func contextEfficiencyUnwrappedValue(_ value: Any) -> Any? {
        let mirror = Mirror(reflecting: value)
        guard mirror.displayStyle == .optional else { return value }
        return mirror.children.first?.value
    }

    private func contextEfficiencyDateString(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    private func contextEfficiencyInteger(_ value: Int64) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    func contextEfficiencyUsage() -> String {
        String(
            localized: "cli.contextEfficiency.usage",
            defaultValue: """
            Usage:
              bmux context-efficiency import <rollout-path> [--database <path>] [--codex-home <path>] [--json]
              bmux context-efficiency inspect-thread <thread-id> [--database <path>] [--json]
              bmux context-efficiency summarize-day YYYY-MM-DD [--database <path>] [--json]

            Import and inspect read-only Codex rollout telemetry without copying raw rollout payloads.
            """
        )
    }
}

private final class ContextEfficiencyAsyncResultBox<Success: Sendable>: @unchecked Sendable {
    // Synchronous CLI entry points need one exact handoff from an async Task.
    private let lock = NSLock()
    private var result: Result<Success, Error>?

    func set(_ result: Result<Success, Error>) {
        lock.lock()
        self.result = result
        lock.unlock()
    }

    func value() throws -> Result<Success, Error> {
        lock.lock()
        defer { lock.unlock() }
        guard let result else {
            throw CLIError(message: String(localized: "cli.contextEfficiency.error.asyncResultMissing", defaultValue: "context-efficiency command did not produce a result"))
        }
        return result
    }
}
