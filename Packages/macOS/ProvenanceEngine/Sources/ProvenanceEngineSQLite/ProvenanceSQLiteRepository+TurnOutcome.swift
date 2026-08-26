import Foundation
import ProvenanceEngineContracts

extension ProvenanceSQLiteRepository {
    static let turnOutcomeRuleID = "deterministic_turn_outcome"
    static let turnOutcomeRuleVersion = "1"
    static let turnOutcomeCommandRuleVersion = "1"

    func turnOutcomeRecord(_ request: ProvenanceTurnOutcomeRequest) throws
        -> ProvenanceTurnOutcomeResponse {
        guard try codingAgentTurn(id: request.turnID) != nil else {
            return ProvenanceTurnOutcomeResponse(
                found: false,
                reason: "no_turn",
                turnID: request.turnID,
                outcome: nil
            )
        }

        if let revisionID = request.revisionID {
            return try turnOutcomeRevisionResponse(turnID: request.turnID, revisionID: revisionID)
        }

        try projectTurnOutcomeIfNeeded(
            turnID: request.turnID,
            latestEventSequence: turnOutcomeLatestLedgerSequence()
        )

        guard let revisionID = try latestTurnOutcomeRevisionID(turnID: request.turnID) else {
            return ProvenanceTurnOutcomeResponse(
                found: false,
                reason: "no_outcome",
                turnID: request.turnID,
                outcome: nil
            )
        }
        return try turnOutcomeRevisionResponse(turnID: request.turnID, revisionID: revisionID)
    }

    func refreshTurnOutcomes(
        affectedBy event: ProvenanceEvent,
        latestEventSequence: Int?
    ) throws {
        let turnIDs = try affectedTurnOutcomeIDs(event: event)
        for turnID in turnIDs.sorted() {
            try projectTurnOutcomeIfNeeded(
                turnID: turnID,
                latestEventSequence: latestEventSequence
            )
        }
    }

    private func turnOutcomeRevisionResponse(
        turnID: String,
        revisionID: String
    ) throws -> ProvenanceTurnOutcomeResponse {
        guard let outcome = try turnOutcomeRevision(turnID: turnID, revisionID: revisionID) else {
            return ProvenanceTurnOutcomeResponse(
                found: false,
                reason: "no_revision",
                turnID: turnID,
                outcome: nil
            )
        }
        return ProvenanceTurnOutcomeResponse(
            found: true,
            reason: nil,
            turnID: turnID,
            outcome: outcome
        )
    }

    private func projectTurnOutcomeIfNeeded(
        turnID: String,
        latestEventSequence: Int?
    ) throws {
        guard let projected = try projectedTurnOutcome(
            turnID: turnID,
            latestEventSequence: latestEventSequence
        ) else {
            return
        }
        let outcomeData = try payloadEncoder.encode(projected)
        guard let outcomeJSON = String(data: outcomeData, encoding: .utf8) else {
            throw ProvenanceSQLiteError.sqlite(message: "failed to encode turn outcome")
        }

        let insertRevision = try database.prepare(
            """
            INSERT INTO provenance_coding_agent_turn_outcome_revisions (
                id,
                turn_id,
                session_id,
                projection_rule_id,
                projection_rule_version,
                source_watermark_sequence,
                content_fingerprint,
                outcome_json,
                created_at_seconds
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                source_watermark_sequence = excluded.source_watermark_sequence,
                outcome_json = excluded.outcome_json,
                created_at_seconds = excluded.created_at_seconds
            """
        )
        defer { insertRevision.finalize() }
        try insertRevision.bind(projected.projection.revisionID, at: 1)
        try insertRevision.bind(projected.turnID, at: 2)
        try insertRevision.bind(projected.sessionID, at: 3)
        try insertRevision.bind(projected.projection.projectionRuleID, at: 4)
        try insertRevision.bind(projected.projection.projectionRuleVersion, at: 5)
        if let watermark = projected.projection.sourceEvidenceWatermark {
            try insertRevision.bind(watermark, at: 6)
        } else {
            try insertRevision.bind(nil as Double?, at: 6)
        }
        try insertRevision.bind(projected.projection.contentFingerprint, at: 7)
        try insertRevision.bind(outcomeJSON, at: 8)
        try insertRevision.bind(projected.projection.generatedAt?.timeIntervalSince1970, at: 9)
        _ = try insertRevision.step()

        let upsertLatest = try database.prepare(
            """
            INSERT INTO provenance_coding_agent_turn_outcomes (
                turn_id,
                latest_revision_id,
                session_id,
                projection_rule_id,
                projection_rule_version,
                latest_evaluated_sequence,
                updated_at_seconds
            ) VALUES (?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(turn_id) DO UPDATE SET
                latest_revision_id = excluded.latest_revision_id,
                session_id = excluded.session_id,
                projection_rule_id = excluded.projection_rule_id,
                projection_rule_version = excluded.projection_rule_version,
                latest_evaluated_sequence = excluded.latest_evaluated_sequence,
                updated_at_seconds = excluded.updated_at_seconds
            """
        )
        defer { upsertLatest.finalize() }
        try upsertLatest.bind(projected.turnID, at: 1)
        try upsertLatest.bind(projected.projection.revisionID, at: 2)
        try upsertLatest.bind(projected.sessionID, at: 3)
        try upsertLatest.bind(projected.projection.projectionRuleID, at: 4)
        try upsertLatest.bind(projected.projection.projectionRuleVersion, at: 5)
        if let watermark = projected.projection.sourceEvidenceWatermark {
            try upsertLatest.bind(watermark, at: 6)
        } else {
            try upsertLatest.bind(nil as Double?, at: 6)
        }
        try upsertLatest.bind(projected.projection.generatedAt?.timeIntervalSince1970, at: 7)
        _ = try upsertLatest.step()
    }

