import Foundation
import SQLite3

struct CLICodexTokenAuditReport: Codable {
    var databasePath: String
    var codexHomePath: String?
    var generatedAt: String
    var sessionCount: Int
    var totalTokens: Int64
    var largestSessionTokens: Int64
    var averageTokensPerSession: Double
    var sessions: [CLICodexTokenAuditSession]
    var updatedDayTotals: [CLICodexTokenAuditDayTotal]
    var modelTotals: [CLICodexTokenAuditModelTotal]
    var cwdTotals: [CLICodexTokenAuditCWDTotal]
    var notes: [String]

    enum CodingKeys: String, CodingKey {
        case databasePath = "database_path"
        case codexHomePath = "codex_home_path"
        case generatedAt = "generated_at"
        case sessionCount = "session_count"
        case totalTokens = "total_tokens"
        case largestSessionTokens = "largest_session_tokens"
        case averageTokensPerSession = "average_tokens_per_session"
        case sessions
        case updatedDayTotals = "updated_day_totals"
        case modelTotals = "model_totals"
        case cwdTotals = "cwd_totals"
        case notes
    }
}

struct CLICodexTokenAuditSession: Codable {
    var id: String
    var tokensUsed: Int64
    var createdAt: String?
    var updatedAt: String?
    var updatedDay: String?
    var source: String?
    var modelProvider: String?
    var model: String?
    var cwd: String?
    var gitBranch: String?
    var gitOriginURL: String?
    var cliVersion: String?
    var rolloutPath: String?
    var sessionSpanSeconds: Double?
    var analysis: CLICodexTokenAuditSessionAnalysis?
    var title: String?
    var preview: String?

    enum CodingKeys: String, CodingKey {
        case id
        case tokensUsed = "tokens_used"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case updatedDay = "updated_day"
        case source
        case modelProvider = "model_provider"
        case model
        case cwd
        case gitBranch = "git_branch"
        case gitOriginURL = "git_origin_url"
        case cliVersion = "cli_version"
        case rolloutPath = "rollout_path"
        case sessionSpanSeconds = "session_span_seconds"
        case analysis
        case title
        case preview
    }
}

struct CLICodexTokenAuditDayTotal: Codable {
    var day: String
    var sessionCount: Int
    var tokens: Int64

    enum CodingKeys: String, CodingKey {
        case day
        case sessionCount = "session_count"
        case tokens
    }
}

struct CLICodexTokenAuditModelTotal: Codable {
    var modelProvider: String?
    var model: String?
    var sessionCount: Int
    var tokens: Int64

    enum CodingKeys: String, CodingKey {
        case modelProvider = "model_provider"
        case model
        case sessionCount = "session_count"
        case tokens
    }
}

struct CLICodexTokenAuditCWDTotal: Codable {
    var cwd: String
    var sessionCount: Int
    var tokens: Int64
    var rolloutBytes: Int64
    var toolOutputBytes: Int64

    enum CodingKeys: String, CodingKey {
        case cwd
        case sessionCount = "session_count"
        case tokens
        case rolloutBytes = "rollout_bytes"
        case toolOutputBytes = "tool_output_bytes"
    }
}

struct CLICodexTokenAuditSessionAnalysis: Codable {
    var rolloutExists: Bool
    var rolloutBytes: Int64
    var rolloutLineCount: Int
    var rolloutEventCount: Int
    var turnContextCount: Int
    var userMessageCount: Int
    var assistantMessageCount: Int
    var toolCallCount: Int
    var toolOutputCount: Int
    var toolOutputBytes: Int64
    var estimatedToolOutputTokens: Int64
    var rawOutputRefCount: Int
    var largestToolOutputBytes: Int64
    var largestToolOutputTool: String?
    var largestToolOutputCommand: String?
    var repeatedCommandCount: Int
    var topRepeatedCommands: [CLICodexTokenAuditRepeatedCommand]
    var driverIDs: [String]

    enum CodingKeys: String, CodingKey {
        case rolloutExists = "rollout_exists"
        case rolloutBytes = "rollout_bytes"
        case rolloutLineCount = "rollout_line_count"
        case rolloutEventCount = "rollout_event_count"
        case turnContextCount = "turn_context_count"
        case userMessageCount = "user_message_count"
        case assistantMessageCount = "assistant_message_count"
        case toolCallCount = "tool_call_count"
        case toolOutputCount = "tool_output_count"
        case toolOutputBytes = "tool_output_bytes"
        case estimatedToolOutputTokens = "estimated_tool_output_tokens"
        case rawOutputRefCount = "raw_output_ref_count"
        case largestToolOutputBytes = "largest_tool_output_bytes"
        case largestToolOutputTool = "largest_tool_output_tool"
        case largestToolOutputCommand = "largest_tool_output_command"
        case repeatedCommandCount = "repeated_command_count"
        case topRepeatedCommands = "top_repeated_commands"
        case driverIDs = "driver_ids"
    }
}

struct CLICodexTokenAuditRepeatedCommand: Codable {
    var command: String
    var count: Int
    var outputBytes: Int64
    var estimatedOutputTokens: Int64

    enum CodingKeys: String, CodingKey {
        case command
        case count
        case outputBytes = "output_bytes"
        case estimatedOutputTokens = "estimated_output_tokens"
    }
}

private struct CLICodexTokenAuditToolCallInfo {
    var toolName: String?
    var command: String?
}

private struct CLICodexTokenAuditCommandStats {
    var command: String
    var count = 0
    var outputBytes: Int64 = 0
    var estimatedOutputTokens: Int64 = 0
}

