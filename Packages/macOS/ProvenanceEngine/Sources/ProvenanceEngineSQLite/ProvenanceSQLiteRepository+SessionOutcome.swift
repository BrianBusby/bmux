import Foundation
import ProvenanceEngineContracts

extension ProvenanceSQLiteRepository {
    static let sessionOutcomeRuleID = "deterministic_session_outcome"
    static let sessionOutcomeRuleVersion = "1"

    func sessionOutcomeRecord(_ request: ProvenanceSessionOutcomeRequest) throws
        -> ProvenanceSessionOutcomeResponse {
        guard try session(id: request.sessionID) != nil else {
            return ProvenanceSessionOutcomeResponse(
                found: false,
                reason: "no_session",
                sessionID: request.sessionID,
                outcome: nil
            )
        }

        if let revisionID = request.revisionID {
            return try sessionOutcomeRevisionResponse(
                sessionID: request.sessionID,
                revisionID: revisionID
            )
        }

        try projectSessionOutcomeIfNeeded(
            sessionID: request.sessionID,
            latestEventSequence: sessionOutcomeLatestLedgerSequence()
        )

        guard let revisionID = try latestSessionOutcomeRevisionID(sessionID: request.sessionID) else {
            return ProvenanceSessionOutcomeResponse(
                found: false,
                reason: "no_outcome",
                sessionID: request.sessionID,
                outcome: nil
            )
        }
        return try sessionOutcomeRevisionResponse(
            sessionID: request.sessionID,
            revisionID: revisionID
        )
    }

    func refreshSessionOutcomes(
        affectedBy event: ProvenanceEvent,
        latestEventSequence: Int?
    ) throws {
        let sessionIDs = try affectedSessionOutcomeIDs(event: event)
        for sessionID in sessionIDs.sorted() {
            try projectSessionOutcomeIfNeeded(
                sessionID: sessionID,
                latestEventSequence: latestEventSequence
            )
        }
    }

    private func sessionOutcomeRevisionResponse(
        sessionID: String,
        revisionID: String
    ) throws -> ProvenanceSessionOutcomeResponse {
        guard let outcome = try sessionOutcomeRevision(
            sessionID: sessionID,
            revisionID: revisionID
        ) else {
            return ProvenanceSessionOutcomeResponse(
                found: false,
                reason: "no_revision",
                sessionID: sessionID,
                outcome: nil
            )
        }
        return ProvenanceSessionOutcomeResponse(
            found: true,
            reason: nil,
            sessionID: sessionID,
            outcome: outcome
        )
    }

    private func projectSessionOutcomeIfNeeded(
        sessionID: String,
        latestEventSequence: Int?
    ) throws {
        guard let projected = try projectedSessionOutcome(
            sessionID: sessionID,
            latestEventSequence: latestEventSequence
        ) else {
            return
        }
        let outcomeData = try payloadEncoder.encode(projected)
        guard let outcomeJSON = String(data: outcomeData, encoding: .utf8) else {
            throw ProvenanceSQLiteError.sqlite(message: "failed to encode session outcome")
        }
        try insertSessionOutcomeRevision(projected, outcomeJSON: outcomeJSON)
        try upsertLatestSessionOutcome(projected)
    }

    private func insertSessionOutcomeRevision(
        _ outcome: ProvenanceSessionOutcome,
        outcomeJSON: String
    ) throws {
        let insert = try database.prepare(
            """
            INSERT INTO provenance_coding_agent_session_outcome_revisions (
                id,
                session_id,
                projection_rule_id,
                projection_rule_version,
                source_watermark_sequence,
                content_fingerprint,
                outcome_json,
                created_at_seconds
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                source_watermark_sequence = excluded.source_watermark_sequence,
                outcome_json = excluded.outcome_json,
                created_at_seconds = excluded.created_at_seconds
            """
        )
        defer { insert.finalize() }
        try insert.bind(outcome.projection.revisionID, at: 1)
        try insert.bind(outcome.sessionID, at: 2)
        try insert.bind(outcome.projection.projectionRuleID, at: 3)
        try insert.bind(outcome.projection.projectionRuleVersion, at: 4)
        try bindOptionalInt(outcome.projection.sourceEvidenceWatermark, to: insert, at: 5)
        try insert.bind(outcome.projection.contentFingerprint, at: 6)
        try insert.bind(outcomeJSON, at: 7)
        try insert.bind(outcome.projection.generatedAt?.timeIntervalSince1970, at: 8)
        _ = try insert.step()
    }

    private func upsertLatestSessionOutcome(_ outcome: ProvenanceSessionOutcome) throws {
        let upsert = try database.prepare(
            """
            INSERT INTO provenance_coding_agent_session_outcomes (
                session_id,
                latest_revision_id,
                projection_rule_id,
                projection_rule_version,
                latest_evaluated_sequence,
                updated_at_seconds
            ) VALUES (?, ?, ?, ?, ?, ?)
            ON CONFLICT(session_id) DO UPDATE SET
                latest_revision_id = excluded.latest_revision_id,
                projection_rule_id = excluded.projection_rule_id,
                projection_rule_version = excluded.projection_rule_version,
                latest_evaluated_sequence = excluded.latest_evaluated_sequence,
                updated_at_seconds = excluded.updated_at_seconds
            """
        )
        defer { upsert.finalize() }
        try upsert.bind(outcome.sessionID, at: 1)
        try upsert.bind(outcome.projection.revisionID, at: 2)
        try upsert.bind(outcome.projection.projectionRuleID, at: 3)
        try upsert.bind(outcome.projection.projectionRuleVersion, at: 4)
        try bindOptionalInt(outcome.projection.sourceEvidenceWatermark, to: upsert, at: 5)
        try upsert.bind(outcome.projection.generatedAt?.timeIntervalSince1970, at: 6)
        _ = try upsert.step()
    }

