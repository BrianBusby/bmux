import Foundation
import ProvenanceEngineContracts
@testable import ProvenanceEngineSQLite
import Testing

@Suite
struct MilestoneInferenceTests {
    @Test
    func currentPlanStepsProduceSessionMilestones() throws {
        let base = FixtureBase()
        let turn = base.turn(status: "started")
        let plan = base.plan(
            steps: [
                (text: "Inspect existing semantic fields", status: "completed"),
                (text: "Add milestone payload contracts", status: "in_progress"),
                (text: "Project milestones into SessionWorkModel", status: "pending"),
            ],
            turnID: turn.id,
            offset: 6
        )
        let snapshot = base.snapshot(turns: [base.turnSnapshot(
            turn: turn,
            prompt: base.prompt("Implement milestone inference for coding-agent sessions.", turnID: turn.id),
            plan: plan
        )])

        let records = ProvenanceCodingAgentSessionSemanticInferenceProducer.records(
            for: snapshot,
            createdAt: base.timestamp.addingTimeInterval(20)
        )
        let milestoneRecord = try Self.record(.milestones, scope: .session, scopeID: base.session.id, from: records)
        let payload = try Self.milestonePayload(from: milestoneRecord)
        let activeMilestone = try #require(payload.milestones.first { $0.status == .active })
        let hasPlanEvidence = milestoneRecord.supportingEvidenceRefs.contains {
            $0.kind == "coding_agent_plan_update" && $0.id == plan.id
        }

        #expect(payload.basis == "current_plan")
        #expect(payload.milestones.map(\.title) == [
            "Inspect existing semantic fields",
            "Add milestone payload contracts",
            "Project milestones into SessionWorkModel",
        ])
        #expect(payload.milestones.map(\.status) == [.completed, .active, .planned])
        #expect(payload.milestones.count == 3)
        #expect(payload.currentMilestoneID == activeMilestone.id)
        #expect(milestoneRecord.confidence == .medium)
        #expect(milestoneRecord.specificity == .scoped)
        #expect(hasPlanEvidence)
    }


    @Test
    func ambiguousTurnEvidencePublishesUnknownBroadMilestoneClaim() throws {
        let base = FixtureBase()
        let turn = base.turn(status: "started")
        let snapshot = base.snapshot(turns: [base.turnSnapshot(turn: turn)])

        let records = ProvenanceCodingAgentSessionSemanticInferenceProducer.records(
            for: snapshot,
            createdAt: base.timestamp.addingTimeInterval(20)
        )
        let milestoneRecord = try Self.record(.milestones, scope: .session, scopeID: base.session.id, from: records)
        let milestonePayload = try Self.milestonePayload(from: milestoneRecord)

        #expect(milestonePayload.milestones.isEmpty)
        #expect(milestonePayload.unknownReason != nil)
        #expect(milestoneRecord.confidence == .unknown)
        #expect(milestoneRecord.specificity == .broad)
    }

    @Test
    func producerRecordOrderAndIDsAreDeterministic() throws {
        let base = FixtureBase()
        let turn = base.turn(status: "started")
        let snapshot = base.snapshot(turns: [base.turnSnapshot(
            turn: turn,
            prompt: base.prompt("Implement deterministic semantic records.", turnID: turn.id),
            plan: base.plan("Implement deterministic semantic record IDs", turnID: turn.id, offset: 5)
        )])
        let createdAt = base.timestamp.addingTimeInterval(20)

        let first = ProvenanceCodingAgentSessionSemanticInferenceProducer.records(for: snapshot, createdAt: createdAt)
        let second = ProvenanceCodingAgentSessionSemanticInferenceProducer.records(for: snapshot, createdAt: createdAt)

        #expect(first.map(\.kind) == [
            ProvenanceCodingAgentSemanticInferenceKind.threadIntent.rawValue,
            ProvenanceCodingAgentSemanticInferenceKind.turnIntent.rawValue,
            ProvenanceCodingAgentSemanticInferenceKind.milestones.rawValue,
            ProvenanceCodingAgentSemanticInferenceKind.sessionPhase.rawValue,
            ProvenanceCodingAgentSemanticInferenceKind.currentActivity.rawValue,
        ])
        #expect(first.map(\.id) == second.map(\.id))
        #expect(first == second)
    }

    private static func record(
        _ kind: ProvenanceCodingAgentSemanticInferenceKind,
        scope: ProvenanceSemanticInferenceScope,
        scopeID: String,
        from records: [ProvenanceSemanticInferenceRecord]
    ) throws -> ProvenanceSemanticInferenceRecord {
        try #require(records.first {
            $0.kind == kind.rawValue && $0.scope == scope && $0.scopeID == scopeID
        })
    }

    private static func milestonePayload(
        from record: ProvenanceSemanticInferenceRecord
    ) throws -> ProvenanceCodingAgentMilestonePayload {
        try #require(ProvenanceCodingAgentMilestonePayload(semanticPayloadValue: record.payload))
    }
}
