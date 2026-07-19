import Foundation
import SQLite3

final class CLIProvenanceObservabilitySQLiteReader {
    private var handle: OpaquePointer?

    init(databaseURL: URL) throws {
        var opened: OpaquePointer?
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(databaseURL.path, &opened, flags, nil) == SQLITE_OK, let opened else {
            let message = opened.flatMap { sqlite3_errmsg($0) }.map { String(cString: $0) }
                ?? String(localized: "cli.provenance.error.sqliteOpenFailed", defaultValue: "open failed")
            if let opened {
                sqlite3_close(opened)
            }
            throw CLIError(message: String.localizedStringWithFormat(
                String(
                    localized: "cli.provenance.error.openObservabilityDatabaseFailed",
                    defaultValue: "failed to open provenance observability database: %@"
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

    func lifecycleIngestionTraces(limit: Int) throws -> CLIProvenanceLifecycleTraceList {
        let boundedLimit = max(1, min(limit, 100))
        let runs = try lifecycleIngestionRunRows(limit: boundedLimit)
        var stages: [[String: AnyHashable]] = []
        for run in runs {
            guard let pipelineRunID = run["pipeline_run_id"] as? String else { continue }
            stages.append(contentsOf: try stageRows(pipelineRunID: pipelineRunID))
        }
        return CLIProvenanceLifecycleTraceList(
            found: !runs.isEmpty,
            reason: runs.isEmpty
                ? String(localized: "cli.provenance.reason.noLifecycleTraces", defaultValue: "no lifecycle ingestion traces have been recorded")
                : nil,
            runs: runs,
            stages: stages
        )
    }

    private func lifecycleIngestionRunRows(limit: Int) throws -> [[String: AnyHashable]] {
        let statement = try prepare(
            """
            SELECT pipeline_run_id, pipeline_kind, trigger_source,
                   parent_session_id, child_session_id, lifecycle_event_id,
                   relationship_session_id, external_identity_id, status,
                   started_at, ended_at, duration_ms, input_count, output_count,
                   error_count, error_summary, implementation_version
            FROM pipeline_runs
            WHERE pipeline_kind = 'lifecycle_ingestion'
            ORDER BY started_at DESC, rowid DESC
            LIMIT ?
            """
        )
        defer { sqlite3_finalize(statement) }
        try bind(limit, to: statement, at: 1)
        var rows: [[String: AnyHashable]] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            rows.append(compactPayload([
                "pipeline_run_id": string(statement, 0),
                "pipeline_kind": string(statement, 1),
                "trigger_source": string(statement, 2),
                "parent_session_id": string(statement, 3),
                "child_session_id": string(statement, 4),
                "lifecycle_event_id": string(statement, 5),
                "relationship_session_id": string(statement, 6),
                "external_identity_id": string(statement, 7),
                "status": string(statement, 8),
                "started_at": double(statement, 9),
                "ended_at": double(statement, 10),
                "duration_ms": double(statement, 11),
                "input_count": int(statement, 12),
                "output_count": int(statement, 13),
                "error_count": int(statement, 14),
                "error_summary": string(statement, 15),
                "implementation_version": string(statement, 16)
            ]))
        }
        return rows
    }

    private func stageRows(pipelineRunID: String) throws -> [[String: AnyHashable]] {
        let statement = try prepare(
            """
            SELECT pipeline_run_id, stage_name, stage_version, status,
                   started_at, ended_at, duration_ms, input_count, output_count,
                   error_count, error_summary
            FROM pipeline_stage_executions
            WHERE pipeline_run_id = ?
            ORDER BY started_at ASC, rowid ASC
            """
        )
        defer { sqlite3_finalize(statement) }
        try bind(pipelineRunID, to: statement, at: 1)
        var rows: [[String: AnyHashable]] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            rows.append(compactPayload([
                "pipeline_run_id": string(statement, 0),
                "stage_name": string(statement, 1),
                "stage_version": string(statement, 2),
                "status": string(statement, 3),
                "started_at": double(statement, 4),
                "ended_at": double(statement, 5),
                "duration_ms": double(statement, 6),
                "input_count": int(statement, 7),
                "output_count": int(statement, 8),
                "error_count": int(statement, 9),
                "error_summary": string(statement, 10)
            ]))
        }
        return rows
    }

    private func prepare(_ sql: String) throws -> OpaquePointer {
        guard let handle else {
            throw CLIError(message: String(localized: "cli.provenance.error.databaseClosed", defaultValue: "provenance database is closed"))
        }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw CLIError(message: sqliteMessage)
        }
        return statement
    }

    private func bind(_ value: String, to statement: OpaquePointer, at index: Int32) throws {
        let transient = unsafeBitCast(OpaquePointer(bitPattern: -1), to: sqlite3_destructor_type.self)
        guard sqlite3_bind_text(statement, index, value, -1, transient) == SQLITE_OK else {
            throw CLIError(message: sqliteMessage)
        }
    }

    private func bind(_ value: Int, to statement: OpaquePointer, at index: Int32) throws {
        guard sqlite3_bind_int64(statement, index, sqlite3_int64(value)) == SQLITE_OK else {
            throw CLIError(message: sqliteMessage)
        }
    }

    private func string(_ statement: OpaquePointer, _ index: Int32) -> String? {
        guard let raw = sqlite3_column_text(statement, index) else { return nil }
        return String(cString: raw)
    }

    private func double(_ statement: OpaquePointer, _ index: Int32) -> Double? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL else { return nil }
        return sqlite3_column_double(statement, index)
    }

    private func int(_ statement: OpaquePointer, _ index: Int32) -> Int {
        Int(sqlite3_column_int64(statement, index))
    }

    private func compactPayload(_ values: [String: AnyHashable?]) -> [String: AnyHashable] {
        values.reduce(into: [String: AnyHashable]()) { partial, item in
            if let value = item.value {
                partial[item.key] = value
            }
        }
    }

    private var sqliteMessage: String {
        guard let handle, let raw = sqlite3_errmsg(handle) else {
            return String(localized: "cli.provenance.error.unknownSQLiteError", defaultValue: "unknown sqlite error")
        }
        return String(cString: raw)
    }
}