    private func projectedSessionOutcome(
        sessionID: String,
        latestEventSequence: Int?
    ) throws -> ProvenanceSessionOutcome? {
        guard let session = try session(id: sessionID) else { return nil }
        let externalIdentities = try externalIdentities(sessionID: sessionID)
        let providerThreads = try codingAgentThreadIDs(sessionID: sessionID)
            .compactMap { try codingAgentThread(id: $0) }
            .map(ProvenanceFactualSessionProjectionProviderThreadIdentity.init(thread:))
        let turnIDs = try sessionOutcomeOrderedTurnIDs(sessionID: sessionID)
        var turnOutcomes: [ProvenanceTurnOutcome] = []
        var missingTurnIDs: [String] = []

        for turnID in turnIDs {
            let response = try turnOutcomeRecord(ProvenanceTurnOutcomeRequest(turnID: turnID))
            if response.found, let outcome = response.outcome {
                turnOutcomes.append(outcome)
            } else {
                missingTurnIDs.append(turnID)
            }
        }

        return try projectedSessionOutcome(
            session: session,
            externalIdentities: externalIdentities,
            providerThreads: providerThreads,
            turnOutcomes: turnOutcomes,
            missingTurnIDs: missingTurnIDs,
            latestEventSequence: latestEventSequence
        )
    }

    private func projectedSessionOutcome(
        session: ProvenanceSessionRecord,
        externalIdentities: [ProvenanceExternalIdentityRecord],
        providerThreads: [ProvenanceFactualSessionProjectionProviderThreadIdentity],
        turnOutcomes: [ProvenanceTurnOutcome],
        missingTurnIDs: [String],
        latestEventSequence: Int?
    ) throws -> ProvenanceSessionOutcome {
        let constituentTurns = try sessionOutcomeTurnReferences(turnOutcomes)
        let objectives = turnOutcomes.compactMap { outcome in
            outcome.objective.map {
                sessionTextFact(source: $0, outcome: outcome, idPrefix: "session-outcome-objective")
            }
        }
        let actionsCompleted = sessionTextFacts(
            turnOutcomes.flatMap { outcome in
                outcome.actionsCompleted.map { (outcome, $0) }
            },
            idPrefix: "session-outcome-action"
        )
        let commandsCompleted = sessionOutcomeCommands(turnOutcomes)
        let changedArtifacts = sessionOutcomeArtifacts(turnOutcomes)
        let decisions = sessionTextFacts(
            turnOutcomes.flatMap { outcome in
                outcome.decisions.map { (outcome, $0) }
            },
            idPrefix: "session-outcome-decision"
        )
        let validationsAttempted = sessionOutcomeValidations(turnOutcomes)
        let blockers = sessionTextFacts(
            turnOutcomes.flatMap { outcome in
                outcome.blockers.map { (outcome, $0) }
            },
            idPrefix: "session-outcome-blocker"
        )
        let unresolvedItems = sessionTextFacts(
            turnOutcomes.flatMap { outcome in
                outcome.unresolvedItems.map { (outcome, $0) }
            },
            idPrefix: "session-outcome-unresolved"
        )
        let resumePoints = sessionTextFacts(
            turnOutcomes.compactMap { outcome in
                outcome.resumePoint.map { (outcome, $0) }
            },
            idPrefix: "session-outcome-resume"
        )
        let repositoryBoundaries = sessionOutcomeRepositoryBoundaries(turnOutcomes)
        let planItems = sessionOutcomePlanItems(turnOutcomes)
        let completionState = normalizedSessionCompletionState(session.status)
        let completeness = sessionOutcomeCompleteness(
            turnOutcomes: turnOutcomes,
            missingTurnIDs: missingTurnIDs,
            externalIdentities: externalIdentities,
            providerThreads: providerThreads,
            objectives: objectives,
            planItems: planItems,
            commands: commandsCompleted,
            changedArtifacts: changedArtifacts,
            decisions: decisions,
            validations: validationsAttempted,
            blockers: blockers,
            unresolvedItems: unresolvedItems,
            repositoryBoundaries: repositoryBoundaries,
            resumePoints: resumePoints,
            completionState: completionState,
            evaluatedThroughSequence: latestEventSequence
        )
        let fingerprint = sessionOutcomeContentFingerprint(
            session: session,
            externalIdentities: externalIdentities,
            providerThreads: providerThreads,
            constituentTurns: constituentTurns,
            objectives: objectives,
            planItems: planItems,
            actionsCompleted: actionsCompleted,
            commands: commandsCompleted,
            changedArtifacts: changedArtifacts,
            decisions: decisions,
            validations: validationsAttempted,
            blockers: blockers,
            unresolvedItems: unresolvedItems,
            repositoryBoundaries: repositoryBoundaries,
            resumePoints: resumePoints,
            lifecycleState: session.status,
            completionState: completionState,
            completeness: completeness
        )
        let revisionID = stableIDFactory.id(
            prefix: "session-outcome-revision",
            value: [
                session.id,
                Self.sessionOutcomeRuleID,
                Self.sessionOutcomeRuleVersion,
                fingerprint,
            ].joined(separator: "\n")
        )
        let generatedAt = try sessionOutcomeEventTimestamp(sequence: latestEventSequence)
            ?? session.updatedAt
        let projection = ProvenanceSessionOutcomeProjectionMetadata(
            revisionID: revisionID,
            projectionRuleID: Self.sessionOutcomeRuleID,
            projectionRuleVersion: Self.sessionOutcomeRuleVersion,
            contentFingerprint: fingerprint,
            sourceEvidenceWatermark: latestEventSequence,
            generatedAt: generatedAt
        )
        return ProvenanceSessionOutcome(
            sessionID: session.id,
            session: session,
            externalIdentities: externalIdentities,
            providerThreadIdentities: providerThreads,
            projection: projection,
            constituentTurns: constituentTurns,
            turnOutcomes: turnOutcomes,
            objectives: objectives,
            planItems: planItems,
            actionsCompleted: actionsCompleted,
            commandsCompleted: commandsCompleted,
            changedArtifacts: changedArtifacts,
            decisions: decisions,
            validationsAttempted: validationsAttempted,
            blockers: blockers,
            unresolvedItems: unresolvedItems,
            repositoryBoundaries: repositoryBoundaries,
            resumePoints: resumePoints,
            latestResumePoint: resumePoints.last,
            lifecycleState: session.status,
            completionState: completionState,
            completeness: completeness
        )
    }

