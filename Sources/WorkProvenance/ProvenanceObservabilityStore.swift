import Foundation

/// Separate operational telemetry store for provenance pipeline traces.
actor ProvenanceObservabilityStore {
    private static let schemaVersion = 1
    private let database: WorkProvenanceSQLiteDatabase

    init(databaseURL: URL, fileManager: FileManager = .default) throws {
        try fileManager.createDirectory(
            at: databaseURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        self.database = try WorkProvenanceSQLiteDatabase(url: databaseURL)
        try Self.migrateIfNeeded(database: database)
    }

    func record(
        run: ProvenancePipelineRunRecord,
        stages: [ProvenancePipelineStageExecutionRecord]
    ) throws {
        try database.execute("BEGIN IMMEDIATE TRANSACTION")
        do {
            try insert(run)
            for stage in stages {
                try insert(stage)
            }
            try database.execute("COMMIT")
        } catch {
            try? database.execute("ROLLBACK")
            throw error
        }
    }

    func lifecycleIngestionRuns(limit: Int = 20) throws -> [(
        run: ProvenancePipelineRunRecord,
        stages: [ProvenancePipelineStageExecutionRecord]
    )] {
        let boundedLimit = max(1, min(limit, 100))
        let statement = try database.prepare(
            """
            SELECT pipeline_run_id, pipeline_kind, trigger_source,
                   parent_session_id, child_session_id, lifecycle_event_id,
                   relationship_session_id, external_identity_id, status,
                   started_at, ended_at, input_count, output_count,
                   error_count, error_summary, implementation_version
            FROM pipeline_runs
            WHERE pipeline_kind = 'lifecycle_ingestion'
            ORDER BY started_at DESC, rowid DESC
            LIMIT ?
            """
        )
        defer { statement.finalize() }
        try statement.bind(boundedLimit, at: 1)
        var rows: [(run: ProvenancePipelineRunRecord, stages: [ProvenancePipelineStageExecutionRecord])] = []
        while try statement.step() {
            guard let run = pipelineRun(from: statement) else { continue }
            rows.append((run: run, stages: try stages(pipelineRunID: run.pipelineRunID)))
        }
        return rows
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
            try database.execute("PRAGMA user_version = 1")
        }
    }

    private func insert(_ run: ProvenancePipelineRunRecord) throws {
        let statement = try database.prepare(
            """
            INSERT INTO pipeline_runs (
                pipeline_run_id, pipeline_kind, trigger_source,
                parent_session_id, child_session_id, lifecycle_event_id,
                relationship_session_id, external_identity_id, status,
                started_at, ended_at, duration_ms, input_count, output_count,
                error_count, error_summary, implementation_version
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(pipeline_run_id) DO UPDATE SET
                status = excluded.status,
                ended_at = excluded.ended_at,
                duration_ms = excluded.duration_ms,
                input_count = excluded.input_count,
                output_count = excluded.output_count,
                error_count = excluded.error_count,
                error_summary = excluded.error_summary
            """
        )
        defer { statement.finalize() }
        try statement.bind(run.pipelineRunID, at: 1)
        try statement.bind(run.pipelineKind, at: 2)
        try statement.bind(run.triggerSource, at: 3)
        try statement.bind(run.parentSessionID, at: 4)
        try statement.bind(run.childSessionID, at: 5)
        try statement.bind(run.lifecycleEventID, at: 6)
        try statement.bind(run.relationshipSessionID, at: 7)
        try statement.bind(run.externalIdentityID, at: 8)
        try statement.bind(run.status, at: 9)
        try statement.bind(run.startedAt.timeIntervalSince1970, at: 10)
        try statement.bind(run.endedAt.timeIntervalSince1970, at: 11)
        try statement.bind(run.durationMilliseconds, at: 12)
        try statement.bind(run.inputCount, at: 13)
        try statement.bind(run.outputCount, at: 14)
        try statement.bind(run.errorCount, at: 15)
        try statement.bind(run.errorSummary, at: 16)
        try statement.bind(run.implementationVersion, at: 17)
        _ = try statement.step()
    }

    private func insert(_ stage: ProvenancePipelineStageExecutionRecord) throws {
        let statement = try database.prepare(
            """
            INSERT INTO pipeline_stage_executions (
                stage_execution_id, pipeline_run_id, stage_name,
                stage_version, status, started_at, ended_at, duration_ms,
                input_count, output_count, error_count, error_summary
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(stage_execution_id) DO UPDATE SET
                status = excluded.status,
                ended_at = excluded.ended_at,
                duration_ms = excluded.duration_ms,
                input_count = excluded.input_count,
                output_count = excluded.output_count,
                error_count = excluded.error_count,
                error_summary = excluded.error_summary
            """
        )
        defer { statement.finalize() }
        try statement.bind(stage.stageExecutionID, at: 1)
        try statement.bind(stage.pipelineRunID, at: 2)
        try statement.bind(stage.stageName, at: 3)
        try statement.bind(stage.stageVersion, at: 4)
        try statement.bind(stage.status, at: 5)
        try statement.bind(stage.startedAt.timeIntervalSince1970, at: 6)
        try statement.bind(stage.endedAt.timeIntervalSince1970, at: 7)
        try statement.bind(stage.durationMilliseconds, at: 8)
        try statement.bind(stage.inputCount, at: 9)
        try statement.bind(stage.outputCount, at: 10)
        try statement.bind(stage.errorCount, at: 11)
        try statement.bind(stage.errorSummary, at: 12)
        _ = try statement.step()
    }

    private func pipelineRun(from statement: WorkProvenanceSQLiteStatement) -> ProvenancePipelineRunRecord? {
        guard let pipelineRunID = statement.string(at: 0),
              let pipelineKind = statement.string(at: 1),
              let triggerSource = statement.string(at: 2),
              let status = statement.string(at: 8),
              let implementationVersion = statement.string(at: 15) else {
            return nil
        }
        return ProvenancePipelineRunRecord(
            pipelineRunID: pipelineRunID,
            pipelineKind: pipelineKind,
            triggerSource: triggerSource,
            parentSessionID: statement.string(at: 3),
            childSessionID: statement.string(at: 4),
            lifecycleEventID: statement.string(at: 5),
            relationshipSessionID: statement.string(at: 6),
            externalIdentityID: statement.string(at: 7),
            status: status,
            startedAt: Date(timeIntervalSince1970: statement.double(at: 9) ?? 0),
            endedAt: Date(timeIntervalSince1970: statement.double(at: 10) ?? 0),
            inputCount: statement.int(at: 11),
            outputCount: statement.int(at: 12),
            errorCount: statement.int(at: 13),
            errorSummary: statement.string(at: 14),
            implementationVersion: implementationVersion
        )
    }

    private func stages(pipelineRunID: String) throws -> [ProvenancePipelineStageExecutionRecord] {
        let statement = try database.prepare(
            """
            SELECT pipeline_run_id, stage_name, stage_version, status,
                   started_at, ended_at, input_count, output_count,
                   error_count, error_summary
            FROM pipeline_stage_executions
            WHERE pipeline_run_id = ?
            ORDER BY started_at ASC, rowid ASC
            """
        )
        defer { statement.finalize() }
        try statement.bind(pipelineRunID, at: 1)
        var rows: [ProvenancePipelineStageExecutionRecord] = []
        while try statement.step() {
            guard let row = stage(from: statement) else { continue }
            rows.append(row)
        }
        return rows
    }

    private func stage(from statement: WorkProvenanceSQLiteStatement) -> ProvenancePipelineStageExecutionRecord? {
        guard let pipelineRunID = statement.string(at: 0),
              let stageName = statement.string(at: 1),
              let stageVersion = statement.string(at: 2),
              let status = statement.string(at: 3) else {
            return nil
        }
        return ProvenancePipelineStageExecutionRecord(
            pipelineRunID: pipelineRunID,
            stageName: stageName,
            stageVersion: stageVersion,
            status: status,
            startedAt: Date(timeIntervalSince1970: statement.double(at: 4) ?? 0),
            endedAt: Date(timeIntervalSince1970: statement.double(at: 5) ?? 0),
            inputCount: statement.int(at: 6),
            outputCount: statement.int(at: 7),
            errorCount: statement.int(at: 8),
            errorSummary: statement.string(at: 9)
        )
    }

    private static var schemaSQL: String {
        """
        CREATE TABLE IF NOT EXISTS pipeline_runs (
            pipeline_run_id TEXT PRIMARY KEY NOT NULL,
            pipeline_kind TEXT NOT NULL,
            trigger_source TEXT NOT NULL,
            parent_session_id TEXT,
            child_session_id TEXT,
            lifecycle_event_id TEXT,
            relationship_session_id TEXT,
            external_identity_id TEXT,
            status TEXT NOT NULL,
            started_at REAL NOT NULL,
            ended_at REAL NOT NULL,
            duration_ms REAL NOT NULL,
            input_count INTEGER NOT NULL,
            output_count INTEGER NOT NULL,
            error_count INTEGER NOT NULL,
            error_summary TEXT,
            implementation_version TEXT NOT NULL
        );
        CREATE INDEX IF NOT EXISTS pipeline_runs_kind_started_idx
            ON pipeline_runs(pipeline_kind, started_at);
        CREATE INDEX IF NOT EXISTS pipeline_runs_status_idx
            ON pipeline_runs(status, started_at);

        CREATE TABLE IF NOT EXISTS pipeline_stage_executions (
            stage_execution_id TEXT PRIMARY KEY NOT NULL,
            pipeline_run_id TEXT NOT NULL,
            stage_name TEXT NOT NULL,
            stage_version TEXT NOT NULL,
            status TEXT NOT NULL,
            started_at REAL NOT NULL,
            ended_at REAL NOT NULL,
            duration_ms REAL NOT NULL,
            input_count INTEGER NOT NULL,
            output_count INTEGER NOT NULL,
            error_count INTEGER NOT NULL,
            error_summary TEXT
        );
        CREATE INDEX IF NOT EXISTS pipeline_stage_executions_run_idx
            ON pipeline_stage_executions(pipeline_run_id, started_at);
        CREATE INDEX IF NOT EXISTS pipeline_stage_executions_name_status_idx
            ON pipeline_stage_executions(stage_name, status);
        """
    }
}