private struct CLICodexTokenAuditRolloutAnalyzer {
    private static let rawOutputHint = "Raw output: bmux agent-token-output show"
    private static let maxCommandCharacters = 180

    static func analyze(path: String) -> CLICodexTokenAuditSessionAnalysis {
        let expandedPath = NSString(string: path).expandingTildeInPath
        let fileURL = URL(fileURLWithPath: expandedPath)
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return emptyAnalysis(rolloutExists: false)
        }

        let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path)
        let rolloutBytes = (attributes?[.size] as? NSNumber)?.int64Value ?? 0
        guard let data = try? Data(contentsOf: fileURL),
              let contents = String(data: data, encoding: .utf8) else {
            var analysis = emptyAnalysis(rolloutExists: true)
            analysis.rolloutBytes = rolloutBytes
            analysis.driverIDs = driverIDs(for: analysis)
            return analysis
        }

        var lineCount = 0
        var eventCount = 0
        var turnContextCount = 0
        var userMessageCount = 0
        var assistantMessageCount = 0
        var toolCallCount = 0
        var toolOutputCount = 0
        var toolOutputBytes: Int64 = 0
        var estimatedToolOutputTokens: Int64 = 0
        var rawOutputRefCount = 0
        var largestToolOutputBytes: Int64 = 0
        var largestToolOutputTool: String?
        var largestToolOutputCommand: String?
        var callsByID: [String: CLICodexTokenAuditToolCallInfo] = [:]
        var commandStats: [String: CLICodexTokenAuditCommandStats] = [:]

        contents.enumerateLines { line, _ in
            lineCount += 1
            guard let object = jsonObject(from: line),
                  let type = object["type"] as? String else {
                return
            }
            eventCount += 1

            switch type {
            case "turn_context":
                turnContextCount += 1
            case "event_msg":
                if let payload = object["payload"] as? [String: Any],
                   let payloadType = payload["type"] as? String {
                    if payloadType == "user_message" {
                        userMessageCount += 1
                    } else if payloadType == "agent_message" {
                        assistantMessageCount += 1
                    }
                }
            case "response_item":
                guard let payload = object["payload"] as? [String: Any],
                      let payloadType = payload["type"] as? String else {
                    return
                }
                if payloadType == "message" {
                    if (payload["role"] as? String) == "assistant" {
                        assistantMessageCount += 1
                    }
                } else if payloadType == "function_call" {
                    toolCallCount += 1
                    let callID = payload["call_id"] as? String
                    let toolName = payload["name"] as? String
                    let command = commandSummary(fromArguments: payload["arguments"] as? String)
                    if let callID {
                        callsByID[callID] = CLICodexTokenAuditToolCallInfo(toolName: toolName, command: command)
                    }
                    if let command {
                        var stats = commandStats[command] ?? CLICodexTokenAuditCommandStats(command: command)
                        stats.count += 1
                        commandStats[command] = stats
                    }
                } else if payloadType == "function_call_output" {
                    toolOutputCount += 1
                    let output = payload["output"] as? String ?? ""
                    let outputByteCount = Int64(output.lengthOfBytes(using: .utf8))
                    let outputTokenCount = estimatedOriginalTokenCount(in: output)
                    toolOutputBytes += outputByteCount
                    estimatedToolOutputTokens += outputTokenCount
                    rawOutputRefCount += countOccurrences(of: rawOutputHint, in: output)

                    let callInfo = (payload["call_id"] as? String).flatMap { callsByID[$0] }
                    let command = callInfo?.command
                    if let command {
                        var stats = commandStats[command] ?? CLICodexTokenAuditCommandStats(command: command)
                        stats.outputBytes += outputByteCount
                        stats.estimatedOutputTokens += outputTokenCount
                        commandStats[command] = stats
                    }

                    if outputByteCount > largestToolOutputBytes {
                        largestToolOutputBytes = outputByteCount
                        largestToolOutputTool = callInfo?.toolName
                        largestToolOutputCommand = command
                    }
                }
            default:
                break
            }
        }

        let repeatedCommands = commandStats.values
            .filter { $0.count > 1 }
            .sorted {
                if $0.count == $1.count {
                    return $0.outputBytes > $1.outputBytes
                }
                return $0.count > $1.count
            }
        let repeatedCommandCount = repeatedCommands.reduce(0) { $0 + max(0, $1.count - 1) }
        var analysis = CLICodexTokenAuditSessionAnalysis(
            rolloutExists: true,
            rolloutBytes: rolloutBytes,
            rolloutLineCount: lineCount,
            rolloutEventCount: eventCount,
            turnContextCount: turnContextCount,
            userMessageCount: userMessageCount,
            assistantMessageCount: assistantMessageCount,
            toolCallCount: toolCallCount,
            toolOutputCount: toolOutputCount,
            toolOutputBytes: toolOutputBytes,
            estimatedToolOutputTokens: estimatedToolOutputTokens,
            rawOutputRefCount: rawOutputRefCount,
            largestToolOutputBytes: largestToolOutputBytes,
            largestToolOutputTool: largestToolOutputTool,
            largestToolOutputCommand: largestToolOutputCommand,
            repeatedCommandCount: repeatedCommandCount,
            topRepeatedCommands: repeatedCommands.prefix(5).map {
                CLICodexTokenAuditRepeatedCommand(
                    command: $0.command,
                    count: $0.count,
                    outputBytes: $0.outputBytes,
                    estimatedOutputTokens: $0.estimatedOutputTokens
                )
            },
            driverIDs: []
        )
        analysis.driverIDs = driverIDs(for: analysis)
        return analysis
    }

    private static func emptyAnalysis(rolloutExists: Bool) -> CLICodexTokenAuditSessionAnalysis {
        CLICodexTokenAuditSessionAnalysis(
            rolloutExists: rolloutExists,
            rolloutBytes: 0,
            rolloutLineCount: 0,
            rolloutEventCount: 0,
            turnContextCount: 0,
            userMessageCount: 0,
            assistantMessageCount: 0,
            toolCallCount: 0,
            toolOutputCount: 0,
            toolOutputBytes: 0,
            estimatedToolOutputTokens: 0,
            rawOutputRefCount: 0,
            largestToolOutputBytes: 0,
            largestToolOutputTool: nil,
            largestToolOutputCommand: nil,
            repeatedCommandCount: 0,
            topRepeatedCommands: [],
            driverIDs: []
        )
    }

    private static func driverIDs(for analysis: CLICodexTokenAuditSessionAnalysis) -> [String] {
        var ids: [String] = []
        if analysis.rolloutBytes >= 5_000_000 {
            ids.append("large_rollout")
        }
        if analysis.toolOutputBytes >= 1_000_000 || analysis.estimatedToolOutputTokens >= 100_000 {
            ids.append("large_tool_output")
        }
        if analysis.repeatedCommandCount >= 10 {
            ids.append("repeated_commands")
        }
        if analysis.turnContextCount >= 50 {
            ids.append("many_turns")
        }
        if analysis.rawOutputRefCount >= 10 {
            ids.append("many_recoverable_outputs")
        }
        return ids
    }

    private static func jsonObject(from line: String) -> [String: Any]? {
        guard let data = line.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return object
    }

    private static func commandSummary(fromArguments arguments: String?) -> String? {
        guard let arguments = arguments?.trimmingCharacters(in: .whitespacesAndNewlines),
              !arguments.isEmpty else {
            return nil
        }
        if let data = arguments.data(using: .utf8),
           let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            for key in ["cmd", "command"] {
                if let value = object[key] as? String,
                   let summary = summarizedCommand(value) {
                    return summary
                }
            }
        }
        return summarizedCommand(arguments)
    }

    private static func summarizedCommand(_ command: String) -> String? {
        let collapsed = command
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        guard !collapsed.isEmpty else {
            return nil
        }
        guard collapsed.count > maxCommandCharacters else {
            return collapsed
        }
        return String(collapsed.prefix(maxCommandCharacters - 3)) + "..."
    }

    private static func estimatedOriginalTokenCount(in output: String) -> Int64 {
        let marker = "Original token count:"
        guard let range = output.range(of: marker) else {
            return 0
        }
        let suffix = output[range.upperBound...]
        let digits = suffix.drop(while: { !$0.isNumber })
            .prefix(while: { $0.isNumber })
        return Int64(digits) ?? 0
    }

    private static func countOccurrences(of needle: String, in haystack: String) -> Int {
        guard !needle.isEmpty else {
            return 0
        }
        var count = 0
        var searchRange = haystack.startIndex..<haystack.endIndex
        while let range = haystack.range(of: needle, options: [], range: searchRange) {
            count += 1
            searchRange = range.upperBound..<haystack.endIndex
        }
        return count
    }
}