    private func sessionOutcomeOrderedTurnIDs(sessionID: String) throws -> [String] {
        let turns = try codingAgentTurnIDs(sessionID: sessionID, limit: nil)
            .compactMap { try codingAgentTurn(id: $0) }
        return turns.sorted { lhs, rhs in
            let lhsStarted = (lhs.startedAt ?? lhs.updatedAt).timeIntervalSince1970
            let rhsStarted = (rhs.startedAt ?? rhs.updatedAt).timeIntervalSince1970
            if lhsStarted != rhsStarted { return lhsStarted < rhsStarted }

            let lhsCompleted = lhs.completedAt?.timeIntervalSince1970 ?? Double.greatestFiniteMagnitude
            let rhsCompleted = rhs.completedAt?.timeIntervalSince1970 ?? Double.greatestFiniteMagnitude
            if lhsCompleted != rhsCompleted { return lhsCompleted < rhsCompleted }

            let lhsUpdated = lhs.updatedAt.timeIntervalSince1970
            let rhsUpdated = rhs.updatedAt.timeIntervalSince1970
            if lhsUpdated != rhsUpdated { return lhsUpdated < rhsUpdated }

            return lhs.id < rhs.id
        }.map(\.id)
    }

    private func sessionOutcomeTurnReferences(
        _ turnOutcomes: [ProvenanceTurnOutcome]
    ) throws -> [ProvenanceSessionOutcomeTurnReference] {
        try turnOutcomes.enumerated().map { index, outcome in
            let turn = try codingAgentTurn(id: outcome.turnID)
            return ProvenanceSessionOutcomeTurnReference(
                order: index,
                turnID: outcome.turnID,
                provider: outcome.provider,
                providerTurnID: outcome.providerTurnID,
                turnOutcomeRevisionID: outcome.projection.revisionID,
                turnOutcomeContentFingerprint: outcome.projection.contentFingerprint,
                sourceEvidenceWatermark: outcome.projection.sourceEvidenceWatermark,
                lifecycleState: outcome.lifecycleState,
                completionState: outcome.completionState,
                startedAt: turn?.startedAt,
                completedAt: turn?.completedAt
            )
        }
    }

    private func sessionTextFacts(
        _ sources: [(ProvenanceTurnOutcome, ProvenanceTurnOutcomeTextFact)],
        idPrefix: String
    ) -> [ProvenanceSessionOutcomeTextFact] {
        sources.map { outcome, fact in
            sessionTextFact(source: fact, outcome: outcome, idPrefix: idPrefix)
        }
    }

    private func sessionTextFact(
        source fact: ProvenanceTurnOutcomeTextFact,
        outcome: ProvenanceTurnOutcome,
        idPrefix: String
    ) -> ProvenanceSessionOutcomeTextFact {
        let id = stableIDFactory.id(
            prefix: idPrefix,
            value: [
                outcome.sessionID,
                outcome.turnID,
                fact.id,
                fact.kind,
                fact.text,
            ].joined(separator: "\n")
        )
        return ProvenanceSessionOutcomeTextFact(
            id: id,
            kind: fact.kind,
            text: fact.text,
            sourceTurnID: outcome.turnID,
            sourceTurnOutcomeRevisionID: outcome.projection.revisionID,
            evidence: fact.evidence
        )
    }

    private func sessionOutcomeCommands(
        _ turnOutcomes: [ProvenanceTurnOutcome]
    ) -> [ProvenanceSessionOutcomeCommand] {
        turnOutcomes.flatMap { outcome in
            outcome.commandsCompleted.map { command in
                ProvenanceSessionOutcomeCommand(
                    id: stableIDFactory.id(
                        prefix: "session-outcome-command",
                        value: "\(outcome.sessionID)\n\(outcome.turnID)\n\(command.id)"
                    ),
                    sourceTurnID: outcome.turnID,
                    sourceTurnOutcomeRevisionID: outcome.projection.revisionID,
                    command: command
                )
            }
        }
    }

    private func sessionOutcomeArtifacts(
        _ turnOutcomes: [ProvenanceTurnOutcome]
    ) -> [ProvenanceSessionOutcomeArtifact] {
        turnOutcomes.flatMap { outcome in
            turnOutcomeArtifactFacts(outcome).map { item in
                ProvenanceSessionOutcomeArtifact(
                    id: stableIDFactory.id(
                        prefix: "session-outcome-artifact",
                        value: "\(outcome.sessionID)\n\(outcome.turnID)\n\(item.id)"
                    ),
                    sourceTurnID: outcome.turnID,
                    sourceTurnOutcomeRevisionID: outcome.projection.revisionID,
                    artifact: item
                )
            }
        }
    }

