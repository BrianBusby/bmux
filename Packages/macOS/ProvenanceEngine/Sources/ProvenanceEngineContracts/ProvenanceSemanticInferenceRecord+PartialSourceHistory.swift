import Foundation

extension ProvenanceSemanticInferenceRecord {
    func mergingPartialSourceHistory(
        with existing: ProvenanceSemanticInferenceRecord
    ) -> ProvenanceSemanticInferenceRecord? {
        guard scope == existing.scope, scopeID == existing.scopeID, kind == existing.kind else {
            return nil
        }
        if kind == ProvenanceCodingAgentSemanticInferenceKind.blockers.rawValue {
            return mergingPartialBlockerPayload(with: existing)
        }
        if kind == ProvenanceCodingAgentSemanticInferenceKind.approachChanges.rawValue {
            return mergingPartialApproachChangePayload(with: existing)
        }
        return nil
    }

    func mergingPartialBlockerPayload(
        with existing: ProvenanceSemanticInferenceRecord
    ) -> ProvenanceSemanticInferenceRecord? {
        guard let candidatePayload = ProvenanceCodingAgentBlockerPayload(semanticPayloadValue: payload),
              candidatePayload.sourceHistoryState == .partial,
              let existingPayload = ProvenanceCodingAgentBlockerPayload(semanticPayloadValue: existing.payload),
              !existingPayload.blockers.isEmpty else {
            return nil
        }
        guard !candidatePayload.blockers.isEmpty else {
            return existing
        }
        let candidateIDs = Set(candidatePayload.blockers.map(\.id))
        let retained = existingPayload.blockers.filter { !candidateIDs.contains($0.id) }
        let merged = ProvenanceCodingAgentBlockerPayload(
            blockers: retained + candidatePayload.blockers,
            basis: candidatePayload.basis,
            sourceHistoryState: .partial,
            ambiguityReasons: candidatePayload.ambiguityReasons,
            omissionReasons: candidatePayload.omissionReasons + ["partial_source_history_retained_prior_blockers"]
        )
        return replacingPayload(
            merged.semanticPayloadValue,
            evidenceRefs: ProvenanceCodingAgentSessionSemanticInferenceProducer.deduplicated(
                existing.supportingEvidenceRefs + supportingEvidenceRefs
            )
        )
    }

    func mergingPartialApproachChangePayload(
        with existing: ProvenanceSemanticInferenceRecord
    ) -> ProvenanceSemanticInferenceRecord? {
        guard let candidatePayload = ProvenanceCodingAgentApproachChangePayload(semanticPayloadValue: payload),
              candidatePayload.sourceHistoryState == .partial,
              let existingPayload = ProvenanceCodingAgentApproachChangePayload(semanticPayloadValue: existing.payload),
              !existingPayload.approachChanges.isEmpty else {
            return nil
        }
        guard !candidatePayload.approachChanges.isEmpty else {
            return existing
        }
        let candidateIDs = Set(candidatePayload.approachChanges.map(\.id))
        let retained = existingPayload.approachChanges.filter { !candidateIDs.contains($0.id) }
        let merged = ProvenanceCodingAgentApproachChangePayload(
            approachChanges: retained + candidatePayload.approachChanges,
            basis: candidatePayload.basis,
            sourceHistoryState: .partial,
            ambiguityReasons: candidatePayload.ambiguityReasons,
            omissionReasons: candidatePayload.omissionReasons + ["partial_source_history_retained_prior_approach_changes"]
        )
        return replacingPayload(
            merged.semanticPayloadValue,
            evidenceRefs: ProvenanceCodingAgentSessionSemanticInferenceProducer.deduplicated(
                existing.supportingEvidenceRefs + supportingEvidenceRefs
            )
        )
    }

    func replacingPayload(
        _ payload: ProvenanceSemanticPayloadValue,
        evidenceRefs: [ProvenanceSemanticEvidenceReference]
    ) -> ProvenanceSemanticInferenceRecord {
        ProvenanceSemanticInferenceRecord(
            id: ProvenanceCodingAgentSessionSemanticInferenceProducer.stableRecordID(
                kind: kind,
                scope: scope,
                scopeID: scopeID,
                revision: supportingFactualRevision,
                payload: payload,
                producerVersion: producerVersion
            ),
            schemaVersion: schemaVersion,
            kind: kind,
            scope: scope,
            scopeID: scopeID,
            payload: payload,
            supportingEvidenceRefs: evidenceRefs,
            supportingFactualRevision: supportingFactualRevision,
            confidence: confidence,
            specificity: specificity,
            producerType: producerType,
            producerID: producerID,
            producerVersion: producerVersion,
            createdAt: createdAt,
            supersedes: supersedes,
            supersededBy: supersededBy,
            status: status
        )
    }
}