final class CLICodexTokenAuditSQLiteReader {
    private var handle: OpaquePointer?

    init(databaseURL: URL) throws {
        var opened: OpaquePointer?
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(databaseURL.path, &opened, flags, nil) == SQLITE_OK, let opened else {
            let message = opened.flatMap { sqlite3_errmsg($0) }.map { String(cString: $0) }
                ?? String(localized: "cli.codexTokenAudit.error.openFailedFallback", defaultValue: "open failed")
            if let opened {
                sqlite3_close(opened)
            }
            throw CLIError(message: String.localizedStringWithFormat(
                String(
                    localized: "cli.codexTokenAudit.error.openDatabaseFailed",
                    defaultValue: "failed to open Codex session database: %@"
                ),
                message
            ))
        }
        self.handle = opened
    }

    deinit {
        if let handle {
            sqlite3_close(handle)
        }
    }

    func report(databasePath: String, codexHomePath: String?, generatedAt: Date = Date()) throws -> CLICodexTokenAuditReport {
        let sessions = try readSessions()
        let totalTokens = sessions.reduce(Int64(0)) { $0 + $1.tokensUsed }
        let largestSessionTokens = sessions.first?.tokensUsed ?? 0
        let average = sessions.isEmpty ? 0 : Double(totalTokens) / Double(sessions.count)
        return CLICodexTokenAuditReport(
            databasePath: databasePath,
            codexHomePath: codexHomePath,
            generatedAt: Self.isoString(generatedAt),
            sessionCount: sessions.count,
            totalTokens: totalTokens,
            largestSessionTokens: largestSessionTokens,
            averageTokensPerSession: average,
            sessions: sessions,
            updatedDayTotals: dayTotals(from: sessions),
            modelTotals: modelTotals(from: sessions),
            cwdTotals: cwdTotals(from: sessions),
            notes: [
                String(
                    localized: "cli.codexTokenAudit.note.updatedDayGrouping",
                    defaultValue: "Updated-day totals group each session's lifetime tokens by threads.updated_at; they are not provider billing day totals."
                ),
                String(
                    localized: "cli.codexTokenAudit.note.providerBreakdownUnavailable",
                    defaultValue: "Local Codex metadata does not expose cached-input, uncached-input, output, or reasoning-token splits."
                ),
                String(
                    localized: "cli.codexTokenAudit.note.rolloutAnalysis",
                    defaultValue: "Rollout analysis uses local session JSONL files to estimate tool-output pressure, repeated commands, and likely waste drivers."
                )
            ]
        )
    }