    private func projectedTurnOutcome(
        turnID: String,
        latestEventSequence: Int?
    ) throws -> ProvenanceTurnOutcome? {
        guard let turn = try codingAgentTurn(id: turnID) else { return nil }
        let session = try session(id: turn.sessionID)
        let prompt = try turnOutcomeLatestPrompt(turnID: turnID)
        let plan = try turnOutcomeLatestPlan(turnID: turnID)
        let commands = try turnOutcomeRecordIDs(
            tableName: "provenance_coding_agent_commands",
            timeColumn: "completed_at_seconds",
            turnID: turnID
        ).compactMap { try codingAgentCommand(id: $0) }
        let reasoningSummaries = try turnOutcomeRecordIDs(
            tableName: "provenance_coding_agent_reasoning_summaries",
            timeColumn: "completed_at_seconds",
            turnID: turnID
        ).compactMap { try codingAgentReasoningSummary(id: $0) }
        let attributions = try turnOutcomeRecordIDs(
            tableName: "provenance_coding_agent_file_change_attributions",
            timeColumn: "observed_at_seconds",
            turnID: turnID
        ).compactMap { try codingAgentFileChangeAttribution(id: $0) }
        let evidenceIndex = try turnOutcomeEvidenceIndex()
        let repositoryBoundary = try turnOutcomeRepositoryBoundary(
            turn: turn,
            session: session,
            commandCwd: nil,
            evidenceIndex: evidenceIndex
        )
        let objective = prompt.map { prompt in
            ProvenanceTurnOutcomeTextFact(
                id: "objective:\(prompt.id)",
                kind: "submitted_prompt",
                text: prompt.text,
                evidence: evidenceIndex.references(kind: "coding_agent_prompt", id: prompt.id)
            )
        }
        let planItems = plan?.steps
            .sorted { lhs, rhs in
                lhs.order == rhs.order ? lhs.id < rhs.id : lhs.order < rhs.order
            }
            .map { step in
                ProvenanceTurnOutcomePlanItem(
                    id: "\(plan?.id ?? "plan"):\(step.id)",
                    status: step.status,
                    text: step.text,
                    evidence: plan.map {
                        evidenceIndex.references(kind: "coding_agent_plan_update", id: $0.id)
                    } ?? []
                )
            } ?? []
        var actionsCompleted = planItems
            .filter { isCompletedPlanStatus($0.status) }
            .map {
                ProvenanceTurnOutcomeTextFact(
                    id: "completed_action:\($0.id)",
                    kind: "completed_plan_item",
                    text: $0.text,
                    evidence: $0.evidence
                )
            }
        actionsCompleted += reasoningSummaries
            .filter { isExplicitCompletedActionReport($0.text) }
            .map {
                ProvenanceTurnOutcomeTextFact(
                    id: "reported_action:\($0.id)",
                    kind: "visible_assistant_statement",
                    text: $0.text,
                    evidence: evidenceIndex.references(kind: "coding_agent_reasoning_summary", id: $0.id)
                )
            }
        let outcomeCommands = commands.map { command in
            ProvenanceTurnOutcomeCommand(
                id: command.id,
                operationID: command.operationID,
                command: command.command,
                cwd: command.cwd,
                status: command.status,
                exitCode: command.exitCode,
                outputSummary: command.outputSummary,
                startedAt: command.startedAt,
                completedAt: command.completedAt,
                classification: classifyTurnOutcomeCommand(command.command),
                evidence: evidenceIndex.references(kind: "coding_agent_command", id: command.id)
            )
        }
        let validations = try outcomeCommands.compactMap { command -> ProvenanceTurnOutcomeValidation? in
            guard isValidationClassification(command.classification.kind) else { return nil }
            let commandRecord = commands.first { $0.id == command.id }
            let boundary = try commandRecord.map {
                try turnOutcomeRepositoryBoundary(
                    turn: turn,
                    session: session,
                    commandCwd: $0.cwd,
                    evidenceIndex: evidenceIndex
                )
            } ?? repositoryBoundary
            return ProvenanceTurnOutcomeValidation(
                id: "validation:\(command.id)",
                commandID: command.id,
                validationKind: command.classification.kind,
                command: command.command,
                cwd: command.cwd,
                status: command.status,
                exitCode: command.exitCode,
                resultStatus: validationResultStatus(status: command.status, exitCode: command.exitCode),
                repositoryBoundary: boundary,
                evidence: command.evidence
            )
        }
        let artifacts = try attributions.flatMap { attribution in
            try turnOutcomeArtifacts(attribution: attribution, evidenceIndex: evidenceIndex)
        }
        let blockers = planItems
            .filter { isBlockedPlanStatus($0.status) }
            .map {
                ProvenanceTurnOutcomeTextFact(
                    id: "blocker:\($0.id)",
                    kind: "blocked_plan_item",
                    text: $0.text,
                    evidence: $0.evidence
                )
            }
        let unresolvedItems = planItems
            .filter { !isCompletedPlanStatus($0.status) }
            .map {
                ProvenanceTurnOutcomeTextFact(
                    id: "unresolved:\($0.id)",
                    kind: "unresolved_plan_item",
                    text: $0.text,
                    evidence: $0.evidence
                )
            }
        let resumePoint = planItems.first(where: { isActivePlanStatus($0.status) })
            .map {
                ProvenanceTurnOutcomeTextFact(
                    id: "resume:\($0.id)",
                    kind: "active_plan_item",
                    text: $0.text,
                    evidence: $0.evidence
                )
            } ?? planItems.first(where: { isPendingPlanStatus($0.status) })
            .map {
                ProvenanceTurnOutcomeTextFact(
                    id: "resume:\($0.id)",
                    kind: "pending_plan_item",
                    text: $0.text,
                    evidence: $0.evidence
                )
            }
        let completionState = normalizedTurnCompletionState(turn.status)
        let completeness = turnOutcomeCompleteness(
            objective: objective,
            planItems: planItems,
            commands: outcomeCommands,
            artifacts: artifacts,
            validations: validations,
            blockers: blockers,
            unresolvedItems: unresolvedItems,
            repositoryBoundary: repositoryBoundary,
            resumePoint: resumePoint,
            evaluatedThroughSequence: latestEventSequence
        )
        let fingerprint = turnOutcomeContentFingerprint(
            turn: turn,
            objective: objective,
            planItems: planItems,
            actionsCompleted: actionsCompleted,
            commands: outcomeCommands,
            artifacts: artifacts,
            decisions: [],
            validations: validations,
            blockers: blockers,
            unresolvedItems: unresolvedItems,
            repositoryBoundary: repositoryBoundary,
            resumePoint: resumePoint,
            lifecycleState: turn.status,
            completionState: completionState,
            completeness: completeness
        )
        let revisionID = stableIDFactory.id(
            prefix: "turn-outcome-revision",
            value: [
                turn.id,
                Self.turnOutcomeRuleID,
                Self.turnOutcomeRuleVersion,
                fingerprint,
            ].joined(separator: "\n")
        )
        let generatedAt = try turnOutcomeEventTimestamp(sequence: latestEventSequence) ?? turn.updatedAt
        let projection = ProvenanceTurnOutcomeProjectionMetadata(
            revisionID: revisionID,
            projectionRuleID: Self.turnOutcomeRuleID,
            projectionRuleVersion: Self.turnOutcomeRuleVersion,
            contentFingerprint: fingerprint,
            sourceEvidenceWatermark: latestEventSequence,
            generatedAt: generatedAt
        )
        return ProvenanceTurnOutcome(
            turnID: turn.id,
            sessionID: turn.sessionID,
            provider: turn.provider,
            providerTurnID: turn.providerTurnID,
            projection: projection,
            objective: objective,
            planItems: planItems,
            actionsCompleted: actionsCompleted,
            commandsCompleted: outcomeCommands,
            artifactsChanged: artifacts,
            decisions: [],
            validationsAttempted: validations,
            blockers: blockers,
            unresolvedItems: unresolvedItems,
            repositoryBoundary: repositoryBoundary,
            resumePoint: resumePoint,
            lifecycleState: turn.status,
            completionState: completionState,
            completeness: completeness
        )
    }

