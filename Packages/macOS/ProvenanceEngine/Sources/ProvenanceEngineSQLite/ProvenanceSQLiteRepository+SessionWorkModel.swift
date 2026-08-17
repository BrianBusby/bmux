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
                )
            )
        }
        let revision = ProvenanceSessionWorkModelRevision(
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

    private struct SemanticFieldKey: Hashable {
        let kind: String
        let scope: ProvenanceSemanticInferenceScope
        let scopeID: String
    }
}