    private func turnOutcomeArtifactFacts(
        _ outcome: ProvenanceTurnOutcome
    ) -> [ProvenanceTurnOutcomeArtifact] {
        let artifactKey = ["artifacts", "Changed"].joined()
        guard let data = try? payloadEncoder.encode(outcome),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rawFacts = object[artifactKey],
              JSONSerialization.isValidJSONObject(rawFacts),
              let factData = try? JSONSerialization.data(withJSONObject: rawFacts) else {
            return []
        }
        return (try? payloadDecoder.decode([ProvenanceTurnOutcomeArtifact].self, from: factData)) ?? []
    }

    private func sessionOutcomeValidations(
        _ turnOutcomes: [ProvenanceTurnOutcome]
    ) -> [ProvenanceSessionOutcomeValidation] {
        turnOutcomes.flatMap { outcome in
            outcome.validationsAttempted.map { validation in
                ProvenanceSessionOutcomeValidation(
                    id: stableIDFactory.id(
                        prefix: "session-outcome-validation",
                        value: "\(outcome.sessionID)\n\(outcome.turnID)\n\(validation.id)"
                    ),
                    sourceTurnID: outcome.turnID,
                    sourceTurnOutcomeRevisionID: outcome.projection.revisionID,
                    validation: validation
                )
            }
        }
    }

    private func sessionOutcomePlanItems(
        _ turnOutcomes: [ProvenanceTurnOutcome]
    ) -> [ProvenanceSessionOutcomePlanItem] {
        var orderedKeys: [String] = []
        var accumulators: [String: SessionOutcomePlanAccumulator] = [:]
        for outcome in turnOutcomes {
            for item in outcome.planItems {
                guard let normalized = normalizedPlanText(item.text) else { continue }
                if accumulators[normalized] == nil {
                    orderedKeys.append(normalized)
                    accumulators[normalized] = SessionOutcomePlanAccumulator(
                        firstText: item.text,
                        firstTurnID: outcome.turnID
                    )
                }
                accumulators[normalized]?.append(item, from: outcome)
            }
        }
        return orderedKeys.compactMap { key in
            guard let accumulator = accumulators[key] else { return nil }
            return accumulator.planItem(
                id: stableIDFactory.id(
                    prefix: "session-outcome-plan-item",
                    value: "\(turnOutcomes.first?.sessionID ?? "")\n\(key)"
                )
            )
        }
    }

    private func sessionOutcomeRepositoryBoundaries(
        _ turnOutcomes: [ProvenanceTurnOutcome]
    ) -> [ProvenanceSessionOutcomeRepositoryBoundary] {
        var orderedKeys: [SessionOutcomeBoundaryKey] = []
        var accumulators: [SessionOutcomeBoundaryKey: SessionOutcomeBoundaryAccumulator] = [:]
        for outcome in turnOutcomes {
            guard let boundary = outcome.repositoryBoundary else { continue }
            let key = SessionOutcomeBoundaryKey(boundary: boundary)
            if accumulators[key] == nil {
                orderedKeys.append(key)
                accumulators[key] = SessionOutcomeBoundaryAccumulator(boundary: boundary)
            }
            accumulators[key]?.append(boundary, from: outcome)
        }
        return orderedKeys.compactMap { key in
            accumulators[key]?.boundaryFact(
                id: stableIDFactory.id(
                    prefix: "session-outcome-boundary",
                    value: key.fingerprintValue
                )
            )
        }
    }