    private func affectedTurnOutcomeIDs(event: ProvenanceEvent) throws -> Set<String> {
        let payload = event.payload
        var turnIDs = Set<String>()
        var sessionIDs = Set<String>()

        if let sessionID = event.sessionID {
            sessionIDs.insert(sessionID)
        }
        if let session = payload.session {
            sessionIDs.insert(session.id)
        }
        if let thread = payload.codingAgentThread {
            sessionIDs.insert(thread.sessionID)
        }
        if let turn = payload.codingAgentTurn {
            turnIDs.insert(turn.id)
            sessionIDs.insert(turn.sessionID)
        }
        if let prompt = payload.codingAgentPrompt {
            if let turnID = prompt.turnID {
                turnIDs.insert(turnID)
            }
            sessionIDs.insert(prompt.sessionID)
        }
        if let plan = payload.codingAgentPlanUpdate {
            if let turnID = plan.turnID {
                turnIDs.insert(turnID)
            }
            sessionIDs.insert(plan.sessionID)
        }
        if let command = payload.codingAgentCommand {
            if let turnID = command.turnID {
                turnIDs.insert(turnID)
            }
            sessionIDs.insert(command.sessionID)
        }
        if let summary = payload.codingAgentReasoningSummary {
            if let turnID = summary.turnID {
                turnIDs.insert(turnID)
            }
            sessionIDs.insert(summary.sessionID)
        }
        if let attribution = payload.codingAgentFileChangeAttribution {
            if let turnID = attribution.turnID {
                turnIDs.insert(turnID)
            }
            sessionIDs.insert(attribution.sessionID)
        }
        for sessionID in sessionIDs {
            turnIDs.formUnion(try turnOutcomeTurnIDs(sessionID: sessionID))
        }
        if let worktree = payload.worktree {
            turnIDs.formUnion(try turnOutcomeTurnIDs(worktreeID: worktree.id))
        }
        if let repository = payload.repository {
            turnIDs.formUnion(try turnOutcomeTurnIDs(repositoryID: repository.id))
        }
        if let changeSet = payload.changeSet {
            turnIDs.formUnion(try turnOutcomeTurnIDs(changeSetID: changeSet.id))
        }
        for fileChange in payload.fileChanges {
            turnIDs.formUnion(try turnOutcomeTurnIDs(fileChangeID: fileChange.id))
            turnIDs.formUnion(try turnOutcomeTurnIDs(worktreeID: fileChange.worktreeID))
        }
        return turnIDs
    }

