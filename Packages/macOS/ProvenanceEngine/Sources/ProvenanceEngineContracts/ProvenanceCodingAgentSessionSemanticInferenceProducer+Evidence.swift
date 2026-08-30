import Foundation

extension ProvenanceCodingAgentSessionSemanticInferenceProducer {
    static func record(
        kind: ProvenanceCodingAgentSemanticInferenceKind,
        scope: ProvenanceSemanticInferenceScope,
        scopeID: String,
        payload: ProvenanceSemanticPayloadValue,
        evidenceRefs: [ProvenanceSemanticEvidenceReference],
        revision: Int?,
        confidence: ProvenanceConfidence,
        specificity: ProvenanceSemanticSpecificity,
        createdAt: Date,
        producerID: String,
        producerVersion: String
    ) -> ProvenanceSemanticInferenceRecord {
        ProvenanceSemanticInferenceRecord(
            id: stableRecordID(
                kind: kind.rawValue,
                scope: scope,
                scopeID: scopeID,
                revision: revision,
                payload: payload,
                producerVersion: producerVersion
            ),
            kind: kind.rawValue,
            scope: scope,
            scopeID: scopeID,
            payload: payload,
            supportingEvidenceRefs: evidenceRefs,
            supportingFactualRevision: revision,
            confidence: confidence,
            specificity: specificity,
            producerType: .rule,
            producerID: producerID,
            producerVersion: producerVersion,
            createdAt: createdAt
        )
    }

    static func evidenceRefs(
        for payload: ProvenanceCodingAgentIntentPayload,
        thread: ProvenanceCodingAgentThreadRecord,
        snapshot: ProvenanceFactualSessionProjectionSnapshot
    ) -> [ProvenanceSemanticEvidenceReference] {
        var refs = baseEvidenceRefs(sessionID: snapshot.session.id, revision: snapshot.revision)
        refs.append(ProvenanceSemanticEvidenceReference(kind: "coding_agent_thread", id: thread.id))
        if let prompt = snapshot.turns
            .filter({ $0.turn.threadID == thread.id })
            .sorted(by: turnSort)
            .compactMap(\.submittedPrompt)
            .first {
            refs.append(ProvenanceSemanticEvidenceReference(kind: "coding_agent_prompt", id: prompt.id))
        }
        return deduplicated(refs)
    }

    static func evidenceRefs(
        for payload: ProvenanceCodingAgentIntentPayload,
        turn: ProvenanceFactualSessionProjectionTurnSnapshot,
        snapshot: ProvenanceFactualSessionProjectionSnapshot
    ) -> [ProvenanceSemanticEvidenceReference] {
        var refs = baseEvidenceRefs(sessionID: snapshot.session.id, revision: snapshot.revision)
        refs.append(ProvenanceSemanticEvidenceReference(kind: "coding_agent_turn", id: turn.turn.id))
        if let prompt = turn.submittedPrompt {
            refs.append(ProvenanceSemanticEvidenceReference(kind: "coding_agent_prompt", id: prompt.id))
        } else if let plan = turn.currentPlan {
            refs.append(ProvenanceSemanticEvidenceReference(kind: "coding_agent_plan_update", id: plan.id))
        }
        return deduplicated(refs)
    }

    static func evidenceRefs(
        for payload: ProvenanceCodingAgentMilestonePayload,
        latestTurn: ProvenanceFactualSessionProjectionTurnSnapshot?,
        snapshot: ProvenanceFactualSessionProjectionSnapshot
    ) -> [ProvenanceSemanticEvidenceReference] {
        var refs = baseEvidenceRefs(sessionID: snapshot.session.id, revision: snapshot.revision)
        guard let latestTurn else { return refs }
        refs.append(ProvenanceSemanticEvidenceReference(kind: "coding_agent_turn", id: latestTurn.turn.id))
        switch payload.basis {
        case "current_plan":
            if let plan = latestTurn.currentPlan {
                refs.append(ProvenanceSemanticEvidenceReference(kind: "coding_agent_plan_update", id: plan.id))
            }
        case "submitted_prompt":
            if let prompt = latestTurn.submittedPrompt {
                refs.append(ProvenanceSemanticEvidenceReference(kind: "coding_agent_prompt", id: prompt.id))
            }
        default:
            if let plan = latestTurn.currentPlan {
                refs.append(ProvenanceSemanticEvidenceReference(kind: "coding_agent_plan_update", id: plan.id))
            }
            if let prompt = latestTurn.submittedPrompt {
                refs.append(ProvenanceSemanticEvidenceReference(kind: "coding_agent_prompt", id: prompt.id))
            }
        }
        return deduplicated(refs)
    }

    static func evidenceRefs(
        for payload: ProvenanceCodingAgentSessionPhasePayload,
        latestTurn: ProvenanceFactualSessionProjectionTurnSnapshot?,
        snapshot: ProvenanceFactualSessionProjectionSnapshot
    ) -> [ProvenanceSemanticEvidenceReference] {
        var refs = baseEvidenceRefs(sessionID: snapshot.session.id, revision: snapshot.revision)
        if let latestTurn {
            refs.append(ProvenanceSemanticEvidenceReference(kind: "coding_agent_turn", id: latestTurn.turn.id))
            refs.append(contentsOf: materialActivityEvidenceRefs(from: latestTurn))
        }
        return deduplicated(refs)
    }

