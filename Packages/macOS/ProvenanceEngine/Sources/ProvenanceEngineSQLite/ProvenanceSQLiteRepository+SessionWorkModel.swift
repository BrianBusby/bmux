import Foundation
import ProvenanceEngineContracts

extension ProvenanceSQLiteRepository {
    func sessionWorkModelSnapshot(_ request: ProvenanceSessionWorkModelRequest) throws
        -> ProvenanceSessionWorkModelResponse {
        let factualResponse = try factualSessionProjection(
            ProvenanceFactualSessionProjectionRequest(
                sessionID: request.sessionID,
                turnLimit: request.turnLimit
            )
        )
        guard factualResponse.found, let factualProjection = factualResponse.snapshot else {
            return ProvenanceSessionWorkModelResponse(
                found: false,
                reason: factualResponse.reason ?? "no_session",
                sessionID: request.sessionID,
                model: nil
            )
        }

        let latestTurnSnapshot = factualProjection.latestTurn
        let selectedThreadIdentity = Self.selectedThreadIdentity(
            from: factualProjection,
            latestTurn: latestTurnSnapshot?.turn
        )
        let semanticRecords = try activeSemanticRecords(
            sessionID: factualProjection.session.id,
            threadID: selectedThreadIdentity?.threadID,
            turnID: latestTurnSnapshot?.turn.id
        )
        let semanticRecordByField = Dictionary(
            uniqueKeysWithValues: semanticRecords.map { record in
                (SemanticFieldKey(kind: record.kind, scope: record.scope, scopeID: record.scopeID), record)
            }
        )

        let thread = selectedThreadIdentity.map { identity in
            ProvenanceSessionWorkModelThread(
                identity: identity,
                intent: semanticField(
                    kind: ProvenanceCodingAgentSemanticInferenceKind.threadIntent.rawValue,
                    scope: .thread,
                    scopeID: identity.threadID,
                    records: semanticRecordByField
                )
            )
        }
        let currentTurn = latestTurnSnapshot.map { turnSnapshot in
            ProvenanceSessionWorkModelCurrentTurn(
                turn: turnSnapshot.turn,
                prompt: turnSnapshot.submittedPrompt,
                plan: turnSnapshot.currentPlan,
                completedCommands: turnSnapshot.completedCommands,
                visibleReasoningSummaries: turnSnapshot.visibleReasoningSummaries,
                fileChangeAttributions: turnSnapshot.fileChangeAttributions,
                intent: semanticField(
                    kind: ProvenanceCodingAgentSemanticInferenceKind.turnIntent.rawValue,
                    scope: .turn,
                    scopeID: turnSnapshot.turn.id,
                    records: semanticRecordByField
                ),
                currentActivity: semanticField(
                    kind: ProvenanceCodingAgentSemanticInferenceKind.currentActivity.rawValue,
                    scope: .turn,
                    scopeID: turnSnapshot.turn.id,
                    records: semanticRecordByField
                ),
                assistantMessages: turnSnapshot.assistantMessages
            )
        }
        let revision = ProvenanceSessionWorkModelRevision(
            schemaVersion: 3,
            factualRevision: factualProjection.revision,
            semanticInferenceIDs: semanticRecords.map(\.id),
            latestSemanticInferenceCreatedAt: semanticRecords.map(\.createdAt).max()
        )
        let model = ProvenanceSessionWorkModel(
            revision: revision,
            identity: ProvenanceSessionWorkModelIdentity(
                session: factualProjection.session,
                providerThreadIdentities: factualProjection.providerThreadIdentities
            ),
            thread: thread,
            currentTurn: currentTurn,
            priorTurns: factualProjection.priorTurns,
            milestones: semanticField(
                kind: ProvenanceCodingAgentSemanticInferenceKind.milestones.rawValue,
                scope: .session,
                scopeID: factualProjection.session.id,
                records: semanticRecordByField
            ),
            blockers: semanticField(
                kind: ProvenanceCodingAgentSemanticInferenceKind.blockers.rawValue,
                scope: .session,
                scopeID: factualProjection.session.id,
                records: semanticRecordByField
            ),
            approachChanges: semanticField(
                kind: ProvenanceCodingAgentSemanticInferenceKind.approachChanges.rawValue,
                scope: .session,
                scopeID: factualProjection.session.id,
                records: semanticRecordByField
            ),
            sessionPhase: semanticField(
                kind: ProvenanceCodingAgentSemanticInferenceKind.sessionPhase.rawValue,
                scope: .session,
                scopeID: factualProjection.session.id,
                records: semanticRecordByField
            ),
            basis: ProvenanceSessionWorkModelBasis(
                factualSessionProjection: factualProjection,
                semanticInferenceRecords: semanticRecords
            )
        )

        return ProvenanceSessionWorkModelResponse(
            found: true,
            sessionID: request.sessionID,
            model: model
        )
    }

