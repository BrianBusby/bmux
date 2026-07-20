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

    func lifecycleIngestionTraces(
        limit: Int,
        pipelineRunID: String? = nil,
        parentSessionID: String? = nil,
        childSessionID: String? = nil,
        status: String? = nil
    ) throws -> CLIProvenanceLifecycleTraceList {
        let boundedLimit = max(1, min(limit, 100))
        let runs = try lifecycleIngestionRunRows(
            limit: boundedLimit,
            pipelineRunID: pipelineRunID,
            parentSessionID: parentSessionID,
            childSessionID: childSessionID,
            status: status
        )
        var stages: [[String: AnyHashable]] = []
        var identityResolutions: [[String: AnyHashable]] = []
        var projectionLineage: [[String: AnyHashable]] = []
        for run in runs {
            guard let pipelineRunID = run["pipeline_run_id"] as? String else { continue }
            stages.append(contentsOf: try stageRows(pipelineRunID: pipelineRunID))
            identityResolutions.append(contentsOf: try identityResolutionRows(pipelineRunID: pipelineRunID))
            projectionLineage.append(contentsOf: try projectionLineageRows(pipelineRunID: pipelineRunID))
        }
        return CLIProvenanceLifecycleTraceList(
            found: !runs.isEmpty,
            reason: runs.isEmpty
                ? String(localized: "cli.provenance.reason.noLifecycleTraces", defaultValue: "no lifecycle ingestion traces have been recorded")
                : nil,
            runs: runs,
            stages: stages,
            identityResolutions: identityResolutions,
            projectionLineage: projectionLineage
        )
    }

    private func lifecycleIngestionRunRows(
        limit: Int,
        pipelineRunID: String?,
        parentSessionID: String?,
        childSessionID: String?,
        status: String?
    ) throws -> [[String: AnyHashable]] {
        var predicates = ["pipeline_kind = 'lifecycle_ingestion'"]
        var bindings: [String] = []
        if let pipelineRunID, !pipelineRunID.isEmpty {
            predicates.append("pipeline_run_id = ?")
            bindings.append(pipelineRunID)
        }
        if let parentSessionID, !parentSessionID.isEmpty {
            predicates.append("parent_session_id = ?")
            bindings.append(parentSessionID)
        }
        if let childSessionID, !childSessionID.isEmpty {
            predicates.append("child_session_id = ?")
            bindings.append(childSessionID)
        }
        if let status, !status.isEmpty {
            predicates.append("status = ?")
            bindings.append(status)
        }
        let statement = try prepare(
            """
            SELECT pipeline_run_id, pipeline_kind, trigger_source,
                   parent_session_id, child_session_id, lifecycle_event_id,
                   relationship_session_id, external_identity_id, status,
                   started_at, ended_at, duration_ms, input_count, output_count,
                   error_count, error_summary, implementation_version
            FROM pipeline_runs
            WHERE \(predicates.joined(separator: " AND "))
            ORDER BY started_at DESC, rowid DESC
            LIMIT ?
            """
        )
        defer { sqlite3_finalize(statement) }
        for (index, binding) in bindings.enumerated() {
            try bind(binding, to: statement, at: Int32(index + 1))
        }
        try bind(limit, to: statement, at: Int32(bindings.count + 1))
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

    private func identityResolutionRows(pipelineRunID: String) throws -> [[String: AnyHashable]] {
        guard try tableExists("identity_resolution_attempts") else { return [] }
        let statement = try prepare(
            """
            SELECT identity_resolution_id, pipeline_run_id, resolver_name,
                   resolver_version, trigger_source, input_phase,
                   input_agent_kind, input_parent_session_id,
                   input_subsession_id_state, input_workspace_present,
                   input_surface_present, input_working_directory_present,
                   input_display_name_present, input_identity_kind,
                   input_identity_value_hash, selected_identity_kind,
                   selected_identity_value_category, candidate_count,
                   selected_child_session_id, selected_lifecycle_event_id,
                   selected_relationship_session_id, selected_external_identity_id,
                   confidence, outcome, fallback_state, unresolved_reason,
                   conflict_reason, started_at, ended_at, duration_ms
            FROM identity_resolution_attempts
            WHERE pipeline_run_id = ?
            ORDER BY started_at ASC, rowid ASC
            """
        )
        defer { sqlite3_finalize(statement) }
        try bind(pipelineRunID, to: statement, at: 1)
        var rows: [[String: AnyHashable]] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            rows.append(compactPayload([
                "identity_resolution_id": string(statement, 0),
                "pipeline_run_id": string(statement, 1),
                "resolver_name": string(statement, 2),
                "resolver_version": string(statement, 3),
                "trigger_source": string(statement, 4),
                "input_phase": string(statement, 5),
                "input_agent_kind": string(statement, 6),
                "input_parent_session_id": string(statement, 7),
                "input_subsession_id_state": string(statement, 8),
                "input_workspace_present": bool(statement, 9),
                "input_surface_present": bool(statement, 10),
                "input_working_directory_present": bool(statement, 11),
                "input_display_name_present": bool(statement, 12),
                "input_identity_kind": string(statement, 13),
                "input_identity_value_hash": string(statement, 14),
                "selected_identity_kind": string(statement, 15),
                "selected_identity_value_category": string(statement, 16),
                "candidate_count": int(statement, 17),
                "selected_child_session_id": string(statement, 18),
                "selected_lifecycle_event_id": string(statement, 19),
                "selected_relationship_session_id": string(statement, 20),
                "selected_external_identity_id": string(statement, 21),
                "confidence": string(statement, 22),
                "outcome": string(statement, 23),
                "fallback_state": string(statement, 24),
                "unresolved_reason": string(statement, 25),
                "conflict_reason": string(statement, 26),
                "started_at": double(statement, 27),
                "ended_at": double(statement, 28),
                "duration_ms": double(statement, 29)
            ]))
        }
        return rows
    }

    private func projectionLineageRows(pipelineRunID: String) throws -> [[String: AnyHashable]] {
        guard try tableExists("projection_lineage") else { return [] }
        let statement = try prepare(
            """
            SELECT projection_lineage_id, pipeline_run_id, stage_name,
                   projection_kind, source_event_id, source_event_type,
                   source_event_schema_version, source_payload_hash,
                   target_table, target_entity_kind, target_entity_id,
                   operation, generator_version, confidence, started_at,
                   ended_at, duration_ms
            FROM projection_lineage
            WHERE pipeline_run_id = ?
            ORDER BY started_at ASC, rowid ASC
            """
        )
        defer { sqlite3_finalize(statement) }
        try bind(pipelineRunID, to: statement, at: 1)
        var rows: [[String: AnyHashable]] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            rows.append(compactPayload([
                "projection_lineage_id": string(statement, 0),
                "pipeline_run_id": string(statement, 1),
                "stage_name": string(statement, 2),
                "projection_kind": string(statement, 3),
                "source_event_id": string(statement, 4),
                "source_event_type": string(statement, 5),
                "source_event_schema_version": int(statement, 6),
                "source_payload_hash": string(statement, 7),
                "target_table": string(statement, 8),
                "target_entity_kind": string(statement, 9),
                "target_entity_id": string(statement, 10),
                "operation": string(statement, 11),
                "generator_version": string(statement, 12),
                "confidence": string(statement, 13),
                "started_at": double(statement, 14),
                "ended_at": double(statement, 15),
                "duration_ms": double(statement, 16)
            ]))
        }
        return rows
    }

    private func tableExists(_ name: String) throws -> Bool {
        let statement = try prepare(
            """
            SELECT 1
            FROM sqlite_master
            WHERE type = 'table' AND name = ?
            LIMIT 1
            """
        )
        defer { sqlite3_finalize(statement) }
        try bind(name, to: statement, at: 1)
        return sqlite3_step(statement) == SQLITE_ROW
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

    private func bool(_ statement: OpaquePointer, _ index: Int32) -> Bool {
        sqlite3_column_int64(statement, index) != 0
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