    private func sessionOutcomeCompleteness(
        turnOutcomes: [ProvenanceTurnOutcome],
        missingTurnIDs: [String],
        externalIdentities: [ProvenanceExternalIdentityRecord],
        providerThreads: [ProvenanceFactualSessionProjectionProviderThreadIdentity],
        objectives: [ProvenanceSessionOutcomeTextFact],
        planItems: [ProvenanceSessionOutcomePlanItem],
        commands: [ProvenanceSessionOutcomeCommand],
        changedArtifacts: [ProvenanceSessionOutcomeArtifact],
        decisions: [ProvenanceSessionOutcomeTextFact],
        validations: [ProvenanceSessionOutcomeValidation],
        blockers: [ProvenanceSessionOutcomeTextFact],
        unresolvedItems: [ProvenanceSessionOutcomeTextFact],
        repositoryBoundaries: [ProvenanceSessionOutcomeRepositoryBoundary],
        resumePoints: [ProvenanceSessionOutcomeTextFact],
        completionState: String,
        evaluatedThroughSequence: Int?
    ) -> ProvenanceSessionOutcomeCompleteness {
        var fields: [ProvenanceSessionOutcomeAvailability] = []
        fields.append(turnAvailability(turnOutcomes: turnOutcomes, missingTurnIDs: missingTurnIDs))
        fields.append(availability(field: "external_identities", observed: !externalIdentities.isEmpty, reason: "no_external_identity"))
        fields.append(availability(field: "provider_thread_identities", observed: !providerThreads.isEmpty, reason: "no_provider_thread"))
        fields.append(availability(field: "objectives", observed: !objectives.isEmpty, reason: "no_submitted_prompt", evidence: objectives.flatMap(\.evidence)))
        fields.append(availability(field: "plan_items", observed: !planItems.isEmpty, reason: "no_plan_update", evidence: planItems.flatMap(\.evidence)))
        fields.append(availability(field: "completed_commands", observed: !commands.isEmpty, reason: "no_completed_command", evidence: commands.flatMap { $0.command.evidence }))
        fields.append(availability(field: "changed_artifacts", observed: !changedArtifacts.isEmpty, reason: "no_file_change_attribution", evidence: changedArtifacts.flatMap { $0.artifact.evidence }))
        fields.append(availability(field: "decisions", observed: !decisions.isEmpty, reason: "no_explicit_decision_evidence", evidence: decisions.flatMap(\.evidence)))
        fields.append(availability(field: "validations_attempted", observed: !validations.isEmpty, reason: "no_supported_validation_command", evidence: validations.flatMap { $0.validation.evidence }))
        fields.append(availability(field: "blockers", observed: !blockers.isEmpty, reason: "no_blocked_plan_item", evidence: blockers.flatMap(\.evidence)))
        fields.append(availability(field: "unresolved_items", observed: !unresolvedItems.isEmpty, reason: "no_unresolved_plan_item", evidence: unresolvedItems.flatMap(\.evidence)))
        fields.append(repositoryBoundaryAvailability(repositoryBoundaries))
        fields.append(availability(field: "resume_points", observed: !resumePoints.isEmpty, reason: "no_active_or_pending_plan_item", evidence: resumePoints.flatMap(\.evidence)))
        fields.append(availability(field: "completion_state", observed: completionState != "unknown", reason: "unknown_session_status"))
        let status = fields.allSatisfy { $0.status == "observed" } ? "complete" : "partial"
        return ProvenanceSessionOutcomeCompleteness(
            status: status,
            evaluatedThroughSequence: evaluatedThroughSequence,
            fields: fields,
            notes: [
                "session outcome aggregates deterministic turn outcome revisions and does not infer intent beyond accepted turn facts",
                "plan items reconcile by normalized text with latest factual state winning",
                "multiple repository or worktree boundaries are preserved as separate facts",
                "validation attempts do not prove the entire session change is valid",
            ]
        )
    }

    private func turnAvailability(
        turnOutcomes: [ProvenanceTurnOutcome],
        missingTurnIDs: [String]
    ) -> ProvenanceSessionOutcomeAvailability {
        if !missingTurnIDs.isEmpty {
            return ProvenanceSessionOutcomeAvailability(
                field: "constituent_turns",
                status: "partial",
                reason: "missing_turn_outcome_revisions",
                evidence: turnOutcomes.flatMap { $0.completeness.fields.flatMap(\.evidence) }
            )
        }
        return availability(
            field: "constituent_turns",
            observed: !turnOutcomes.isEmpty,
            reason: "no_turn_outcomes",
            evidence: turnOutcomes.flatMap { $0.completeness.fields.flatMap(\.evidence) }
        )
    }

    private func repositoryBoundaryAvailability(
        _ boundaries: [ProvenanceSessionOutcomeRepositoryBoundary]
    ) -> ProvenanceSessionOutcomeAvailability {
        guard !boundaries.isEmpty else {
            return availability(
                field: "repository_boundaries",
                observed: false,
                reason: "no_repository_or_worktree_boundary"
            )
        }
        return ProvenanceSessionOutcomeAvailability(
            field: "repository_boundaries",
            status: boundaries.count == 1 ? "observed" : "partial",
            reason: boundaries.count == 1 ? nil : "multiple_repository_boundaries",
            evidence: boundaries.flatMap(\.evidence)
        )
    }

    private func availability(
        field: String,
        observed: Bool,
        reason: String,
        evidence: [ProvenanceTurnOutcomeEvidenceReference] = []
    ) -> ProvenanceSessionOutcomeAvailability {
        ProvenanceSessionOutcomeAvailability(
            field: field,
            status: observed ? "observed" : "not_observed",
            reason: observed ? nil : reason,
            evidence: evidence
        )
    }

