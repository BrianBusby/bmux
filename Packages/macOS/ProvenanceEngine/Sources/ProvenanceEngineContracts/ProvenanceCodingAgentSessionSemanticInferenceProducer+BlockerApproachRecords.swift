import Foundation

extension ProvenanceCodingAgentSessionSemanticInferenceProducer {
    func blockerApproachRecords(
        for snapshot: ProvenanceFactualSessionProjectionSnapshot,
        milestonePayload: ProvenanceCodingAgentMilestonePayload,
        createdAt: Date
    ) -> [ProvenanceSemanticInferenceRecord] {
        let blockerPayload = Self.blockerPayload(for: snapshot, milestonePayload: milestonePayload)
        let approachChangePayload = Self.approachChangePayload(for: snapshot, milestonePayload: milestonePayload)
        return [
            Self.record(
                kind: .blockers,
                scope: .session,
                scopeID: snapshot.session.id,
                payload: blockerPayload.semanticPayloadValue,
                evidenceRefs: Self.evidenceRefs(for: blockerPayload, snapshot: snapshot),
                revision: snapshot.revision,
                confidence: blockerPayload.unknownReason == nil ? .medium : .unknown,
                specificity: blockerPayload.unknownReason == nil ? .scoped : .broad,
                createdAt: createdAt,
                producerID: producerID,
                producerVersion: producerVersion
            ),
            Self.record(
                kind: .approachChanges,
                scope: .session,
                scopeID: snapshot.session.id,
                payload: approachChangePayload.semanticPayloadValue,
                evidenceRefs: Self.evidenceRefs(for: approachChangePayload, snapshot: snapshot),
                revision: snapshot.revision,
                confidence: approachChangePayload.unknownReason == nil ? .medium : .unknown,
                specificity: approachChangePayload.unknownReason == nil ? .scoped : .broad,
                createdAt: createdAt,
                producerID: producerID,
                producerVersion: producerVersion
            ),
        ]
    }
}