    private func activeSemanticRecords(
        sessionID: String,
        threadID: String?,
        turnID: String?
    ) throws -> [ProvenanceSemanticInferenceRecord] {
        var records: [ProvenanceSemanticInferenceRecord] = []
        records.append(contentsOf: try activeSemanticRecords(
            kind: ProvenanceCodingAgentSemanticInferenceKind.milestones.rawValue,
            scope: .session,
            scopeID: sessionID
        ))
        records.append(contentsOf: try activeSemanticRecords(
            kind: ProvenanceCodingAgentSemanticInferenceKind.blockers.rawValue,
            scope: .session,
            scopeID: sessionID
        ))
        records.append(contentsOf: try activeSemanticRecords(
            kind: ProvenanceCodingAgentSemanticInferenceKind.approachChanges.rawValue,
            scope: .session,
            scopeID: sessionID
        ))
        records.append(contentsOf: try activeSemanticRecords(
            kind: ProvenanceCodingAgentSemanticInferenceKind.sessionPhase.rawValue,
            scope: .session,
            scopeID: sessionID
        ))
        if let threadID {
            records.append(contentsOf: try activeSemanticRecords(
                kind: ProvenanceCodingAgentSemanticInferenceKind.threadIntent.rawValue,
                scope: .thread,
                scopeID: threadID
            ))
        }
        if let turnID {
            records.append(contentsOf: try activeSemanticRecords(
                kind: ProvenanceCodingAgentSemanticInferenceKind.turnIntent.rawValue,
                scope: .turn,
                scopeID: turnID
            ))
            records.append(contentsOf: try activeSemanticRecords(
                kind: ProvenanceCodingAgentSemanticInferenceKind.currentActivity.rawValue,
                scope: .turn,
                scopeID: turnID
            ))
        }
        return records.sorted {
            if $0.scope.rawValue != $1.scope.rawValue {
                return $0.scope.rawValue < $1.scope.rawValue
            }
            if $0.scopeID != $1.scopeID {
                return $0.scopeID < $1.scopeID
            }
            if $0.kind != $1.kind {
                return $0.kind < $1.kind
            }
            if $0.createdAt != $1.createdAt {
                return $0.createdAt > $1.createdAt
            }
            return $0.id < $1.id
        }
    }

    private func activeSemanticRecords(
        kind: String,
        scope: ProvenanceSemanticInferenceScope,
        scopeID: String
    ) throws -> [ProvenanceSemanticInferenceRecord] {
        try semanticInferenceRecords(
            ProvenanceSemanticInferenceQueryRequest(
                scope: scope,
                scopeID: scopeID,
                kind: kind,
                includeInactive: false,
                limit: 1
            )
        ).records
    }

    private static func selectedThreadIdentity(
        from factualProjection: ProvenanceFactualSessionProjectionSnapshot,
        latestTurn: ProvenanceCodingAgentTurnRecord?
    ) -> ProvenanceFactualSessionProjectionProviderThreadIdentity? {
        guard let latestTurn else {
            return soleThreadIdentity(from: factualProjection)
        }
        guard let threadID = latestTurn.threadID else {
            return soleThreadIdentity(from: factualProjection)
        }
        return factualProjection.providerThreadIdentities.first(where: { $0.threadID == threadID })
    }