    private func turnOutcomeRevision(turnID: String, revisionID: String) throws -> ProvenanceTurnOutcome? {
        let query = try database.prepare(
            """
            SELECT outcome_json
            FROM provenance_coding_agent_turn_outcome_revisions
            WHERE turn_id = ?
              AND id = ?
            """
        )
        defer { query.finalize() }
        try query.bind(turnID, at: 1)
        try query.bind(revisionID, at: 2)
        guard try query.step(),
              let json = query.string(at: 0),
              let data = json.data(using: .utf8) else {
            return nil
        }
        return try payloadDecoder.decode(ProvenanceTurnOutcome.self, from: data)
    }

    private func latestTurnOutcomeRevisionID(turnID: String) throws -> String? {
        let query = try database.prepare(
            """
            SELECT latest_revision_id
            FROM provenance_coding_agent_turn_outcomes
            WHERE turn_id = ?
            """
        )
        defer { query.finalize() }
        try query.bind(turnID, at: 1)
        guard try query.step() else { return nil }
        return query.string(at: 0)
    }

    private func turnOutcomeLatestPrompt(turnID: String) throws -> ProvenanceCodingAgentPromptRecord? {
        guard let id = try turnOutcomeLatestRecordID(
            tableName: "provenance_coding_agent_prompts",
            timeColumn: "submitted_at_seconds",
            turnID: turnID
        ) else { return nil }
        return try codingAgentPrompt(id: id)
    }

    private func turnOutcomeLatestPlan(turnID: String) throws -> ProvenanceCodingAgentPlanUpdateRecord? {
        guard let id = try turnOutcomeLatestRecordID(
            tableName: "provenance_coding_agent_plan_updates",
            timeColumn: "observed_at_seconds",
            turnID: turnID
        ) else { return nil }
        return try codingAgentPlanUpdate(id: id)
    }

    private func turnOutcomeLatestRecordID(
        tableName: String,
        timeColumn: String,
        turnID: String
    ) throws -> String? {
        let query = try database.prepare(
            """
            SELECT id
            FROM \(tableName)
            WHERE turn_id = ?
            ORDER BY \(timeColumn) DESC, rowid DESC
            LIMIT 1
            """
        )
        defer { query.finalize() }
        try query.bind(turnID, at: 1)
        guard try query.step() else { return nil }
        return query.string(at: 0)
    }

    private func turnOutcomeRecordIDs(
        tableName: String,
        timeColumn: String,
        turnID: String
    ) throws -> [String] {
        let query = try database.prepare(
            """
            SELECT id
            FROM \(tableName)
            WHERE turn_id = ?
            ORDER BY \(timeColumn) ASC, rowid ASC
            """
        )
        defer { query.finalize() }
        try query.bind(turnID, at: 1)
        return try turnOutcomeStringIDs(from: query)
    }

    private func turnOutcomeTurnIDs(sessionID: String) throws -> [String] {
        let query = try database.prepare(
            """
            SELECT id
            FROM provenance_coding_agent_turns
            WHERE session_id = ?
            ORDER BY COALESCE(started_at_seconds, updated_at_seconds) ASC, rowid ASC
            """
        )
        defer { query.finalize() }
        try query.bind(sessionID, at: 1)
        return try turnOutcomeStringIDs(from: query)
    }

    private func turnOutcomeTurnIDs(worktreeID: String) throws -> [String] {
        let query = try database.prepare(
            """
            SELECT DISTINCT turns.id
            FROM provenance_coding_agent_turns AS turns
            LEFT JOIN provenance_sessions AS sessions ON sessions.id = turns.session_id
            LEFT JOIN provenance_coding_agent_threads AS threads ON threads.id = turns.thread_id
            WHERE sessions.worktree_id = ?
               OR threads.worktree_id = ?
            ORDER BY turns.id ASC
            """
        )
        defer { query.finalize() }
        try query.bind(worktreeID, at: 1)
        try query.bind(worktreeID, at: 2)
        return try turnOutcomeStringIDs(from: query)
    }

    private func turnOutcomeTurnIDs(repositoryID: String) throws -> [String] {
        let query = try database.prepare(
            """
            SELECT DISTINCT turns.id
            FROM provenance_coding_agent_turns AS turns
            LEFT JOIN provenance_sessions AS sessions ON sessions.id = turns.session_id
            LEFT JOIN provenance_coding_agent_threads AS threads ON threads.id = turns.thread_id
            LEFT JOIN provenance_worktrees AS session_worktree ON session_worktree.id = sessions.worktree_id
            LEFT JOIN provenance_worktrees AS thread_worktree ON thread_worktree.id = threads.worktree_id
            WHERE session_worktree.repository_id = ?
               OR thread_worktree.repository_id = ?
            ORDER BY turns.id ASC
            """
        )
        defer { query.finalize() }
        try query.bind(repositoryID, at: 1)
        try query.bind(repositoryID, at: 2)
        return try turnOutcomeStringIDs(from: query)
    }

    private func turnOutcomeTurnIDs(changeSetID: String) throws -> [String] {
        let query = try database.prepare(
            """
            SELECT DISTINCT turn_id
            FROM provenance_coding_agent_file_change_attributions
            WHERE change_set_id = ?
              AND turn_id IS NOT NULL
            ORDER BY turn_id ASC
            """
        )
        defer { query.finalize() }
        try query.bind(changeSetID, at: 1)
        return try turnOutcomeStringIDs(from: query)
    }