    private func readSessions() throws -> [CLICodexTokenAuditSession] {
        let statement = try prepare(
            """
            SELECT id, COALESCE(tokens_used, 0), created_at, updated_at,
                   source, model_provider, model, cwd, git_branch,
                   git_origin_url, cli_version, rollout_path, title, preview
            FROM threads
            ORDER BY COALESCE(tokens_used, 0) DESC, updated_at DESC, rowid DESC
            """
        )
        defer { sqlite3_finalize(statement) }

        var rows: [CLICodexTokenAuditSession] = []
        while true {
            let step = sqlite3_step(statement)
            if step == SQLITE_DONE {
                break
            }
            guard step == SQLITE_ROW else {
                throw CLIError(message: sqliteMessage)
            }

            guard let id = string(statement, 0) else {
                continue
            }
            let createdTimestamp = timestamp(statement, 2)
            let updatedTimestamp = timestamp(statement, 3)
            let rolloutPath = string(statement, 11)
            let sessionSpanSeconds: Double?
            if let createdTimestamp, let updatedTimestamp {
                sessionSpanSeconds = max(0, updatedTimestamp - createdTimestamp)
            } else {
                sessionSpanSeconds = nil
            }
            var analysis = rolloutPath.map { CLICodexTokenAuditRolloutAnalyzer.analyze(path: $0) }
            if var rolloutAnalysis = analysis,
               let sessionSpanSeconds,
               sessionSpanSeconds >= 21_600,
               !rolloutAnalysis.driverIDs.contains("long_running_session") {
                rolloutAnalysis.driverIDs.append("long_running_session")
                analysis = rolloutAnalysis
            }
            rows.append(CLICodexTokenAuditSession(
                id: id,
                tokensUsed: sqlite3_column_int64(statement, 1),
                createdAt: createdTimestamp.map(Self.isoString),
                updatedAt: updatedTimestamp.map(Self.isoString),
                updatedDay: updatedTimestamp.map(Self.dayString),
                source: string(statement, 4),
                modelProvider: string(statement, 5),
                model: string(statement, 6),
                cwd: string(statement, 7),
                gitBranch: string(statement, 8),
                gitOriginURL: string(statement, 9),
                cliVersion: string(statement, 10),
                rolloutPath: rolloutPath,
                sessionSpanSeconds: sessionSpanSeconds,
                analysis: analysis,
                title: string(statement, 12),
                preview: string(statement, 13)
            ))
        }
        return rows
    }

    private func dayTotals(from sessions: [CLICodexTokenAuditSession]) -> [CLICodexTokenAuditDayTotal] {
        var totals: [String: (count: Int, tokens: Int64)] = [:]
        let unknown = String(localized: "cli.codexTokenAudit.output.unknown", defaultValue: "unknown")
        for session in sessions {
            let day = session.updatedDay ?? unknown
            let current = totals[day] ?? (0, 0)
            totals[day] = (current.count + 1, current.tokens + session.tokensUsed)
        }
        return totals.map { day, total in
            CLICodexTokenAuditDayTotal(day: day, sessionCount: total.count, tokens: total.tokens)
        }
        .sorted {
            if $0.tokens == $1.tokens {
                return $0.day > $1.day
            }
            return $0.tokens > $1.tokens
        }
    }

    private func modelTotals(from sessions: [CLICodexTokenAuditSession]) -> [CLICodexTokenAuditModelTotal] {
        struct ModelKey: Hashable {
            var provider: String?
            var model: String?
        }

        var totals: [ModelKey: (count: Int, tokens: Int64)] = [:]
        for session in sessions {
            let key = ModelKey(provider: session.modelProvider ?? session.source, model: session.model)
            let current = totals[key] ?? (0, 0)
            totals[key] = (current.count + 1, current.tokens + session.tokensUsed)
        }
        return totals.map { key, total in
            CLICodexTokenAuditModelTotal(
                modelProvider: key.provider,
                model: key.model,
                sessionCount: total.count,
                tokens: total.tokens
            )
        }
        .sorted {
            if $0.tokens == $1.tokens {
                return Self.modelIdentity($0) < Self.modelIdentity($1)
            }
            return $0.tokens > $1.tokens
        }
    }

    private func cwdTotals(from sessions: [CLICodexTokenAuditSession]) -> [CLICodexTokenAuditCWDTotal] {
        var totals: [String: (count: Int, tokens: Int64, rolloutBytes: Int64, toolOutputBytes: Int64)] = [:]
        let unknown = String(localized: "cli.codexTokenAudit.output.unknown", defaultValue: "unknown")
        for session in sessions {
            let cwd = session.cwd ?? unknown
            let current = totals[cwd] ?? (0, 0, 0, 0)
            totals[cwd] = (
                current.count + 1,
                current.tokens + session.tokensUsed,
                current.rolloutBytes + (session.analysis?.rolloutBytes ?? 0),
                current.toolOutputBytes + (session.analysis?.toolOutputBytes ?? 0)
            )
        }
        return totals.map { cwd, total in
            CLICodexTokenAuditCWDTotal(
                cwd: cwd,
                sessionCount: total.count,
                tokens: total.tokens,
                rolloutBytes: total.rolloutBytes,
                toolOutputBytes: total.toolOutputBytes
            )
        }
        .sorted {
            if $0.tokens == $1.tokens {
                return $0.cwd < $1.cwd
            }
            return $0.tokens > $1.tokens
        }
    }

