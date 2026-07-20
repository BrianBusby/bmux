import Foundation

/// Separate operational telemetry store for provenance pipeline traces.
actor ProvenanceObservabilityStore {
    private static let schemaVersion = 3
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
        stages: [ProvenancePipelineStageExecutionRecord],
        identityResolutions: [ProvenanceIdentityResolutionRecord] = [],
        projectionLineage: [ProvenanceProjectionLineageRecord] = []
    ) throws {
        try database.execute("BEGIN IMMEDIATE TRANSACTION")
        do {
            try insert(run)
            for stage in stages {
                try insert(stage)
            }
            for identityResolution in identityResolutions {
                try insert(identityResolution)
            }
            for projectionLineageRecord in projectionLineage {
                try insert(projectionLineageRecord)
            }
            try database.execute("COMMIT")
        } catch {
            try? database.execute("ROLLBACK")
            throw error
        }
    }

    func lifecycleIngestionRuns(
        limit: Int = 20,
        pipelineRunID: String? = nil,
        parentSessionID: String? = nil,
        childSessionID: String? = nil,
        status: String? = nil
    ) throws -> [(
        run: ProvenancePipelineRunRecord,
        stages: [ProvenancePipelineStageExecutionRecord],
        identityResolutions: [ProvenanceIdentityResolutionRecord],
        projectionLineage: [ProvenanceProjectionLineageRecord]
    )] {
        let boundedLimit = max(1, min(limit, 100))
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
        let statement = try database.prepare(
            """
            SELECT pipeline_run_id, pipeline_kind, trigger_source,
                   parent_session_id, child_session_id, lifecycle_event_id,
                   relationship_session_id, external_identity_id, status,
                   started_at, ended_at, input_count, output_count,
                   error_count, error_summary, implementation_version
            FROM pipeline_runs
            WHERE \(predicates.joined(separator: " AND "))
            ORDER BY started_at DESC, rowid DESC
            LIMIT ?
            """
        )
        defer { statement.finalize() }
        for (index, binding) in bindings.enumerated() {
            try statement.bind(binding, at: Int32(index + 1))
        }
        try statement.bind(boundedLimit, at: Int32(bindings.count + 1))
        var rows: [(
            run: ProvenancePipelineRunRecord,
            stages: [ProvenancePipelineStageExecutionRecord],
            identityResolutions: [ProvenanceIdentityResolutionRecord],
            projectionLineage: [ProvenanceProjectionLineageRecord]
        )] = []
        while try statement.step() {
            guard let run = pipelineRun(from: statement) else { continue }
            rows.append((
                run: run,
                stages: try stages(pipelineRunID: run.pipelineRunID),
                identityResolutions: try identityResolutions(pipelineRunID: run.pipelineRunID),
                projectionLineage: try projectionLineage(pipelineRunID: run.pipelineRunID)
            ))
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
            try database.execute("PRAGMA user_version = 3")
            return
        }
        if version < 2 {
            try database.execute(identityResolutionSchemaSQL)
        }
        if version < 3 {
            try database.execute(projectionLineageSchemaSQL)
            try database.execute("PRAGMA user_version = 3")
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

    private func insert(_ identityResolution: ProvenanceIdentityResolutionRecord) throws {
        let statement = try database.prepare(
            """
            INSERT INTO identity_resolution_attempts (
                identity_resolution_id, pipeline_run_id, resolver_name,
                resolver_version, trigger_source, input_phase, input_agent_kind,
                input_parent_session_id, input_subsession_id_state,
                input_workspace_present, input_surface_present,
                input_working_directory_present, input_display_name_present,
                input_identity_kind, input_identity_value_hash,
                selected_identity_kind, selected_identity_value_category,
                candidate_count, selected_child_session_id,
                selected_lifecycle_event_id, selected_relationship_session_id,
                selected_external_identity_id, confidence, outcome,
                fallback_state, unresolved_reason, conflict_reason,
                started_at, ended_at, duration_ms
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(identity_resolution_id) DO UPDATE SET
                resolver_version = excluded.resolver_version,
                selected_child_session_id = excluded.selected_child_session_id,
                selected_lifecycle_event_id = excluded.selected_lifecycle_event_id,
                selected_relationship_session_id = excluded.selected_relationship_session_id,
                selected_external_identity_id = excluded.selected_external_identity_id,
                confidence = excluded.confidence,
                outcome = excluded.outcome,
                fallback_state = excluded.fallback_state,
                unresolved_reason = excluded.unresolved_reason,
                conflict_reason = excluded.conflict_reason,
                ended_at = excluded.ended_at,
                duration_ms = excluded.duration_ms
            """
        )
        defer { statement.finalize() }
        try statement.bind(identityResolution.identityResolutionID, at: 1)
        try statement.bind(identityResolution.pipelineRunID, at: 2)
        try statement.bind(identityResolution.resolverName, at: 3)
        try statement.bind(identityResolution.resolverVersion, at: 4)
        try statement.bind(identityResolution.triggerSource, at: 5)
        try statement.bind(identityResolution.inputPhase, at: 6)
        try statement.bind(identityResolution.inputAgentKind, at: 7)
        try statement.bind(identityResolution.inputParentSessionID, at: 8)
        try statement.bind(identityResolution.inputSubsessionIDState, at: 9)
        try statement.bind(identityResolution.inputWorkspacePresent ? 1 : 0, at: 10)
        try statement.bind(identityResolution.inputSurfacePresent ? 1 : 0, at: 11)
        try statement.bind(identityResolution.inputWorkingDirectoryPresent ? 1 : 0, at: 12)
        try statement.bind(identityResolution.inputDisplayNamePresent ? 1 : 0, at: 13)
        try statement.bind(identityResolution.inputIdentityKind, at: 14)
        try statement.bind(identityResolution.inputIdentityValueHash, at: 15)
        try statement.bind(identityResolution.selectedIdentityKind, at: 16)
        try statement.bind(identityResolution.selectedIdentityValueCategory, at: 17)
        try statement.bind(identityResolution.candidateCount, at: 18)
        try statement.bind(identityResolution.selectedChildSessionID, at: 19)
        try statement.bind(identityResolution.selectedLifecycleEventID, at: 20)
        try statement.bind(identityResolution.selectedRelationshipSessionID, at: 21)
        try statement.bind(identityResolution.selectedExternalIdentityID, at: 22)
        try statement.bind(identityResolution.confidence, at: 23)
        try statement.bind(identityResolution.outcome, at: 24)
        try statement.bind(identityResolution.fallbackState, at: 25)
        try statement.bind(identityResolution.unresolvedReason, at: 26)
        try statement.bind(identityResolution.conflictReason, at: 27)
        try statement.bind(identityResolution.startedAt.timeIntervalSince1970, at: 28)
        try statement.bind(identityResolution.endedAt.timeIntervalSince1970, at: 29)
        try statement.bind(identityResolution.durationMilliseconds, at: 30)
        _ = try statement.step()
    }

    private func insert(_ projectionLineage: ProvenanceProjectionLineageRecord) throws {
        let statement = try database.prepare(
            """
            INSERT INTO projection_lineage (
                projection_lineage_id, pipeline_run_id, stage_name,
                projection_kind, source_event_id, source_event_type,
                source_event_schema_version, source_payload_hash, target_table,
                target_entity_kind, target_entity_id, operation,
                generator_version, confidence, started_at, ended_at, duration_ms
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(projection_lineage_id) DO UPDATE SET
                operation = excluded.operation,
                generator_version = excluded.generator_version,
                confidence = excluded.confidence,
                ended_at = excluded.ended_at,
                duration_ms = excluded.duration_ms
            """
        )
        defer { statement.finalize() }
        try statement.bind(projectionLineage.projectionLineageID, at: 1)
        try statement.bind(projectionLineage.pipelineRunID, at: 2)
        try statement.bind(projectionLineage.stageName, at: 3)
        try statement.bind(projectionLineage.projectionKind, at: 4)
        try statement.bind(projectionLineage.sourceEventID, at: 5)
        try statement.bind(projectionLineage.sourceEventType, at: 6)
        try statement.bind(projectionLineage.sourceSchemaVersion, at: 7)
        try statement.bind(projectionLineage.sourcePayloadHash, at: 8)
        try statement.bind(projectionLineage.targetTable, at: 9)
        try statement.bind(projectionLineage.targetEntityKind, at: 10)
        try statement.bind(projectionLineage.targetEntityID, at: 11)
        try statement.bind(projectionLineage.operation, at: 12)
        try statement.bind(projectionLineage.generatorVersion, at: 13)
        try statement.bind(projectionLineage.confidence, at: 14)
        try statement.bind(projectionLineage.startedAt.timeIntervalSince1970, at: 15)
        try statement.bind(projectionLineage.endedAt.timeIntervalSince1970, at: 16)
        try statement.bind(projectionLineage.durationMilliseconds, at: 17)
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

    private func identityResolutions(pipelineRunID: String) throws -> [ProvenanceIdentityResolutionRecord] {
        let statement = try database.prepare(
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
                   conflict_reason, started_at, ended_at
            FROM identity_resolution_attempts
            WHERE pipeline_run_id = ?
            ORDER BY started_at ASC, rowid ASC
            """
        )
        defer { statement.finalize() }
        try statement.bind(pipelineRunID, at: 1)
        var rows: [ProvenanceIdentityResolutionRecord] = []
        while try statement.step() {
            guard let row = identityResolution(from: statement) else { continue }
            rows.append(row)
        }
        return rows
    }

    private func identityResolution(
        from statement: WorkProvenanceSQLiteStatement
    ) -> ProvenanceIdentityResolutionRecord? {
        guard let identityResolutionID = statement.string(at: 0),
              let pipelineRunID = statement.string(at: 1),
              let resolverName = statement.string(at: 2),
              let resolverVersion = statement.string(at: 3),
              let triggerSource = statement.string(at: 4),
              let inputPhase = statement.string(at: 5),
              let inputAgentKind = statement.string(at: 6),
              let inputParentSessionID = statement.string(at: 7),
              let inputSubsessionIDState = statement.string(at: 8),
              let inputIdentityKind = statement.string(at: 13),
              let inputIdentityValueHash = statement.string(at: 14),
              let selectedIdentityKind = statement.string(at: 15),
              let selectedIdentityValueCategory = statement.string(at: 16),
              let confidence = statement.string(at: 22),
              let outcome = statement.string(at: 23),
              let fallbackState = statement.string(at: 24) else {
            return nil
        }
        return ProvenanceIdentityResolutionRecord(
            identityResolutionID: identityResolutionID,
            pipelineRunID: pipelineRunID,
            resolverName: resolverName,
            resolverVersion: resolverVersion,
            triggerSource: triggerSource,
            inputPhase: inputPhase,
            inputAgentKind: inputAgentKind,
            inputParentSessionID: inputParentSessionID,
            inputSubsessionIDState: inputSubsessionIDState,
            inputWorkspacePresent: statement.int(at: 9) != 0,
            inputSurfacePresent: statement.int(at: 10) != 0,
            inputWorkingDirectoryPresent: statement.int(at: 11) != 0,
            inputDisplayNamePresent: statement.int(at: 12) != 0,
            inputIdentityKind: inputIdentityKind,
            inputIdentityValueHash: inputIdentityValueHash,
            selectedIdentityKind: selectedIdentityKind,
            selectedIdentityValueCategory: selectedIdentityValueCategory,
            candidateCount: statement.int(at: 17),
            selectedChildSessionID: statement.string(at: 18),
            selectedLifecycleEventID: statement.string(at: 19),
            selectedRelationshipSessionID: statement.string(at: 20),
            selectedExternalIdentityID: statement.string(at: 21),
            confidence: confidence,
            outcome: outcome,
            fallbackState: fallbackState,
            unresolvedReason: statement.string(at: 25),
            conflictReason: statement.string(at: 26),
            startedAt: Date(timeIntervalSince1970: statement.double(at: 27) ?? 0),
            endedAt: Date(timeIntervalSince1970: statement.double(at: 28) ?? 0)
        )
    }

    private func projectionLineage(pipelineRunID: String) throws -> [ProvenanceProjectionLineageRecord] {
        let statement = try database.prepare(
            """
            SELECT projection_lineage_id, pipeline_run_id, stage_name,
                   projection_kind, source_event_id, source_event_type,
                   source_event_schema_version, source_payload_hash,
                   target_table, target_entity_kind, target_entity_id,
                   operation, generator_version, confidence, started_at,
                   ended_at
            FROM projection_lineage
            WHERE pipeline_run_id = ?
            ORDER BY started_at ASC, rowid ASC
            """
        )
        defer { statement.finalize() }
        try statement.bind(pipelineRunID, at: 1)
        var rows: [ProvenanceProjectionLineageRecord] = []
        while try statement.step() {
            guard let row = projectionLineage(from: statement) else { continue }
            rows.append(row)
        }
        return rows
    }

    private func projectionLineage(
        from statement: WorkProvenanceSQLiteStatement
    ) -> ProvenanceProjectionLineageRecord? {
        guard let projectionLineageID = statement.string(at: 0),
              let pipelineRunID = statement.string(at: 1),
              let stageName = statement.string(at: 2),
              let projectionKind = statement.string(at: 3),
              let sourceEventID = statement.string(at: 4),
              let sourceEventType = statement.string(at: 5) else {
            return nil
        }
        guard let sourcePayloadHash = statement.string(at: 7),
              let targetTable = statement.string(at: 8),
              let targetEntityKind = statement.string(at: 9),
              let targetEntityID = statement.string(at: 10),
              let operation = statement.string(at: 11),
              let generatorVersion = statement.string(at: 12),
              let confidence = statement.string(at: 13) else {
            return nil
        }
        return ProvenanceProjectionLineageRecord(
            projectionLineageID: projectionLineageID,
            pipelineRunID: pipelineRunID,
            stageName: stageName,
            projectionKind: projectionKind,
            sourceEventID: sourceEventID,
            sourceEventType: sourceEventType,
            sourceSchemaVersion: statement.int(at: 6),
            sourcePayloadHash: sourcePayloadHash,
            targetTable: targetTable,
            targetEntityKind: targetEntityKind,
            targetEntityID: targetEntityID,
            operation: operation,
            generatorVersion: generatorVersion,
            confidence: confidence,
            startedAt: Date(timeIntervalSince1970: statement.double(at: 14) ?? 0),
            endedAt: Date(timeIntervalSince1970: statement.double(at: 15) ?? 0)
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

        \(identityResolutionSchemaSQL)
        \(projectionLineageSchemaSQL)
        """
    }

    private static var identityResolutionSchemaSQL: String {
        """
        CREATE TABLE IF NOT EXISTS identity_resolution_attempts (
            identity_resolution_id TEXT PRIMARY KEY NOT NULL,
            pipeline_run_id TEXT NOT NULL,
            resolver_name TEXT NOT NULL,
            resolver_version TEXT NOT NULL,
            trigger_source TEXT NOT NULL,
            input_phase TEXT NOT NULL,
            input_agent_kind TEXT NOT NULL,
            input_parent_session_id TEXT NOT NULL,
            input_subsession_id_state TEXT NOT NULL,
            input_workspace_present INTEGER NOT NULL,
            input_surface_present INTEGER NOT NULL,
            input_working_directory_present INTEGER NOT NULL,
            input_display_name_present INTEGER NOT NULL,
            input_identity_kind TEXT NOT NULL,
            input_identity_value_hash TEXT NOT NULL,
            selected_identity_kind TEXT NOT NULL,
            selected_identity_value_category TEXT NOT NULL,
            candidate_count INTEGER NOT NULL,
            selected_child_session_id TEXT,
            selected_lifecycle_event_id TEXT,
            selected_relationship_session_id TEXT,
            selected_external_identity_id TEXT,
            confidence TEXT NOT NULL,
            outcome TEXT NOT NULL,
            fallback_state TEXT NOT NULL,
            unresolved_reason TEXT,
            conflict_reason TEXT,
            started_at REAL NOT NULL,
            ended_at REAL NOT NULL,
            duration_ms REAL NOT NULL
        );
        CREATE INDEX IF NOT EXISTS identity_resolution_attempts_run_idx
            ON identity_resolution_attempts(pipeline_run_id, started_at);
        CREATE INDEX IF NOT EXISTS identity_resolution_attempts_outcome_idx
            ON identity_resolution_attempts(outcome, confidence);
        """
    }

    private static var projectionLineageSchemaSQL: String {
        """
        CREATE TABLE IF NOT EXISTS projection_lineage (
            projection_lineage_id TEXT PRIMARY KEY NOT NULL,
            pipeline_run_id TEXT NOT NULL,
            stage_name TEXT NOT NULL,
            projection_kind TEXT NOT NULL,
            source_event_id TEXT NOT NULL,
            source_event_type TEXT NOT NULL,
            source_event_schema_version INTEGER NOT NULL,
            source_payload_hash TEXT NOT NULL,
            target_table TEXT NOT NULL,
            target_entity_kind TEXT NOT NULL,
            target_entity_id TEXT NOT NULL,
            operation TEXT NOT NULL,
            generator_version TEXT NOT NULL,
            confidence TEXT NOT NULL,
            started_at REAL NOT NULL,
            ended_at REAL NOT NULL,
            duration_ms REAL NOT NULL
        );
        CREATE INDEX IF NOT EXISTS projection_lineage_run_idx
            ON projection_lineage(pipeline_run_id, started_at);
        CREATE INDEX IF NOT EXISTS projection_lineage_target_idx
            ON projection_lineage(target_entity_kind, target_entity_id);
        """
    }
}