    private func sessionOutcomeContentFingerprint(
        session: ProvenanceSessionRecord,
        externalIdentities: [ProvenanceExternalIdentityRecord],
        providerThreads: [ProvenanceFactualSessionProjectionProviderThreadIdentity],
        constituentTurns: [ProvenanceSessionOutcomeTurnReference],
        objectives: [ProvenanceSessionOutcomeTextFact],
        planItems: [ProvenanceSessionOutcomePlanItem],
        actionsCompleted: [ProvenanceSessionOutcomeTextFact],
        commands: [ProvenanceSessionOutcomeCommand],
        changedArtifacts: [ProvenanceSessionOutcomeArtifact],
        decisions: [ProvenanceSessionOutcomeTextFact],
        validations: [ProvenanceSessionOutcomeValidation],
        blockers: [ProvenanceSessionOutcomeTextFact],
        unresolvedItems: [ProvenanceSessionOutcomeTextFact],
        repositoryBoundaries: [ProvenanceSessionOutcomeRepositoryBoundary],
        resumePoints: [ProvenanceSessionOutcomeTextFact],
        lifecycleState: String,
        completionState: String,
        completeness: ProvenanceSessionOutcomeCompleteness
    ) -> String {
        var parts = [
            "schema=1",
            "session=\(session.id)",
            "agent=\(session.agentKind)",
            "workspace=\(session.workspaceID ?? "")",
            "surface=\(session.surfaceID ?? "")",
            "worktree=\(session.worktreeID ?? "")",
            "cwd=\(session.cwd ?? "")",
            "lifecycle=\(lifecycleState)",
            "completion=\(completionState)",
        ]
        for identity in externalIdentities {
            parts.append(
                "identity|\(identity.system)|\(identity.kind)|\(identity.externalID)|\(identity.source.rawValue)|\(identity.confidence.rawValue)"
            )
        }
        for thread in providerThreads {
            parts.append(
                "thread|\(thread.threadID)|\(thread.provider)|\(thread.providerThreadID)|\(thread.worktreeID ?? "")|\(thread.source.rawValue)|\(thread.confidence.rawValue)"
            )
        }
        for turn in constituentTurns {
            parts.append(
                [
                    "turn",
                    String(turn.order),
                    turn.turnID,
                    turn.provider,
                    turn.providerTurnID,
                    turn.turnOutcomeRevisionID,
                    turn.turnOutcomeContentFingerprint,
                    turn.lifecycleState,
                    turn.completionState,
                ].joined(separator: "|")
            )
        }
        for item in objectives {
            parts.append("objective|\(item.id)|\(item.kind)|\(item.text)|\(item.sourceTurnOutcomeRevisionID)")
        }
        for item in planItems {
            parts.append(
                [
                    "plan",
                    item.id,
                    item.text,
                    item.status,
                    item.firstObservedTurnID,
                    item.latestObservedTurnID,
                    item.latestTurnOutcomeRevisionID,
                    item.sourcePlanItemIDs.joined(separator: ","),
                ].joined(separator: "|")
            )
        }
        for item in actionsCompleted {
            parts.append("action|\(item.id)|\(item.kind)|\(item.text)|\(item.sourceTurnOutcomeRevisionID)")
        }
        for item in commands {
            parts.append(
                [
                    "command",
                    item.id,
                    item.sourceTurnOutcomeRevisionID,
                    item.command.id,
                    item.command.operationID ?? "",
                    item.command.command,
                    item.command.cwd ?? "",
                    item.command.status,
                    item.command.exitCode.map(String.init) ?? "",
                    item.command.outputSummary ?? "",
                    timestampFingerprint(item.command.startedAt),
                    timestampFingerprint(item.command.completedAt),
                    item.command.classification.kind,
                    item.command.classification.ruleVersion,
                    String(item.command.classification.supported),
                ].joined(separator: "|")
            )
        }
        for item in changedArtifacts {
            parts.append(
                [
                    "changed-artifact",
                    item.id,
                    item.sourceTurnOutcomeRevisionID,
                    item.artifact.id,
                    item.artifact.path,
                    item.artifact.status ?? "",
                    item.artifact.fileChangeID ?? "",
                    item.artifact.changeSetID ?? "",
                ].joined(separator: "|")
            )
        }
        for item in decisions {
            parts.append("decision|\(item.id)|\(item.kind)|\(item.text)|\(item.sourceTurnOutcomeRevisionID)")
        }
        for item in validations {
            parts.append(
                [
                    "validation",
                    item.id,
                    item.sourceTurnOutcomeRevisionID,
                    item.validation.id,
                    item.validation.commandID,
                    item.validation.validationKind,
                    item.validation.command,
                    item.validation.cwd ?? "",
                    item.validation.status,
                    item.validation.exitCode.map(String.init) ?? "",
                    item.validation.resultStatus,
                ].joined(separator: "|")
            )
        }
        for item in blockers {
            parts.append("blocker|\(item.id)|\(item.kind)|\(item.text)|\(item.sourceTurnOutcomeRevisionID)")
        }
        for item in unresolvedItems {
            parts.append("unresolved|\(item.id)|\(item.kind)|\(item.text)|\(item.sourceTurnOutcomeRevisionID)")
        }
        for boundary in repositoryBoundaries {
            parts.append(
                [
                    "boundary",
                    boundary.id,
                    boundary.repositoryID ?? "",
                    boundary.repositoryPath ?? "",
                    boundary.worktreeID ?? "",
                    boundary.worktreePath ?? "",
                    boundary.branch ?? "",
                    boundary.head ?? "",
                    boundary.cwd ?? "",
                    boundary.turnIDs.joined(separator: ","),
                    boundary.turnOutcomeRevisionIDs.joined(separator: ","),
                ].joined(separator: "|")
            )
        }
        for item in resumePoints {
            parts.append("resume|\(item.id)|\(item.kind)|\(item.text)|\(item.sourceTurnOutcomeRevisionID)")
        }
        for field in completeness.fields {
            parts.append("availability|\(field.field)|\(field.status)|\(field.reason ?? "")")
        }
        return stableIDFactory.id(
            prefix: "session-outcome-fingerprint",
            value: parts.joined(separator: "\n")
        )
    }

    private func sessionOutcomeRevision(
        sessionID: String,
        revisionID: String
    ) throws -> ProvenanceSessionOutcome? {
        let query = try database.prepare(
            """
            SELECT outcome_json
            FROM provenance_coding_agent_session_outcome_revisions
            WHERE session_id = ?
              AND id = ?
            """
        )
        defer { query.finalize() }
        try query.bind(sessionID, at: 1)
        try query.bind(revisionID, at: 2)
        guard try query.step(),
              let json = query.string(at: 0),
              let data = json.data(using: .utf8) else {
            return nil
        }
        return try payloadDecoder.decode(ProvenanceSessionOutcome.self, from: data)
    }

    private func latestSessionOutcomeRevisionID(sessionID: String) throws -> String? {
        let query = try database.prepare(
            """
            SELECT latest_revision_id
            FROM provenance_coding_agent_session_outcomes
            WHERE session_id = ?
            """
        )
        defer { query.finalize() }
        try query.bind(sessionID, at: 1)
        guard try query.step() else { return nil }
        return query.string(at: 0)
    }