    private static func soleThreadIdentity(
        from factualProjection: ProvenanceFactualSessionProjectionSnapshot
    ) -> ProvenanceFactualSessionProjectionProviderThreadIdentity? {
        factualProjection.providerThreadIdentities.count == 1
            ? factualProjection.providerThreadIdentities[0]
            : nil
    }

    private func semanticField(
        kind: String,
        scope: ProvenanceSemanticInferenceScope,
        scopeID: String?,
        records: [SemanticFieldKey: ProvenanceSemanticInferenceRecord]
    ) -> ProvenanceSessionWorkModelSemanticField {
        guard let scopeID else {
            return ProvenanceSessionWorkModelSemanticField(
                kind: kind,
                scope: scope,
                scopeID: nil,
                state: .unavailable,
                reason: "missing_factual_scope"
            )
        }
        let key = SemanticFieldKey(kind: kind, scope: scope, scopeID: scopeID)
        guard let record = records[key] else {
            return ProvenanceSessionWorkModelSemanticField(
                kind: kind,
                scope: scope,
                scopeID: scopeID,
                state: .unknown,
                reason: "no_active_semantic_inference"
            )
        }
        return ProvenanceSessionWorkModelSemanticField(
            kind: kind,
            scope: scope,
            scopeID: scopeID,
            state: .known,
            record: ProvenanceSessionWorkModelSemanticRecord(record: record)
        )
    }

    /// Reads one current-state assistant-message projection by stable ID.
    ///
    /// - Parameter id: Stable coding-agent assistant-message identifier.
    /// - Returns: The persisted assistant-message projection, or `nil` when the ID is unknown.
    /// - Throws: ``ProvenanceSQLiteError`` when SQLite rejects the read.
    func codingAgentAssistantMessage(id: String) throws -> ProvenanceCodingAgentAssistantMessageRecord? {
        let query = try database.prepare(
            """
            SELECT
                session_id,
                thread_id,
                turn_id,
                provider,
                item_id,
                text,
                completed_at_seconds,
                source,
                confidence
            FROM provenance_coding_agent_assistant_messages
            WHERE id = ?
            """
        )
        defer { query.finalize() }

        try query.bind(id, at: 1)
        guard try query.step(),
              let sessionID = query.string(at: 0),
              let provider = query.string(at: 3),
              let text = query.string(at: 5),
              let sourceRawValue = query.string(at: 7),
              let source = ProvenanceSource(rawValue: sourceRawValue),
              let confidenceRawValue = query.string(at: 8),
              let confidence = ProvenanceConfidence(rawValue: confidenceRawValue) else {
            return nil
        }

        return ProvenanceCodingAgentAssistantMessageRecord(
            id: id,
            sessionID: sessionID,
            threadID: query.string(at: 1),
            turnID: query.string(at: 2),
            provider: provider,
            itemID: query.string(at: 4),
            text: text,
            completedAt: Date(timeIntervalSince1970: query.double(at: 6) ?? 0),
            source: source,
            confidence: confidence
        )
    }

    func codingAgentThreadIDs(sessionID: String) throws -> [String] {
        let query = try database.prepare(
            """
            SELECT id
            FROM provenance_coding_agent_threads
            WHERE session_id = ?
            ORDER BY first_observed_at_seconds ASC, rowid ASC
            """
        )
        defer { query.finalize() }

        try query.bind(sessionID, at: 1)
        return try stringIDs(from: query)
    }