    private static func modelIdentity(_ row: CLICodexTokenAuditModelTotal) -> String {
        let parts = [row.modelProvider, row.model].compactMap { value -> String? in
            guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
                return nil
            }
            return value
        }
        return parts.isEmpty
            ? String(localized: "cli.codexTokenAudit.output.unknown", defaultValue: "unknown")
            : parts.joined(separator: " ")
    }

    private func prepare(_ sql: String) throws -> OpaquePointer {
        guard let handle else {
            throw CLIError(message: String(localized: "cli.codexTokenAudit.error.databaseClosed", defaultValue: "Codex session database is closed"))
        }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw CLIError(message: sqliteMessage)
        }
        return statement
    }

    private func string(_ statement: OpaquePointer, _ index: Int32) -> String? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL,
              let raw = sqlite3_column_text(statement, index) else {
            return nil
        }
        let value = String(cString: raw).trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private func timestamp(_ statement: OpaquePointer, _ index: Int32) -> TimeInterval? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL else {
            return nil
        }
        return sqlite3_column_double(statement, index)
    }

    private var sqliteMessage: String {
        guard let handle, let raw = sqlite3_errmsg(handle) else {
            return String(localized: "cli.codexTokenAudit.error.unknownSQLiteError", defaultValue: "unknown sqlite error")
        }
        return String(cString: raw)
    }

    private static func isoString(_ timestamp: TimeInterval) -> String {
        isoString(Date(timeIntervalSince1970: timestamp))
    }

    private static func isoString(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    private static func dayString(_ timestamp: TimeInterval) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date(timeIntervalSince1970: timestamp))
    }
}

extension BMUXCLI {
    func runCodexTokenAuditCommand(
        commandArgs: [String],
        jsonOutput: Bool,
        processEnv: [String: String] = ProcessInfo.processInfo.environment
    ) throws {
        let (localJSONOutput, argsAfterJSON) = removeCodexTokenAuditFlag(commandArgs, name: "--json")
        let (databasePathLong, argsAfterDatabaseLong) = parseOption(argsAfterJSON, name: "--database")
        let (databasePathShort, argsAfterDatabaseShort) = parseOption(argsAfterDatabaseLong, name: "--db")
        let (codexHomePath, argsAfterCodexHome) = parseOption(argsAfterDatabaseShort, name: "--codex-home")
        let (limitValue, remaining) = parseOption(argsAfterCodexHome, name: "--limit")
        let effectiveJSONOutput = jsonOutput || localJSONOutput

        if let unknown = remaining.first(where: { $0.hasPrefix("--") }) {
            throw CLIError(message: String.localizedStringWithFormat(
                String(localized: "cli.codexTokenAudit.error.unknownFlag", defaultValue: "codex-token-audit: unknown flag '%@'"),
                unknown
            ))
        }
        guard remaining.isEmpty else {
            throw CLIError(message: String.localizedStringWithFormat(
                String(localized: "cli.codexTokenAudit.error.unexpectedArgument", defaultValue: "codex-token-audit: unexpected argument '%@'"),
                remaining[0]
            ))
        }
        if databasePathLong != nil, databasePathShort != nil {
            throw CLIError(message: String(localized: "cli.codexTokenAudit.error.duplicateDatabase", defaultValue: "Use only one of --database or --db."))
        }
        if (databasePathLong ?? databasePathShort) != nil, codexHomePath != nil {
            throw CLIError(message: String(localized: "cli.codexTokenAudit.error.databaseOrCodexHome", defaultValue: "Use --database or --codex-home, not both."))
        }

        let displayLimit = try codexTokenAuditDisplayLimit(limitValue)
        let resolved = codexTokenAuditDatabaseURL(
            databasePath: databasePathLong ?? databasePathShort,
            codexHomePath: codexHomePath,
            processEnv: processEnv
        )
        guard FileManager.default.fileExists(atPath: resolved.databaseURL.path) else {
            throw CLIError(message: String.localizedStringWithFormat(
                String(localized: "cli.codexTokenAudit.error.noDatabase", defaultValue: "No Codex session database found at %@"),
                resolved.databaseURL.path
            ), exitCode: 2)
        }

        let reader = try CLICodexTokenAuditSQLiteReader(databaseURL: resolved.databaseURL)
        let report = try reader.report(
            databasePath: resolved.databaseURL.path,
            codexHomePath: resolved.codexHomeURL?.path
        )
        printCodexTokenAuditReport(report, jsonOutput: effectiveJSONOutput, displayLimit: displayLimit)
    }

    private func codexTokenAuditDatabaseURL(
        databasePath: String?,
        codexHomePath: String?,
        processEnv: [String: String]
    ) -> (databaseURL: URL, codexHomeURL: URL?) {
        if let databasePath = databasePath?.trimmingCharacters(in: .whitespacesAndNewlines),
           !databasePath.isEmpty {
            return (URL(fileURLWithPath: NSString(string: databasePath).expandingTildeInPath), nil)
        }

        let codexHome = codexHomePath?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            ?? processEnv["CODEX_HOME"]?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            ?? "~/.codex"
        let codexHomeURL = URL(fileURLWithPath: NSString(string: codexHome).expandingTildeInPath, isDirectory: true)
        let selectedDatabaseURL = highestCodexStateDatabase(in: codexHomeURL)
            ?? codexHomeURL.appendingPathComponent("state_5.sqlite", isDirectory: false)
        return (selectedDatabaseURL, codexHomeURL)
    }