    private func sessionOutcomeLatestLedgerSequence() throws -> Int? {
        let query = try database.prepare("SELECT MAX(sequence) FROM provenance_events")
        defer { query.finalize() }
        guard try query.step() else { return nil }
        return query.double(at: 0).map(Int.init)
    }

    private func sessionOutcomeEventTimestamp(sequence: Int?) throws -> Date? {
        guard let sequence else { return nil }
        let query = try database.prepare("SELECT timestamp_seconds FROM provenance_events WHERE sequence = ?")
        defer { query.finalize() }
        try query.bind(sequence, at: 1)
        guard try query.step() else { return nil }
        return query.double(at: 0).map { Date(timeIntervalSince1970: $0) }
    }

    private func bindOptionalInt(
        _ value: Int?,
        to statement: ProvenanceSQLiteStatement,
        at index: Int32
    ) throws {
        if let value {
            try statement.bind(value, at: index)
        } else {
            try statement.bind(nil as Double?, at: index)
        }
    }

    private func affectedSessionOutcomeIDs(event: ProvenanceEvent) throws -> Set<String> {
        let payload = event.payload
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
            sessionIDs.insert(turn.sessionID)
        }
        if let prompt = payload.codingAgentPrompt {
            sessionIDs.insert(prompt.sessionID)
        }
        if let plan = payload.codingAgentPlanUpdate {
            sessionIDs.insert(plan.sessionID)
        }
        if let command = payload.codingAgentCommand {
            sessionIDs.insert(command.sessionID)
        }
        if let summary = payload.codingAgentReasoningSummary {
            sessionIDs.insert(summary.sessionID)
        }
        if let message = payload.codingAgentAssistantMessage {
            sessionIDs.insert(message.sessionID)
        }
        if let attribution = payload.codingAgentFileChangeAttribution {
            sessionIDs.insert(attribution.sessionID)
        }
        if let worktree = payload.worktree {
            sessionIDs.formUnion(try sessionOutcomeSessionIDs(worktreeID: worktree.id))
        }
        if let repository = payload.repository {
            sessionIDs.formUnion(try sessionOutcomeSessionIDs(repositoryID: repository.id))
        }
        if let changeSet = payload.changeSet {
            sessionIDs.formUnion(try sessionOutcomeSessionIDs(changeSetID: changeSet.id))
        }
        for fileChange in payload.fileChanges {
            sessionIDs.formUnion(try sessionOutcomeSessionIDs(fileChangeID: fileChange.id))
            sessionIDs.formUnion(try sessionOutcomeSessionIDs(worktreeID: fileChange.worktreeID))
        }
        return sessionIDs
    }

    private func sessionOutcomeSessionIDs(worktreeID: String) throws -> [String] {
        let query = try database.prepare(
            """
            SELECT DISTINCT sessions.id
            FROM provenance_sessions AS sessions
            LEFT JOIN provenance_coding_agent_threads AS threads
              ON threads.session_id = sessions.id
            WHERE sessions.worktree_id = ?
               OR threads.worktree_id = ?
            ORDER BY sessions.id ASC
            """
        )
        defer { query.finalize() }
        try query.bind(worktreeID, at: 1)
        try query.bind(worktreeID, at: 2)
        return try sessionOutcomeStringIDs(from: query)
    }

    private func sessionOutcomeSessionIDs(repositoryID: String) throws -> [String] {
        let query = try database.prepare(
            """
            SELECT DISTINCT sessions.id
            FROM provenance_sessions AS sessions
            LEFT JOIN provenance_worktrees AS session_worktree
              ON session_worktree.id = sessions.worktree_id
            LEFT JOIN provenance_coding_agent_threads AS threads
              ON threads.session_id = sessions.id
            LEFT JOIN provenance_worktrees AS thread_worktree
              ON thread_worktree.id = threads.worktree_id
            WHERE session_worktree.repository_id = ?
               OR thread_worktree.repository_id = ?
            ORDER BY sessions.id ASC
            """
        )
        defer { query.finalize() }
        try query.bind(repositoryID, at: 1)
        try query.bind(repositoryID, at: 2)
        return try sessionOutcomeStringIDs(from: query)
    }

    private func sessionOutcomeSessionIDs(changeSetID: String) throws -> [String] {
        let query = try database.prepare(
            """
            SELECT DISTINCT session_id
            FROM provenance_coding_agent_file_change_attributions
            WHERE change_set_id = ?
            ORDER BY session_id ASC
            """
        )
        defer { query.finalize() }
        try query.bind(changeSetID, at: 1)
        return try sessionOutcomeStringIDs(from: query)
    }

    private func sessionOutcomeSessionIDs(fileChangeID: String) throws -> [String] {
        let query = try database.prepare(
            """
            SELECT DISTINCT session_id
            FROM provenance_coding_agent_file_change_attributions
            WHERE file_change_ids_json LIKE ?
            ORDER BY session_id ASC
            """
        )
        defer { query.finalize() }
        try query.bind("%\"\(fileChangeID)\"%", at: 1)
        return try sessionOutcomeStringIDs(from: query)
    }

    private func sessionOutcomeStringIDs(from query: ProvenanceSQLiteStatement) throws -> [String] {
        var ids: [String] = []
        while try query.step() {
            if let id = query.string(at: 0) {
                ids.append(id)
            }
        }
        return ids
    }

    private func normalizedSessionCompletionState(_ status: String) -> String {
        let normalized = status.lowercased()
        if normalized.contains("cancel") { return "cancelled" }
        if normalized.contains("interrupt") { return "interrupted" }
        if normalized.contains("fail") || normalized.contains("error") { return "failed" }
        if normalized.contains("complete")
            || normalized.contains("success")
            || normalized == "done"
            || normalized == "finished"
            || normalized == "stopped"
            || normalized == "closed" {
            return "completed"
        }
        if normalized.contains("active")
            || normalized.contains("running")
            || normalized.contains("started")
            || normalized.contains("progress")
            || normalized.contains("incomplete") {
            return "incomplete"
        }
        return "unknown"
    }

    private func normalizedPlanText(_ text: String) -> String? {
        let normalized = text
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return normalized.isEmpty ? nil : normalized
    }

    private func timestampFingerprint(_ date: Date?) -> String {
        guard let date else { return "" }
        return String(Int64((date.timeIntervalSince1970 * 1_000_000).rounded()))
    }
}