    static func evidenceRefs(
        for payload: ProvenanceCodingAgentBlockerPayload,
        snapshot: ProvenanceFactualSessionProjectionSnapshot
    ) -> [ProvenanceSemanticEvidenceReference] {
        var refs = baseEvidenceRefs(sessionID: snapshot.session.id, revision: snapshot.revision)
        refs.append(contentsOf: payload.blockers.flatMap(\.sourceEvidenceRefs))
        return deduplicated(refs)
    }

    static func evidenceRefs(
        for payload: ProvenanceCodingAgentApproachChangePayload,
        snapshot: ProvenanceFactualSessionProjectionSnapshot
    ) -> [ProvenanceSemanticEvidenceReference] {
        var refs = baseEvidenceRefs(sessionID: snapshot.session.id, revision: snapshot.revision)
        refs.append(contentsOf: payload.approachChanges.flatMap(\.sourceEvidenceRefs))
        return deduplicated(refs)
    }

    static func evidenceRefs(
        for payload: ProvenanceCodingAgentCurrentActivityPayload,
        turn: ProvenanceFactualSessionProjectionTurnSnapshot,
        snapshot: ProvenanceFactualSessionProjectionSnapshot
    ) -> [ProvenanceSemanticEvidenceReference] {
        var refs = baseEvidenceRefs(sessionID: snapshot.session.id, revision: snapshot.revision)
        refs.append(ProvenanceSemanticEvidenceReference(kind: "coding_agent_turn", id: turn.turn.id))
        refs.append(contentsOf: materialActivityEvidenceRefs(from: turn, basis: payload.basis))
        return deduplicated(refs)
    }

    static func baseEvidenceRefs(sessionID: String, revision: Int?) -> [ProvenanceSemanticEvidenceReference] {
        [ProvenanceSemanticEvidenceReference(
            kind: "factual_session_projection",
            id: sessionID,
            factualRevision: revision
        )]
    }

    static func materialActivityEvidenceRefs(
        from turn: ProvenanceFactualSessionProjectionTurnSnapshot,
        basis: String? = nil
    ) -> [ProvenanceSemanticEvidenceReference] {
        switch basis {
        case "file_change_attribution":
            return turn.fileChangeAttributions.map {
                ProvenanceSemanticEvidenceReference(kind: "coding_agent_file_change_attribution", id: $0.id)
            }
        case "failed_command", "completed_command":
            return turn.completedCommands.map {
                ProvenanceSemanticEvidenceReference(kind: "coding_agent_command", id: $0.id)
            }
        case "current_plan":
            return turn.currentPlan.map {
                [ProvenanceSemanticEvidenceReference(kind: "coding_agent_plan_update", id: $0.id)]
            } ?? []
        case "visible_reasoning_summary":
            return turn.visibleReasoningSummaries.map {
                ProvenanceSemanticEvidenceReference(kind: "coding_agent_reasoning_summary", id: $0.id)
            }
        case "submitted_prompt":
            return turn.submittedPrompt.map {
                [ProvenanceSemanticEvidenceReference(kind: "coding_agent_prompt", id: $0.id)]
            } ?? []
        default:
            var refs: [ProvenanceSemanticEvidenceReference] = []
            if let prompt = turn.submittedPrompt {
                refs.append(ProvenanceSemanticEvidenceReference(kind: "coding_agent_prompt", id: prompt.id))
            }
            if let plan = turn.currentPlan {
                refs.append(ProvenanceSemanticEvidenceReference(kind: "coding_agent_plan_update", id: plan.id))
            }
            refs.append(contentsOf: turn.visibleReasoningSummaries.map {
                ProvenanceSemanticEvidenceReference(kind: "coding_agent_reasoning_summary", id: $0.id)
            })
            refs.append(contentsOf: turn.completedCommands.map {
                ProvenanceSemanticEvidenceReference(kind: "coding_agent_command", id: $0.id)
            })
            refs.append(contentsOf: turn.fileChangeAttributions.map {
                ProvenanceSemanticEvidenceReference(kind: "coding_agent_file_change_attribution", id: $0.id)
            })
            return refs
        }
    }

    static func stableRecordID(
        kind: String,
        scope: ProvenanceSemanticInferenceScope,
        scopeID: String,
        revision: Int?,
        payload: ProvenanceSemanticPayloadValue,
        producerVersion: String
    ) -> String {
        let encodedPayload = (try? sortedJSONEncoder.encode(payload)).map {
            String(decoding: $0, as: UTF8.self)
        } ?? "unencodable"
        let fingerprint = fnv1a64Hex("\(kind)|\(scope.rawValue)|\(scopeID)|\(revision ?? 0)|\(producerVersion)|\(encodedPayload)")
        return ["semantic", kind, scope.rawValue, scopeID, "rev", String(revision ?? 0), fingerprint]
            .map(sanitizedIDComponent)
            .joined(separator: "-")
    }
}