    private func turnOutcomeTurnIDs(fileChangeID: String) throws -> [String] {
        let query = try database.prepare(
            """
            SELECT DISTINCT turn_id
            FROM provenance_coding_agent_file_change_attributions
            WHERE file_change_ids_json LIKE ?
              AND turn_id IS NOT NULL
            ORDER BY turn_id ASC
            """
        )
        defer { query.finalize() }
        try query.bind("%\"\(fileChangeID)\"%", at: 1)
        return try turnOutcomeStringIDs(from: query)
    }

    private func turnOutcomeStringIDs(from query: ProvenanceSQLiteStatement) throws -> [String] {
        var ids: [String] = []
        while try query.step() {
            if let id = query.string(at: 0) {
                ids.append(id)
            }
        }
        return ids
    }

    private func turnOutcomeFileChange(id: String) throws -> ProvenanceFileChangeRecord? {
        let query = try database.prepare(
            """
            SELECT
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
            WHERE id = ?
            """
        )
        defer { query.finalize() }
        try query.bind(id, at: 1)
        guard try query.step(),
              let changeSetID = query.string(at: 0),
              let repositoryID = query.string(at: 1),
              let worktreeID = query.string(at: 2),
              let path = query.string(at: 3),
              let status = query.string(at: 4),
              let sourceRawValue = query.string(at: 7),
              let source = ProvenanceSource(rawValue: sourceRawValue),
              let confidenceRawValue = query.string(at: 8),
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
            beforeHash: query.string(at: 5),
            afterHash: query.string(at: 6),
            attributionSource: source,
            attributionConfidence: confidence,
            updatedAt: Date(timeIntervalSince1970: query.double(at: 9) ?? 0)
        )
    }

    private func turnOutcomeArtifacts(
        attribution: ProvenanceCodingAgentFileChangeAttributionRecord,
        evidenceIndex: TurnOutcomeEvidenceIndex
    ) throws -> [ProvenanceTurnOutcomeArtifact] {
        let attributionEvidence = evidenceIndex.references(
            kind: "coding_agent_file_change_attribution",
            id: attribution.id
        )
        if !attribution.fileChangeIDs.isEmpty {
            return try attribution.fileChangeIDs.enumerated().map { index, fileChangeID in
                let fileChange = try turnOutcomeFileChange(id: fileChangeID)
                return ProvenanceTurnOutcomeArtifact(
                    id: "artifact:\(attribution.id):\(fileChangeID)",
                    path: fileChange?.path ?? attribution.paths[safe: index] ?? fileChangeID,
                    status: fileChange?.status,
                    fileChangeID: fileChangeID,
                    changeSetID: fileChange?.changeSetID ?? attribution.changeSetID,
                    evidence: attributionEvidence + evidenceIndex.references(kind: "file_change", id: fileChangeID)
                )
            }
        }
        return attribution.paths.sorted().enumerated().map { index, path in
            ProvenanceTurnOutcomeArtifact(
                id: "artifact:\(attribution.id):path:\(index)",
                path: path,
                status: nil,
                fileChangeID: nil,
                changeSetID: attribution.changeSetID,
                evidence: attributionEvidence
            )
        }
    }

    private func turnOutcomeRepositoryBoundary(
        turn: ProvenanceCodingAgentTurnRecord,
        session: ProvenanceSessionRecord?,
        commandCwd: String?,
        evidenceIndex: TurnOutcomeEvidenceIndex
    ) throws -> ProvenanceTurnOutcomeRepositoryBoundary? {
        let thread = try turn.threadID.flatMap { try codingAgentThread(id: $0) }
        let worktreeID = session?.worktreeID ?? thread?.worktreeID
        let observedWorktree: ProvenanceWorktreeRecord?
        if let worktreeID {
            observedWorktree = try worktree(id: worktreeID)
        } else {
            observedWorktree = nil
        }
        let observedRepository: ProvenanceRepositoryRecord?
        if let repositoryID = observedWorktree?.repositoryID {
            observedRepository = try repository(id: repositoryID)
        } else {
            observedRepository = nil
        }
        let cwd = commandCwd ?? session?.cwd
        var evidence = evidenceIndex.references(kind: "coding_agent_turn", id: turn.id)
        evidence += evidenceIndex.references(kind: "session", id: session?.id)
        evidence += evidenceIndex.references(kind: "coding_agent_thread", id: thread?.id)
        evidence += evidenceIndex.references(kind: "worktree", id: observedWorktree?.id)
        evidence += evidenceIndex.references(kind: "repository", id: observedRepository?.id)
        guard observedRepository != nil || observedWorktree != nil || cwd != nil || !evidence.isEmpty else {
            return nil
        }
        return ProvenanceTurnOutcomeRepositoryBoundary(
            repositoryID: observedRepository?.id,
            repositoryPath: observedRepository?.path,
            worktreeID: observedWorktree?.id,
            worktreePath: observedWorktree?.path,
            branch: observedWorktree?.branch,
            head: observedWorktree?.currentHEAD,
            cwd: cwd,
            evidence: evidence
        )
    }

    private func turnOutcomeCompleteness(
        objective: ProvenanceTurnOutcomeTextFact?,
        planItems: [ProvenanceTurnOutcomePlanItem],
        commands: [ProvenanceTurnOutcomeCommand],
        artifacts: [ProvenanceTurnOutcomeArtifact],
        validations: [ProvenanceTurnOutcomeValidation],
        blockers: [ProvenanceTurnOutcomeTextFact],
        unresolvedItems: [ProvenanceTurnOutcomeTextFact],
        repositoryBoundary: ProvenanceTurnOutcomeRepositoryBoundary?,
        resumePoint: ProvenanceTurnOutcomeTextFact?,
        evaluatedThroughSequence: Int?
    ) -> ProvenanceTurnOutcomeCompleteness {
        let fields = [
            availability(
                field: "objective",
                observed: objective != nil,
                reason: "no_submitted_prompt",
                evidence: objective?.evidence ?? []
            ),
            availability(
                field: "plan_items",
                observed: !planItems.isEmpty,
                reason: "no_plan_update",
                evidence: planItems.flatMap(\.evidence)
            ),
            availability(
                field: "completed_commands",
                observed: !commands.isEmpty,
                reason: "no_completed_command",
                evidence: commands.flatMap(\.evidence)
            ),
            availability(
                field: "artifacts_changed",
                observed: !artifacts.isEmpty,
                reason: "no_file_change_attribution",
                evidence: artifacts.flatMap(\.evidence)
            ),
            ProvenanceTurnOutcomeAvailability(
                field: "decisions",
                status: "not_observed",
                reason: "no_explicit_decision_evidence",
                evidence: []
            ),
            availability(
                field: "validations_attempted",
                observed: !validations.isEmpty,
                reason: "no_supported_validation_command",
                evidence: validations.flatMap(\.evidence)
            ),
            availability(
                field: "blockers",
                observed: !blockers.isEmpty,
                reason: "no_blocked_plan_item",
                evidence: blockers.flatMap(\.evidence)
            ),
            availability(
                field: "unresolved_items",
                observed: !unresolvedItems.isEmpty,
                reason: "no_unresolved_plan_item",
                evidence: unresolvedItems.flatMap(\.evidence)
            ),
            availability(
                field: "repository_boundary",
                observed: repositoryBoundary != nil,
                reason: "no_repository_or_worktree_boundary",
                evidence: repositoryBoundary?.evidence ?? []
            ),
            availability(
                field: "resume_point",
                observed: resumePoint != nil,
                reason: "no_active_or_pending_plan_item",
                evidence: resumePoint?.evidence ?? []
            ),
        ]
        let status = fields.allSatisfy { $0.status == "observed" } ? "complete" : "partial"
        return ProvenanceTurnOutcomeCompleteness(
            status: status,
            evaluatedThroughSequence: evaluatedThroughSequence,
            fields: fields,
            notes: [
                "decision projection requires explicit accepted decision evidence and does not infer from prose",
                "validation_run records are not attached unless represented by a turn-linked command in this rule version",
            ]
        )
    }

    private func availability(
        field: String,
        observed: Bool,
        reason: String,
        evidence: [ProvenanceTurnOutcomeEvidenceReference]
    ) -> ProvenanceTurnOutcomeAvailability {
        ProvenanceTurnOutcomeAvailability(
            field: field,
            status: observed ? "observed" : "not_observed",
            reason: observed ? nil : reason,
            evidence: evidence
        )
    }

    private func turnOutcomeContentFingerprint(
        turn: ProvenanceCodingAgentTurnRecord,
        objective: ProvenanceTurnOutcomeTextFact?,
        planItems: [ProvenanceTurnOutcomePlanItem],
        actionsCompleted: [ProvenanceTurnOutcomeTextFact],
        commands: [ProvenanceTurnOutcomeCommand],
        artifacts: [ProvenanceTurnOutcomeArtifact],
        decisions: [ProvenanceTurnOutcomeTextFact],
        validations: [ProvenanceTurnOutcomeValidation],
        blockers: [ProvenanceTurnOutcomeTextFact],
        unresolvedItems: [ProvenanceTurnOutcomeTextFact],
        repositoryBoundary: ProvenanceTurnOutcomeRepositoryBoundary?,
        resumePoint: ProvenanceTurnOutcomeTextFact?,
        lifecycleState: String,
        completionState: String,
        completeness: ProvenanceTurnOutcomeCompleteness
    ) -> String {
        var parts = [
            "schema=1",
            "turn=\(turn.id)",
            "session=\(turn.sessionID)",
            "provider=\(turn.provider)",
            "provider_turn=\(turn.providerTurnID)",
            "lifecycle=\(lifecycleState)",
            "completion=\(completionState)",
            "objective=\(objective?.text ?? "")",
        ]
        for item in planItems {
            parts.append("plan|\(item.id)|\(item.status)|\(item.text)")
        }
        for item in actionsCompleted {
            parts.append("action|\(item.id)|\(item.kind)|\(item.text)")
        }
        for command in commands {
            parts.append(
                [
                    "command",
                    command.id,
                    command.operationID ?? "",
                    command.command,
                    command.cwd ?? "",
                    command.status,
                    command.exitCode.map(String.init) ?? "",
                    command.outputSummary ?? "",
                    timestampFingerprint(command.startedAt),
                    timestampFingerprint(command.completedAt),
                    command.classification.kind,
                    command.classification.ruleVersion,
                    String(command.classification.supported),
                ].joined(separator: "|")
            )
        }
        for artifact in artifacts {
            parts.append(
                [
                    "artifact",
                    artifact.id,
                    artifact.path,
                    artifact.status ?? "",
                    artifact.fileChangeID ?? "",
                    artifact.changeSetID ?? "",
                ].joined(separator: "|")
            )
        }
        for item in decisions {
            parts.append("decision|\(item.id)|\(item.kind)|\(item.text)")
        }
        for validation in validations {
            parts.append(
                [
                    "validation",
                    validation.id,
                    validation.commandID,
                    validation.validationKind,
                    validation.command,
                    validation.cwd ?? "",
                    validation.status,
                    validation.exitCode.map(String.init) ?? "",
                    validation.resultStatus,
                ].joined(separator: "|")
            )
        }
        for item in blockers {
            parts.append("blocker|\(item.id)|\(item.kind)|\(item.text)")
        }
        for item in unresolvedItems {
            parts.append("unresolved|\(item.id)|\(item.kind)|\(item.text)")
        }
        if let boundary = repositoryBoundary {
            parts.append(
                [
                    "boundary",
                    boundary.repositoryID ?? "",
                    boundary.repositoryPath ?? "",
                    boundary.worktreeID ?? "",
                    boundary.worktreePath ?? "",
                    boundary.branch ?? "",
                    boundary.head ?? "",
                    boundary.cwd ?? "",
                ].joined(separator: "|")
            )
        }
        if let resumePoint {
            parts.append("resume|\(resumePoint.id)|\(resumePoint.kind)|\(resumePoint.text)")
        }
        for field in completeness.fields {
            parts.append("availability|\(field.field)|\(field.status)|\(field.reason ?? "")")
        }
        return stableIDFactory.id(
            prefix: "turn-outcome-fingerprint",
            value: parts.joined(separator: "\n")
        )
    }

    private func turnOutcomeEvidenceIndex() throws -> TurnOutcomeEvidenceIndex {
        let count = try turnOutcomeEventCount()
        guard count > 0 else { return TurnOutcomeEvidenceIndex(referencesByKey: [:]) }
        let entries = try eventLedgerEntries(limit: count)
        var referencesByKey: [TurnOutcomeEvidenceKey: [ProvenanceTurnOutcomeEvidenceReference]] = [:]
        for entry in entries {
            func append(kind: String, id: String?) {
                guard let id else { return }
                let key = TurnOutcomeEvidenceKey(kind: kind, id: id)
                referencesByKey[key, default: []].append(
                    ProvenanceTurnOutcomeEvidenceReference(
                        eventID: entry.event.id,
                        eventSequence: entry.sequence,
                        eventType: entry.event.eventType.rawValue,
                        source: entry.event.source,
                        evidenceOrigin: entry.event.evidenceOrigin,
                        evidenceScope: entry.event.evidenceScope,
                        recordKind: kind,
                        recordID: id,
                        interpretedByRuleVersion: Self.turnOutcomeRuleVersion,
                        sourceState: "available"
                    )
                )
            }
            let payload = entry.event.payload
            append(kind: "repository", id: payload.repository?.id)
            append(kind: "worktree", id: payload.worktree?.id)
            append(kind: "session", id: payload.session?.id)
            append(kind: "session_relationship", id: payload.sessionRelationship?.sessionID)
            append(kind: "work_item", id: payload.workItem?.id)
            append(kind: "contribution", id: payload.contribution?.id)
            append(kind: "checkpoint", id: payload.checkpoint?.id)
            append(kind: "change_set", id: payload.changeSet?.id)
            for fileChange in payload.fileChanges {
                append(kind: "file_change", id: fileChange.id)
            }
            append(kind: "validation_run", id: payload.validationRun?.id)
            append(kind: "coding_agent_thread", id: payload.codingAgentThread?.id)
            append(kind: "coding_agent_turn", id: payload.codingAgentTurn?.id)
            append(kind: "coding_agent_prompt", id: payload.codingAgentPrompt?.id)
            append(kind: "coding_agent_plan_update", id: payload.codingAgentPlanUpdate?.id)
            append(kind: "coding_agent_command", id: payload.codingAgentCommand?.id)
            append(kind: "coding_agent_reasoning_summary", id: payload.codingAgentReasoningSummary?.id)
            append(kind: "coding_agent_file_change_attribution", id: payload.codingAgentFileChangeAttribution?.id)
        }
        return TurnOutcomeEvidenceIndex(referencesByKey: referencesByKey)
    }

    private func turnOutcomeEventCount() throws -> Int {
        let query = try database.prepare("SELECT COUNT(*) FROM provenance_events")
        defer { query.finalize() }
        guard try query.step() else { return 0 }
        return query.int(at: 0)
    }

    private func turnOutcomeLatestLedgerSequence() throws -> Int? {
        let query = try database.prepare("SELECT MAX(sequence) FROM provenance_events")
        defer { query.finalize() }
        guard try query.step() else { return nil }
        return query.double(at: 0).map(Int.init)
    }

    private func turnOutcomeEventTimestamp(sequence: Int?) throws -> Date? {
        guard let sequence else { return nil }
        let query = try database.prepare("SELECT timestamp_seconds FROM provenance_events WHERE sequence = ?")
        defer { query.finalize() }
        try query.bind(sequence, at: 1)
        guard try query.step() else { return nil }
        return query.double(at: 0).map { Date(timeIntervalSince1970: $0) }
    }

    private func classifyTurnOutcomeCommand(_ command: String) -> ProvenanceTurnOutcomeCommandClassification {
        let lower = command.lowercased()
        let kind: String
        let supported: Bool
        if lower.contains("swift test")
            || lower.contains("xcodebuild test")
            || lower.contains("yarn test")
            || lower.contains("npm test")
            || lower.contains("npm run test")
            || lower.contains("pytest")
            || lower.contains("rspec")
            || lower.contains("vitest")
            || lower.contains("jest") {
            kind = "test"
            supported = true
        } else if lower.contains("swift build")
            || lower.contains("xcodebuild build")
            || lower.contains("yarn build")
            || lower.contains("npm run build")
            || lower.contains("cargo build") {
            kind = "build"
            supported = true
        } else if lower.contains("lint") || lower.contains("standard") {
            kind = "lint"
            supported = true
        } else if lower.contains("tsc")
            || lower.contains("typecheck")
            || lower.contains("types:check")
            || lower.contains("ts:check") {
            kind = "typecheck"
            supported = true
        } else if lower.contains("format")
            || lower.contains("prettier")
            || lower.contains("swiftformat") {
            kind = "formatter"
            supported = true
        } else if lower.contains("migrate") || lower.contains("db:migrate") {
            kind = "migration"
            supported = true
        } else if lower.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("git ") {
            kind = "git_inspection"
            supported = true
        } else {
            kind = "unsupported"
            supported = false
        }
        return ProvenanceTurnOutcomeCommandClassification(
            kind: kind,
            ruleVersion: Self.turnOutcomeCommandRuleVersion,
            supported: supported
        )
    }

    private func isValidationClassification(_ kind: String) -> Bool {
        ["test", "build", "lint", "typecheck", "formatter", "migration"].contains(kind)
    }

    private func validationResultStatus(status: String, exitCode: Int?) -> String {
        let normalized = status.lowercased()
        if normalized.contains("cancel") {
            return "cancelled"
        }
        if normalized.contains("interrupt") || normalized.contains("incomplete") {
            return "incomplete"
        }
        if let exitCode {
            return exitCode == 0 ? "passed" : "failed"
        }
        if normalized.contains("success") || normalized.contains("succeed") || normalized == "completed" {
            return "passed"
        }
        if normalized.contains("fail") || normalized.contains("error") {
            return "failed"
        }
        return "unknown"
    }

    private func normalizedTurnCompletionState(_ status: String) -> String {
        let normalized = status.lowercased()
        if normalized.contains("cancel") { return "cancelled" }
        if normalized.contains("interrupt") { return "interrupted" }
        if normalized.contains("fail") || normalized.contains("error") { return "failed" }
        if normalized.contains("complete")
            || normalized.contains("success")
            || normalized == "done"
            || normalized == "finished" {
            return "completed"
        }
        if normalized.contains("active")
            || normalized.contains("running")
            || normalized.contains("started")
            || normalized.contains("progress") {
            return "incomplete"
        }
        return "unknown"
    }

    private func isCompletedPlanStatus(_ status: String) -> Bool {
        let normalized = status.lowercased()
        return normalized == "completed"
            || normalized == "complete"
            || normalized == "done"
            || normalized == "succeeded"
            || normalized == "success"
    }

    private func isBlockedPlanStatus(_ status: String) -> Bool {
        let normalized = status.lowercased()
        return normalized == "blocked" || normalized == "blocker"
    }

    private func isActivePlanStatus(_ status: String) -> Bool {
        let normalized = status.lowercased()
        return normalized == "in_progress"
            || normalized == "in progress"
            || normalized == "active"
            || normalized == "running"
    }

    private func isPendingPlanStatus(_ status: String) -> Bool {
        let normalized = status.lowercased()
        return normalized == "pending" || normalized == "todo" || normalized == "deferred"
    }

    private func isExplicitCompletedActionReport(_ text: String) -> Bool {
        let lower = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return lower.hasPrefix("completed ")
            || lower.hasPrefix("implemented ")
            || lower.hasPrefix("added ")
            || lower.hasPrefix("updated ")
            || lower.hasPrefix("fixed ")
            || lower.hasPrefix("created ")
            || lower.hasPrefix("removed ")
            || lower.hasPrefix("ran ")
    }

    private func timestampFingerprint(_ date: Date?) -> String {
        guard let date else { return "" }
        return String(Int64((date.timeIntervalSince1970 * 1_000_000).rounded()))
    }
}