private struct SessionOutcomePlanAccumulator {
    let firstText: String
    let firstTurnID: String
    private var latestText: String
    private var latestStatus: String
    private var latestTurnID: String
    private var latestRevisionID: String
    private var sourcePlanItemIDs: [String]
    private var latestEvidence: [ProvenanceTurnOutcomeEvidenceReference]

    init(firstText: String, firstTurnID: String) {
        self.firstText = firstText
        self.firstTurnID = firstTurnID
        self.latestText = firstText
        self.latestStatus = "unknown"
        self.latestTurnID = firstTurnID
        self.latestRevisionID = ""
        self.sourcePlanItemIDs = []
        self.latestEvidence = []
    }

    mutating func append(_ item: ProvenanceTurnOutcomePlanItem, from outcome: ProvenanceTurnOutcome) {
        latestText = item.text
        latestStatus = item.status
        latestTurnID = outcome.turnID
        latestRevisionID = outcome.projection.revisionID
        let scopedID = "\(outcome.turnID):\(item.id)"
        if !sourcePlanItemIDs.contains(scopedID) {
            sourcePlanItemIDs.append(scopedID)
        }
        latestEvidence = item.evidence
    }

    func planItem(id: String) -> ProvenanceSessionOutcomePlanItem {
        ProvenanceSessionOutcomePlanItem(
            id: id,
            text: latestText,
            status: latestStatus,
            firstObservedTurnID: firstTurnID,
            latestObservedTurnID: latestTurnID,
            latestTurnOutcomeRevisionID: latestRevisionID,
            sourcePlanItemIDs: sourcePlanItemIDs,
            evidence: latestEvidence
        )
    }
}

private struct SessionOutcomeBoundaryKey: Hashable {
    let repositoryID: String?
    let repositoryPath: String?
    let worktreeID: String?
    let worktreePath: String?
    let branch: String?
    let head: String?
    let cwd: String?

    init(boundary: ProvenanceTurnOutcomeRepositoryBoundary) {
        self.repositoryID = boundary.repositoryID
        self.repositoryPath = boundary.repositoryPath
        self.worktreeID = boundary.worktreeID
        self.worktreePath = boundary.worktreePath
        self.branch = boundary.branch
        self.head = boundary.head
        self.cwd = boundary.cwd
    }

    var fingerprintValue: String {
        [
            repositoryID ?? "",
            repositoryPath ?? "",
            worktreeID ?? "",
            worktreePath ?? "",
            branch ?? "",
            head ?? "",
            cwd ?? "",
        ].joined(separator: "\n")
    }
}

private struct SessionOutcomeBoundaryAccumulator {
    let key: SessionOutcomeBoundaryKey
    private var turnIDs: [String]
    private var revisionIDs: [String]
    private var evidence: [ProvenanceTurnOutcomeEvidenceReference]

    init(boundary: ProvenanceTurnOutcomeRepositoryBoundary) {
        self.key = SessionOutcomeBoundaryKey(boundary: boundary)
        self.turnIDs = []
        self.revisionIDs = []
        self.evidence = []
    }

    mutating func append(_ boundary: ProvenanceTurnOutcomeRepositoryBoundary, from outcome: ProvenanceTurnOutcome) {
        if !turnIDs.contains(outcome.turnID) {
            turnIDs.append(outcome.turnID)
        }
        let revisionID = outcome.projection.revisionID
        if !revisionIDs.contains(revisionID) {
            revisionIDs.append(revisionID)
        }
        evidence = deduplicated(evidence + boundary.evidence)
    }

    func boundaryFact(id: String) -> ProvenanceSessionOutcomeRepositoryBoundary {
        ProvenanceSessionOutcomeRepositoryBoundary(
            id: id,
            repositoryID: key.repositoryID,
            repositoryPath: key.repositoryPath,
            worktreeID: key.worktreeID,
            worktreePath: key.worktreePath,
            branch: key.branch,
            head: key.head,
            cwd: key.cwd,
            turnIDs: turnIDs,
            turnOutcomeRevisionIDs: revisionIDs,
            evidence: evidence
        )
    }
}

private func deduplicated(
    _ references: [ProvenanceTurnOutcomeEvidenceReference]
) -> [ProvenanceTurnOutcomeEvidenceReference] {
    var seen = Set<String>()
    var result: [ProvenanceTurnOutcomeEvidenceReference] = []
    for reference in references {
        let key = [
            reference.eventID,
            String(reference.eventSequence),
            reference.recordKind,
            reference.recordID,
            reference.interpretedByRuleVersion,
        ].joined(separator: "\u{0}")
        guard !seen.contains(key) else { continue }
        seen.insert(key)
        result.append(reference)
    }
    return result
}