    private func highestCodexStateDatabase(in directoryURL: URL) -> URL? {
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []
        return contents.compactMap { url -> (version: Int, url: URL)? in
            let name = url.lastPathComponent
            guard name.hasPrefix("state_"), name.hasSuffix(".sqlite") else {
                return nil
            }
            let versionText = name
                .dropFirst("state_".count)
                .dropLast(".sqlite".count)
            guard let version = Int(versionText) else {
                return nil
            }
            return (version, url)
        }
        .sorted { $0.version > $1.version }
        .first?
        .url
    }

    private func codexTokenAuditDisplayLimit(_ rawValue: String?) throws -> Int {
        guard let rawValue = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawValue.isEmpty else {
            return 20
        }
        if rawValue.lowercased() == "all" {
            return Int.max
        }
        guard let parsed = Int(rawValue), parsed > 0 else {
            throw CLIError(message: String(localized: "cli.codexTokenAudit.error.invalidLimit", defaultValue: "codex-token-audit --limit must be a positive integer or 'all'."))
        }
        return parsed
    }

    private func removeCodexTokenAuditFlag(_ args: [String], name: String) -> (Bool, [String]) {
        var found = false
        var remaining: [String] = []
        var pastTerminator = false
        for arg in args {
            if arg == "--" {
                pastTerminator = true
                remaining.append(arg)
                continue
            }
            if !pastTerminator, arg == name {
                found = true
                continue
            }
            remaining.append(arg)
        }
        return (found, remaining)
    }

    private func printCodexTokenAuditReport(
        _ report: CLICodexTokenAuditReport,
        jsonOutput: Bool,
        displayLimit: Int
    ) {
        if jsonOutput {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            if let data = try? encoder.encode(report) {
                cliWriteStdout(data)
                cliWriteStdout(Data("\n".utf8))
            } else {
                print("{}")
            }
            return
        }

        print(renderCodexTokenAuditReport(report, displayLimit: displayLimit))
    }

    private func renderCodexTokenAuditReport(
        _ report: CLICodexTokenAuditReport,
        displayLimit: Int
    ) -> String {
        var lines: [String] = [
            String(localized: "cli.codexTokenAudit.output.title", defaultValue: "Codex token audit"),
            String.localizedStringWithFormat(
                String(localized: "cli.codexTokenAudit.output.database", defaultValue: "Database: %@"),
                report.databasePath
            ),
            String.localizedStringWithFormat(
                String(localized: "cli.codexTokenAudit.output.generatedAt", defaultValue: "Generated: %@"),
                report.generatedAt
            ),
            String.localizedStringWithFormat(
                String(localized: "cli.codexTokenAudit.output.sessions", defaultValue: "Sessions: %@"),
                codexTokenAuditInteger(report.sessionCount)
            ),
            String.localizedStringWithFormat(
                String(localized: "cli.codexTokenAudit.output.totalTokens", defaultValue: "Total tokens: %@"),
                codexTokenAuditInteger(report.totalTokens)
            ),
            String.localizedStringWithFormat(
                String(localized: "cli.codexTokenAudit.output.largestSession", defaultValue: "Largest session: %@"),
                codexTokenAuditInteger(report.largestSessionTokens)
            ),
            String.localizedStringWithFormat(
                String(localized: "cli.codexTokenAudit.output.averageSession", defaultValue: "Average/session: %@"),
                codexTokenAuditDecimal(report.averageTokensPerSession)
            ),
            ""
        ]

        appendCodexTokenAuditDayTotals(report.updatedDayTotals, displayLimit: displayLimit, to: &lines)
        appendCodexTokenAuditModelTotals(report.modelTotals, displayLimit: displayLimit, to: &lines)
        appendCodexTokenAuditCWDTotals(report.cwdTotals, displayLimit: displayLimit, to: &lines)
        appendCodexTokenAuditSessions(report.sessions, displayLimit: displayLimit, to: &lines)

        lines.append("")
        lines.append(String(localized: "cli.codexTokenAudit.output.notesHeader", defaultValue: "Notes:"))
        for note in report.notes {
            lines.append(String.localizedStringWithFormat(
                String(localized: "cli.codexTokenAudit.output.noteRow", defaultValue: "  - %@"),
                note
            ))
        }
        return lines.joined(separator: "\n")
    }

    private func appendCodexTokenAuditDayTotals(
        _ totals: [CLICodexTokenAuditDayTotal],
        displayLimit: Int,
        to lines: inout [String]
    ) {
        lines.append(String(localized: "cli.codexTokenAudit.output.dayTotalsHeader", defaultValue: "Updated-day totals:"))
        guard !totals.isEmpty else {
            lines.append(String(localized: "cli.codexTokenAudit.output.noRows", defaultValue: "  No rows."))
            lines.append("")
            return
        }
        for row in totals.prefix(displayLimit) {
            lines.append(String.localizedStringWithFormat(
                String(localized: "cli.codexTokenAudit.output.dayRow", defaultValue: "  %@  %@ tokens  %@"),
                row.day,
                codexTokenAuditInteger(row.tokens),
                codexTokenAuditSessionCount(row.sessionCount)
            ))
        }
        appendCodexTokenAuditOmittedRow(
            totalCount: totals.count,
            displayLimit: displayLimit,
            countText: codexTokenAuditCount(
                totalCount: totals.count - displayLimit,
                singularFormat: String(localized: "cli.codexTokenAudit.output.dayCountSingular", defaultValue: "%@ day"),
                pluralFormat: String(localized: "cli.codexTokenAudit.output.dayCountPlural", defaultValue: "%@ days")
            ),
            to: &lines
        )
        lines.append("")
    }