private struct TurnOutcomeEvidenceKey: Hashable {
    let kind: String
    let id: String
}

private struct TurnOutcomeEvidenceIndex {
    private var referencesByKey: [TurnOutcomeEvidenceKey: [ProvenanceTurnOutcomeEvidenceReference]]

    init(referencesByKey: [TurnOutcomeEvidenceKey: [ProvenanceTurnOutcomeEvidenceReference]]) {
        var normalized: [TurnOutcomeEvidenceKey: [ProvenanceTurnOutcomeEvidenceReference]] = [:]
        for (key, references) in referencesByKey {
            let sourceState = references.count > 1 ? "duplicated" : "available"
            normalized[key] = references.map {
                ProvenanceTurnOutcomeEvidenceReference(
                    eventID: $0.eventID,
                    eventSequence: $0.eventSequence,
                    eventType: $0.eventType,
                    source: $0.source,
                    evidenceOrigin: $0.evidenceOrigin,
                    evidenceScope: $0.evidenceScope,
                    recordKind: $0.recordKind,
                    recordID: $0.recordID,
                    interpretedByRuleVersion: $0.interpretedByRuleVersion,
                    sourceState: sourceState
                )
            }
        }
        self.referencesByKey = normalized
    }

    func references(kind: String, id: String?) -> [ProvenanceTurnOutcomeEvidenceReference] {
        guard let id else { return [] }
        return referencesByKey[TurnOutcomeEvidenceKey(kind: kind, id: id)] ?? []
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