    func codingAgentTurnIDs(sessionID: String, limit: Int?) throws -> [String] {
        let rowLimit = limit.map { max(0, $0) }
        var sql = """
            SELECT id
            FROM provenance_coding_agent_turns
            WHERE session_id = ?
            ORDER BY COALESCE(started_at_seconds, updated_at_seconds) ASC, rowid ASC
            """
        if rowLimit != nil {
            sql += "\nLIMIT ?"
        }

        let query = try database.prepare(sql)
        defer { query.finalize() }

        try query.bind(sessionID, at: 1)
        if let rowLimit {
            try query.bind(rowLimit, at: 2)
        }
        return try stringIDs(from: query)
    }

    func factualTurnSnapshot(turnID: String) throws -> ProvenanceFactualSessionProjectionTurnSnapshot? {
        guard let turn = try codingAgentTurn(id: turnID) else { return nil }
        return ProvenanceFactualSessionProjectionTurnSnapshot(
            turn: turn,
            submittedPrompt: try latestCodingAgentPrompt(turnID: turnID),
            currentPlan: try latestCodingAgentPlanUpdate(turnID: turnID),
            completedCommands: try codingAgentCommandIDs(turnID: turnID).compactMap { try codingAgentCommand(id: $0) },
            visibleReasoningSummaries: try codingAgentReasoningSummaryIDs(turnID: turnID).compactMap {
                try codingAgentReasoningSummary(id: $0)
            },
            fileChangeAttributions: try codingAgentFileChangeAttributionIDs(turnID: turnID).compactMap {
                try codingAgentFileChangeAttribution(id: $0)
            },
            assistantMessages: try codingAgentAssistantMessageIDs(turnID: turnID).compactMap {
                try codingAgentAssistantMessage(id: $0)
            }
        )
    }

    private func latestCodingAgentPrompt(turnID: String) throws -> ProvenanceCodingAgentPromptRecord? {
        guard let id = try latestCodingAgentRecordID(
            tableName: "provenance_coding_agent_prompts",
            timeColumn: "submitted_at_seconds",
            turnID: turnID
        ) else {
            return nil
        }
        return try codingAgentPrompt(id: id)
    }

    private func latestCodingAgentPlanUpdate(turnID: String) throws -> ProvenanceCodingAgentPlanUpdateRecord? {
        guard let id = try latestCodingAgentRecordID(
            tableName: "provenance_coding_agent_plan_updates",
            timeColumn: "observed_at_seconds",
            turnID: turnID
        ) else {
            return nil
        }
        return try codingAgentPlanUpdate(id: id)
    }

    private func codingAgentCommandIDs(turnID: String) throws -> [String] {
        try codingAgentRecordIDs(
            tableName: "provenance_coding_agent_commands",
            timeColumn: "completed_at_seconds",
            turnID: turnID
        )
    }

    private func codingAgentReasoningSummaryIDs(turnID: String) throws -> [String] {
        try codingAgentRecordIDs(
            tableName: "provenance_coding_agent_reasoning_summaries",
            timeColumn: "completed_at_seconds",
            turnID: turnID
        )
    }

    private func codingAgentAssistantMessageIDs(turnID: String) throws -> [String] {
        try codingAgentRecordIDs(
            tableName: "provenance_coding_agent_assistant_messages",
            timeColumn: "completed_at_seconds",
            turnID: turnID
        )
    }

    private func codingAgentFileChangeAttributionIDs(turnID: String) throws -> [String] {
        try codingAgentRecordIDs(
            tableName: "provenance_coding_agent_file_change_attributions",
            timeColumn: "observed_at_seconds",
            turnID: turnID
        )
    }

    private func latestCodingAgentRecordID(
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

    private func codingAgentRecordIDs(
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
        return try stringIDs(from: query)
    }

    private func stringIDs(from query: ProvenanceSQLiteStatement) throws -> [String] {
        var ids: [String] = []
        while try query.step() {
            if let id = query.string(at: 0) {
                ids.append(id)
            }
        }
        return ids
    }

    private struct SemanticFieldKey: Hashable {
        let kind: String
        let scope: ProvenanceSemanticInferenceScope
        let scopeID: String
    }
}