    private func appendCodexTokenAuditModelTotals(
        _ totals: [CLICodexTokenAuditModelTotal],
        displayLimit: Int,
        to lines: inout [String]
    ) {
        lines.append(String(localized: "cli.codexTokenAudit.output.modelTotalsHeader", defaultValue: "Model totals:"))
        guard !totals.isEmpty else {
            lines.append(String(localized: "cli.codexTokenAudit.output.noRows", defaultValue: "  No rows."))
            lines.append("")
            return
        }
        for row in totals.prefix(displayLimit) {
            lines.append(String.localizedStringWithFormat(
                String(localized: "cli.codexTokenAudit.output.modelRow", defaultValue: "  %@  %@ tokens  %@"),
                codexTokenAuditModelIdentity(row),
                codexTokenAuditInteger(row.tokens),
                codexTokenAuditSessionCount(row.sessionCount)
            ))
        }
        appendCodexTokenAuditOmittedRow(
            totalCount: totals.count,
            displayLimit: displayLimit,
            countText: codexTokenAuditCount(
                totalCount: totals.count - displayLimit,
                singularFormat: String(localized: "cli.codexTokenAudit.output.modelCountSingular", defaultValue: "%@ model"),
                pluralFormat: String(localized: "cli.codexTokenAudit.output.modelCountPlural", defaultValue: "%@ models")
            ),
            to: &lines
        )
        lines.append("")
    }

    private func appendCodexTokenAuditCWDTotals(
        _ totals: [CLICodexTokenAuditCWDTotal],
        displayLimit: Int,
        to lines: inout [String]
    ) {
        lines.append(String(localized: "cli.codexTokenAudit.output.cwdTotalsHeader", defaultValue: "CWD totals:"))
        guard !totals.isEmpty else {
            lines.append(String(localized: "cli.codexTokenAudit.output.noRows", defaultValue: "  No rows."))
            lines.append("")
            return
        }
        for row in totals.prefix(displayLimit) {
            lines.append(String.localizedStringWithFormat(
                String(localized: "cli.codexTokenAudit.output.cwdRow", defaultValue: "  %@  %@ tokens  %@  %@ rollout  %@ tool output"),
                row.cwd,
                codexTokenAuditInteger(row.tokens),
                codexTokenAuditSessionCount(row.sessionCount),
                codexTokenAuditByteCount(row.rolloutBytes),
                codexTokenAuditByteCount(row.toolOutputBytes)
            ))
        }
        appendCodexTokenAuditOmittedRow(
            totalCount: totals.count,
            displayLimit: displayLimit,
            countText: codexTokenAuditCount(
                totalCount: totals.count - displayLimit,
                singularFormat: String(localized: "cli.codexTokenAudit.output.cwdCountSingular", defaultValue: "%@ cwd"),
                pluralFormat: String(localized: "cli.codexTokenAudit.output.cwdCountPlural", defaultValue: "%@ cwds")
            ),
            to: &lines
        )
        lines.append("")
    }

    private func appendCodexTokenAuditSessions(
        _ sessions: [CLICodexTokenAuditSession],
        displayLimit: Int,
        to lines: inout [String]
    ) {
        lines.append(String(localized: "cli.codexTokenAudit.output.sessionsHeader", defaultValue: "Highest-token sessions:"))
        guard !sessions.isEmpty else {
            lines.append(String(localized: "cli.codexTokenAudit.output.noRows", defaultValue: "  No rows."))
            return
        }
        for session in sessions.prefix(displayLimit) {
            lines.append(String.localizedStringWithFormat(
                String(localized: "cli.codexTokenAudit.output.sessionRow", defaultValue: "  %@ tokens | %@ | %@ | %@"),
                codexTokenAuditInteger(session.tokensUsed),
                session.updatedDay ?? codexTokenAuditUnknown(),
                sessionModelIdentity(session),
                codexTokenAuditSessionTitle(session)
            ))
            lines.append(String.localizedStringWithFormat(
                String(localized: "cli.codexTokenAudit.output.sessionIDRow", defaultValue: "      id: %@"),
                session.id
            ))
            if let cwd = session.cwd {
                lines.append(String.localizedStringWithFormat(
                    String(localized: "cli.codexTokenAudit.output.sessionCWDRow", defaultValue: "      cwd: %@"),
                    cwd
                ))
            }
            if let analysis = session.analysis {
                lines.append(String.localizedStringWithFormat(
                    String(localized: "cli.codexTokenAudit.output.sessionSignalsRow", defaultValue: "      signals: %@ rollout, %@ events, %@ tool calls, %@ tool output, %@ repeats, %@ span"),
                    codexTokenAuditByteCount(analysis.rolloutBytes),
                    codexTokenAuditInteger(analysis.rolloutEventCount),
                    codexTokenAuditInteger(analysis.toolCallCount),
                    codexTokenAuditByteCount(analysis.toolOutputBytes),
                    codexTokenAuditInteger(analysis.repeatedCommandCount),
                    codexTokenAuditDuration(session.sessionSpanSeconds)
                ))
                let driverLabels = analysis.driverIDs.map(codexTokenAuditDriverLabel)
                if !driverLabels.isEmpty {
                    lines.append(String.localizedStringWithFormat(
                        String(localized: "cli.codexTokenAudit.output.sessionDriversRow", defaultValue: "      likely drivers: %@"),
                        driverLabels.joined(separator: ", ")
                    ))
                }
                if let repeated = analysis.topRepeatedCommands.first {
                    lines.append(String.localizedStringWithFormat(
                        String(localized: "cli.codexTokenAudit.output.sessionRepeatedCommandRow", defaultValue: "      repeated: %@ x%@"),
                        repeated.command,
                        codexTokenAuditInteger(repeated.count)
                    ))
                }
            } else if session.sessionSpanSeconds != nil {
                lines.append(String.localizedStringWithFormat(
                    String(localized: "cli.codexTokenAudit.output.sessionDurationRow", defaultValue: "      span: %@"),
                    codexTokenAuditDuration(session.sessionSpanSeconds)
                ))
            }
        }
        appendCodexTokenAuditOmittedRow(
            totalCount: sessions.count,
            displayLimit: displayLimit,
            countText: codexTokenAuditSessionCount(sessions.count - displayLimit),
            to: &lines
        )
    }

