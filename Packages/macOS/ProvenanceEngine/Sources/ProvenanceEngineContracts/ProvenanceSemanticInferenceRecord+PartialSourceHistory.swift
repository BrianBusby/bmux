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
        var occupiedIDs = Set(existingPayload.blockers.map(\.id))
        var requiredIDs = Set<String>()
        let adjustedCandidates = candidatePayload.blockers.map { candidate in
            guard candidate.state == .reportedOpen,
                  let existing = existingPayload.blockers.first(where: {
                      $0.id == candidate.id && $0.hasTerminalPartialHistoryState
                  }) else {
                occupiedIDs.insert(candidate.id)
                return candidate
            }
            requiredIDs.insert(existing.id)
            let reidentified = candidate.withPartialHistoryID(nextPartialHistoryBlockerID(
                for: candidate,
                occupiedIDs: occupiedIDs
            ))
            occupiedIDs.insert(reidentified.id)
            requiredIDs.insert(reidentified.id)
            return reidentified
        }
        let candidateIDs = Set(adjustedCandidates.map(\.id))
        requiredIDs.formUnion(candidateIDs)
        let retained = existingPayload.blockers.filter { !candidateIDs.contains($0.id) }
        let mergedBlockers = retained + adjustedCandidates
        let boundedBlockers = boundedBlockers(mergedBlockers, requiredIDs: requiredIDs)
        var omissionReasons = candidatePayload.omissionReasons + ["partial_source_history_retained_prior_blockers"]
        if boundedBlockers.count < mergedBlockers.count {
            omissionReasons.append("partial_source_history_merge_blocker_output_truncated")
        }
        let merged = ProvenanceCodingAgentBlockerPayload(
            blockers: boundedBlockers,
            basis: candidatePayload.basis,
            sourceHistoryState: .partial,
            ambiguityReasons: candidatePayload.ambiguityReasons,
            omissionReasons: omissionReasons
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
        let mergedApproachChanges = retained + candidatePayload.approachChanges
        let boundedApproachChanges = boundedApproachChanges(
            mergedApproachChanges,
            requiredIDs: candidateIDs
        )
        var omissionReasons = candidatePayload.omissionReasons + ["partial_source_history_retained_prior_approach_changes"]
        if boundedApproachChanges.count < mergedApproachChanges.count {
            omissionReasons.append("partial_source_history_merge_approach_changes_truncated")
        }
        let merged = ProvenanceCodingAgentApproachChangePayload(
            approachChanges: boundedApproachChanges,
            basis: candidatePayload.basis,
            sourceHistoryState: .partial,
            ambiguityReasons: candidatePayload.ambiguityReasons,
            omissionReasons: omissionReasons
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

    func nextPartialHistoryBlockerID(
        for blocker: ProvenanceCodingAgentBlocker,
        occupiedIDs: Set<String>
    ) -> String {
        let key = ProvenanceCodingAgentSessionSemanticInferenceProducer.blockerKey(
            activity: blocker.affectedActivity,
            condition: blocker.condition,
            milestoneID: blocker.affectedMilestoneID
        )
        var episode = 0
        while true {
            let id = ProvenanceCodingAgentSessionSemanticInferenceProducer.blockerID(
                key: key,
                episode: episode
            )
            if !occupiedIDs.contains(id) {
                return id
            }
            episode += 1
        }
    }

    func boundedBlockers(
        _ blockers: [ProvenanceCodingAgentBlocker],
        requiredIDs: Set<String>
    ) -> [ProvenanceCodingAgentBlocker] {
        boundedItems(
            blockers,
            ids: { $0.id },
            requiredIDs: requiredIDs,
            limit: ProvenanceCodingAgentSessionSemanticInferenceProducer.maximumBlockersPerSession
        )
    }

    func boundedApproachChanges(
        _ approachChanges: [ProvenanceCodingAgentApproachChange],
        requiredIDs: Set<String>
    ) -> [ProvenanceCodingAgentApproachChange] {
        boundedItems(
            approachChanges,
            ids: { $0.id },
            requiredIDs: requiredIDs,
            limit: ProvenanceCodingAgentSessionSemanticInferenceProducer.maximumApproachChangesPerSession
        )
    }

    func boundedItems<Item>(
        _ items: [Item],
        ids: (Item) -> String,
        requiredIDs: Set<String>,
        limit: Int
    ) -> [Item] {
        guard items.count > limit else { return items }
        var selectedIDs = Set(items.filter { requiredIDs.contains(ids($0)) }.map(ids))
        if selectedIDs.count > limit {
            let newestRequired = items.filter { requiredIDs.contains(ids($0)) }.suffix(limit)
            selectedIDs = Set(newestRequired.map(ids))
        }
        for item in items.reversed() where selectedIDs.count < limit {
            selectedIDs.insert(ids(item))
        }
        return items.filter { selectedIDs.contains(ids($0)) }
    }
}

private extension ProvenanceCodingAgentBlocker {
    var hasTerminalPartialHistoryState: Bool {
        switch state {
        case .reportedCleared, .reportedBypassed, .reportedNoLongerApplies:
            return true
        case .reportedOpen, .unknown:
            return false
        }
    }

    func withPartialHistoryID(_ id: String) -> ProvenanceCodingAgentBlocker {
        ProvenanceCodingAgentBlocker(
            id: id,
            description: description,
            affectedActivity: affectedActivity,
            condition: condition,
            affectedMilestoneID: affectedMilestoneID,
            state: state,
            identityBasis: identityBasis,
            stateBasis: stateBasis,
            reportedByProvider: reportedByProvider,
            reportedBySource: reportedBySource,
            sourceEvidenceRefs: sourceEvidenceRefs,
            ambiguityReasons: ambiguityReasons,
            omissionReasons: omissionReasons
        )
    }
}
