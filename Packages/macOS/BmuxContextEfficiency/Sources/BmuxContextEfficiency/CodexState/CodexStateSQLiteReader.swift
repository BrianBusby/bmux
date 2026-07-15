import Foundation
import SQLite3

final class CodexStateSQLiteReader {
    private var handle: OpaquePointer?
    private let idFactory: ContextEfficiencyStableIDFactory

    init(databaseURL: URL, idFactory: ContextEfficiencyStableIDFactory) throws {
        self.idFactory = idFactory
        var opened: OpaquePointer?
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(databaseURL.path, &opened, flags, nil) == SQLITE_OK, let opened else {
            let message = opened.flatMap { sqlite3_errmsg($0) }.map { String(cString: $0) } ?? "open failed"
            if let opened {
                sqlite3_close(opened)
            }
            throw CodexStateMetadataReaderError.sqlite(message)
        }
        self.handle = opened
    }

    deinit {
        if let handle {
            sqlite3_close(handle)
        }
    }

    func readThreads() throws -> [CodexStateThreadMetadata] {
        let columns = try threadColumns()
        guard columns.contains("id") else {
            throw CodexStateMetadataReaderError.unsupportedSchema("Codex state database is missing threads.id")
        }

        let selectList = [
            selectedColumn("id", columns: columns),
            selectedColumn("rollout_path", columns: columns),
            selectedColumn("cwd", columns: columns),
            selectedColumn("title", columns: columns),
            selectedColumn("preview", columns: columns),
            selectedColumn("first_user_message", columns: columns),
            selectedColumn("model_provider", columns: columns),
            selectedColumn("model", columns: columns),
            selectedColumn("reasoning_effort", columns: columns),
            selectedColumn("approval_mode", columns: columns),
            selectedColumn("sandbox_policy", columns: columns),
            selectedColumn("git_branch", columns: columns),
            selectedColumn("git_origin_url", columns: columns),
            selectedColumn("cli_version", columns: columns),
            selectedColumn("tokens_used", columns: columns),
            selectedColumn("source", columns: columns),
            selectedColumn("created_at", columns: columns),
            selectedColumn("updated_at", columns: columns),
            selectedColumn("updated_at_ms", columns: columns),
        ].joined(separator: ", ")

        let statement = try prepare(
            """
            SELECT \(selectList)
            FROM threads
            \(orderClause(columns: columns))
            """
        )
        defer { sqlite3_finalize(statement) }

        var rows: [CodexStateThreadMetadata] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let id = string(statement, 0), !id.isEmpty else {
                continue
            }
            let rolloutPath = string(statement, 1).flatMap(nonEmpty)
            let sandboxPolicyType = string(statement, 10).flatMap(sandboxType)
            let updatedAt = date(from: double(statement, 18) ?? double(statement, 17))
            rows.append(CodexStateThreadMetadata(
                id: id,
                normalizedThreadID: idFactory.normalizedThreadID(id),
                rolloutPath: rolloutPath.map(standardizedPath),
                cwd: string(statement, 2).flatMap(nonEmpty),
                title: string(statement, 3).flatMap(nonEmpty),
                preview: string(statement, 4).flatMap(nonEmpty),
                firstUserMessage: string(statement, 5).flatMap(nonEmpty),
                modelProvider: string(statement, 6).flatMap(nonEmpty),
                model: string(statement, 7).flatMap(nonEmpty),
                reasoningEffort: string(statement, 8).flatMap(nonEmpty),
                approvalMode: string(statement, 9).flatMap(nonEmpty),
                sandboxPolicyType: sandboxPolicyType,
                gitBranch: string(statement, 11).flatMap(nonEmpty),
                gitOriginURL: string(statement, 12).flatMap(nonEmpty),
                cliVersion: string(statement, 13).flatMap(nonEmpty),
                tokensUsed: int64(statement, 14),
                source: string(statement, 15).flatMap(nonEmpty),
                createdAt: date(from: double(statement, 16)),
                updatedAt: updatedAt
            ))
        }
        return rows
    }

    private func threadColumns() throws -> Set<String> {
        let statement = try prepare("PRAGMA table_info(threads)")
        defer { sqlite3_finalize(statement) }
        var columns = Set<String>()
        while sqlite3_step(statement) == SQLITE_ROW {
            if let column = string(statement, 1) {
                columns.insert(column)
            }
        }
        guard !columns.isEmpty else {
            throw CodexStateMetadataReaderError.unsupportedSchema("Codex state database is missing threads table")
        }
        return columns
    }

    private func selectedColumn(_ name: String, columns: Set<String>) -> String {
        if columns.contains(name) {
            return name
        }
        return "NULL AS \(name)"
    }

    private func orderClause(columns: Set<String>) -> String {
        var expressions: [String] = []
        if columns.contains("updated_at_ms") {
            expressions.append("updated_at_ms")
        }
        if columns.contains("updated_at") {
            expressions.append("updated_at * 1000")
        }
        if columns.contains("created_at") {
            expressions.append("created_at * 1000")
        }
        guard !expressions.isEmpty else {
            return "ORDER BY rowid DESC"
        }
        return "ORDER BY COALESCE(\(expressions.joined(separator: ", ")), 0) DESC, rowid DESC"
    }

    private func prepare(_ sql: String) throws -> OpaquePointer {
        guard let handle else {
            throw CodexStateMetadataReaderError.sqlite("database is closed")
        }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw CodexStateMetadataReaderError.sqlite(message)
        }
        return statement
    }

    private func string(_ statement: OpaquePointer, _ index: Int32) -> String? {
        guard let raw = sqlite3_column_text(statement, index) else {
            return nil
        }
        return String(cString: raw)
    }

    private func int64(_ statement: OpaquePointer, _ index: Int32) -> Int64? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL else {
            return nil
        }
        return sqlite3_column_int64(statement, index)
    }

    private func double(_ statement: OpaquePointer, _ index: Int32) -> Double? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL else {
            return nil
        }
        return sqlite3_column_double(statement, index)
    }

    private func date(from timestamp: Double?) -> Date? {
        guard let timestamp else { return nil }
        if timestamp > 10_000_000_000 {
            return Date(timeIntervalSince1970: timestamp / 1000)
        }
        return Date(timeIntervalSince1970: timestamp)
    }

    private func nonEmpty(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func standardizedPath(_ path: String) -> String {
        ((path as NSString).expandingTildeInPath as NSString).standardizingPath
    }

    private func sandboxType(_ value: String) -> String? {
        guard let data = value.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = object["type"] as? String,
              !type.isEmpty else {
            return nonEmpty(value)
        }
        return type
    }

    private var message: String {
        guard let handle, let raw = sqlite3_errmsg(handle) else {
            return "unknown sqlite error"
        }
        return String(cString: raw)
    }
}