    private func appendCodexTokenAuditOmittedRow(
        totalCount: Int,
        displayLimit: Int,
        countText: String,
        to lines: inout [String]
    ) {
        guard displayLimit < totalCount else { return }
        lines.append(String.localizedStringWithFormat(
            String(localized: "cli.codexTokenAudit.output.omittedRow", defaultValue: "  ... %@ omitted; use --limit all to show every row."),
            countText
        ))
    }

    private func codexTokenAuditSessionTitle(_ session: CLICodexTokenAuditSession) -> String {
        let raw = session.title ?? session.preview
        guard let text = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            return String(localized: "cli.codexTokenAudit.output.noTitle", defaultValue: "(no title)")
        }
        let singleLine = text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
        guard singleLine.count > 140 else {
            return singleLine
        }
        return String(singleLine.prefix(137)) + "..."
    }

    private func sessionModelIdentity(_ session: CLICodexTokenAuditSession) -> String {
        let provider = session.modelProvider ?? session.source
        let parts = [provider, session.model].compactMap { value -> String? in
            guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
                return nil
            }
            return value
        }
        return parts.isEmpty ? codexTokenAuditUnknown() : parts.joined(separator: " ")
    }

    private func codexTokenAuditModelIdentity(_ row: CLICodexTokenAuditModelTotal) -> String {
        let parts = [row.modelProvider, row.model].compactMap { value -> String? in
            guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
                return nil
            }
            return value
        }
        return parts.isEmpty ? codexTokenAuditUnknown() : parts.joined(separator: " ")
    }

    private func codexTokenAuditDriverLabel(_ driverID: String) -> String {
        switch driverID {
        case "large_rollout":
            return String(localized: "cli.codexTokenAudit.output.driver.largeRollout", defaultValue: "large rollout")
        case "large_tool_output":
            return String(localized: "cli.codexTokenAudit.output.driver.largeToolOutput", defaultValue: "large tool output")
        case "repeated_commands":
            return String(localized: "cli.codexTokenAudit.output.driver.repeatedCommands", defaultValue: "repeated commands")
        case "many_turns":
            return String(localized: "cli.codexTokenAudit.output.driver.manyTurns", defaultValue: "many turns")
        case "many_recoverable_outputs":
            return String(localized: "cli.codexTokenAudit.output.driver.manyRecoverableOutputs", defaultValue: "many recoverable outputs")
        case "long_running_session":
            return String(localized: "cli.codexTokenAudit.output.driver.longRunningSession", defaultValue: "long session span")
        default:
            return driverID.replacingOccurrences(of: "_", with: " ")
        }
    }

    private func codexTokenAuditUnknown() -> String {
        String(localized: "cli.codexTokenAudit.output.unknown", defaultValue: "unknown")
    }

    private func codexTokenAuditSessionCount(_ totalCount: Int) -> String {
        codexTokenAuditCount(
            totalCount: totalCount,
            singularFormat: String(localized: "cli.codexTokenAudit.output.sessionCountSingular", defaultValue: "%@ session"),
            pluralFormat: String(localized: "cli.codexTokenAudit.output.sessionCountPlural", defaultValue: "%@ sessions")
        )
    }

    private func codexTokenAuditCount(
        totalCount: Int,
        singularFormat: String,
        pluralFormat: String
    ) -> String {
        if totalCount == 1 {
            return String.localizedStringWithFormat(
                singularFormat,
                codexTokenAuditInteger(totalCount)
            )
        }
        return String.localizedStringWithFormat(
            pluralFormat,
            codexTokenAuditInteger(totalCount)
        )
    }

    private func codexTokenAuditInteger(_ value: Int) -> String {
        codexTokenAuditInteger(Int64(value))
    }

    private func codexTokenAuditInteger(_ value: Int64) -> String {
        NumberFormatter.localizedString(from: NSNumber(value: value), number: .decimal)
    }

    private func codexTokenAuditDecimal(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.1f", value)
    }

    private func codexTokenAuditByteCount(_ value: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.includesActualByteCount = false
        return formatter.string(fromByteCount: value)
    }

    private func codexTokenAuditDuration(_ value: Double?) -> String {
        guard let value else {
            return codexTokenAuditUnknown()
        }
        let totalMinutes = max(0, Int((value / 60).rounded()))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return String.localizedStringWithFormat(
                String(localized: "cli.codexTokenAudit.output.durationHoursMinutes", defaultValue: "%@h %@m"),
                codexTokenAuditInteger(hours),
                codexTokenAuditInteger(minutes)
            )
        }
        return String.localizedStringWithFormat(
            String(localized: "cli.codexTokenAudit.output.durationMinutes", defaultValue: "%@m"),
            codexTokenAuditInteger(minutes)
        )
    }

    func codexTokenAuditUsage() -> String {
        String(localized: "cli.codexTokenAudit.usage", defaultValue: """
        Usage:
          bmux codex-token-audit [--database <path> | --codex-home <path>] [--limit <n>|all] [--json]
          bmux codex token-audit [--database <path> | --codex-home <path>] [--limit <n>|all] [--json]

        Audit every local Codex session recorded in the Codex state database.
        """)
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
