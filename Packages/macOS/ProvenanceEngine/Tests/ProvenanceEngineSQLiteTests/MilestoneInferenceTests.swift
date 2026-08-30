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
        #expect(activeMilestone.identityBasis == .providerPlanStepID)
        #expect(activeMilestone.stateBasis == .providerPlanStepStatus)
        #expect(activeMilestone.parentID == nil)
        #expect(activeMilestone.sourceEvidenceRefs.contains {
            $0.kind == "coding_agent_plan_update" && $0.id == plan.id
        })
        #expect(activeMilestone.sourceEvidenceRefs.contains {
            $0.kind == "coding_agent_plan_step" && $0.id == plan.steps[1].id
        })
        #expect(payload.omissionReasons.contains("hierarchy_not_evidenced_by_plan_steps"))
        #expect(milestoneRecord.confidence == .medium)
        #expect(milestoneRecord.specificity == .scoped)
        #expect(hasPlanEvidence)
    }

    @Test
    func providerStepIdentitiesSurviveReorderAndInsertion() throws {
        let base = FixtureBase()
        let turn = base.turn(status: "started")
        let firstPlan = base.plan(
            id: "plan-provider-ids-first",
            steps: [
                Self.planStep(id: "step-discover", order: 0, text: "Inspect semantic contracts", status: "completed"),
                Self.planStep(id: "step-implement", order: 1, text: "Implement milestone payloads", status: "in_progress"),
            ],
            turnID: turn.id,
            offset: 5
        )
        let secondPlan = base.plan(
            id: "plan-provider-ids-second",
            steps: [
                Self.planStep(id: "step-implement", order: 0, text: "Implement milestone payloads", status: "completed"),
                Self.planStep(id: "step-validate", order: 1, text: "Validate milestone semantics", status: "in_progress"),
                Self.planStep(id: "step-discover", order: 2, text: "Inspect semantic contracts", status: "completed"),
            ],
            turnID: turn.id,
            offset: 7
        )

        let firstPayload = try Self.milestonePayload(from: firstPlan, turn: turn, base: base)
        let secondPayload = try Self.milestonePayload(from: secondPlan, turn: turn, base: base)
        let firstIDsByTitle = Dictionary(uniqueKeysWithValues: firstPayload.milestones.map { ($0.title, $0.id) })
        let secondByTitle = Dictionary(uniqueKeysWithValues: secondPayload.milestones.map { ($0.title, $0) })

        #expect(secondByTitle["Implement milestone payloads"]?.id == firstIDsByTitle["Implement milestone payloads"])
        #expect(secondByTitle["Inspect semantic contracts"]?.id == firstIDsByTitle["Inspect semantic contracts"])
        #expect(secondByTitle["Validate milestone semantics"]?.identityBasis == .providerPlanStepID)
        #expect(secondByTitle["Implement milestone payloads"]?.order == 0)
        #expect(secondByTitle["Inspect semantic contracts"]?.order == 2)
        #expect(secondPayload.currentMilestoneID == secondByTitle["Validate milestone semantics"]?.id)
    }

    @Test
    func generatedPlanStepRecordIDsDoNotClaimProviderStableIdentity() throws {
        let base = FixtureBase()
        let turn = base.turn(status: "started")
        let firstPlan = base.plan(
            id: "coding-agent-plan-event-a",
            steps: [
                Self.planStep(
                    id: "coding-agent-plan-step-event-a-0",
                    order: 0,
                    text: "Inspect semantic contracts",
                    status: "completed"
                ),
                Self.planStep(
                    id: "coding-agent-plan-step-event-a-1",
                    order: 1,
                    text: "Implement milestone payloads",
                    status: "in_progress"
                ),
            ],
            turnID: turn.id,
            offset: 5
        )
        let secondPlan = base.plan(
            id: "coding-agent-plan-event-b",
            steps: [
                Self.planStep(
                    id: "coding-agent-plan-step-event-b-0",
                    order: 0,
                    text: "Implement milestone payloads",
                    status: "completed"
                ),
                Self.planStep(
                    id: "coding-agent-plan-step-event-b-1",
                    order: 1,
                    text: "Validate milestone semantics",
                    status: "in_progress"
                ),
                Self.planStep(
                    id: "coding-agent-plan-step-event-b-2",
                    order: 2,
                    text: "Inspect semantic contracts",
                    status: "completed"
                ),
            ],
            turnID: turn.id,
            offset: 7
        )

        let firstPayload = try Self.milestonePayload(from: firstPlan, turn: turn, base: base)
        let secondPayload = try Self.milestonePayload(from: secondPlan, turn: turn, base: base)
        let firstIDsByTitle = Dictionary(uniqueKeysWithValues: firstPayload.milestones.map { ($0.title, $0.id) })
        let secondByTitle = Dictionary(uniqueKeysWithValues: secondPayload.milestones.map { ($0.title, $0) })

        #expect(secondByTitle["Implement milestone payloads"]?.id == firstIDsByTitle["Implement milestone payloads"])
        #expect(secondByTitle["Inspect semantic contracts"]?.id == firstIDsByTitle["Inspect semantic contracts"])
        #expect(secondPayload.milestones.allSatisfy { $0.identityBasis == .uniquePlanStepText })
        #expect(secondPayload.milestones.allSatisfy {
            $0.omissionReasons.contains("provider_plan_step_id_unavailable")
        })
        #expect(secondByTitle["Implement milestone payloads"]?.sourceEvidenceRefs.contains {
            $0.kind == "coding_agent_plan_step" && $0.id == "coding-agent-plan-step-event-b-0"
        } == true)
    }

    @Test
    func unsupportedProviderStatusesRemainUnknownWithBasis() throws {
        let base = FixtureBase()
        let turn = base.turn(status: "started")
        let plan = base.plan(
            steps: [
                (text: "Wait for reviewer decision", status: "waiting_on_human"),
            ],
            turnID: turn.id,
            offset: 5
        )

        let payload = try Self.milestonePayload(from: plan, turn: turn, base: base)

        #expect(payload.milestones.map(\.status) == [.unknown])
        #expect(payload.milestones.first?.stateBasis == .unsupportedProviderStatus)
        #expect(payload.milestones.first?.omissionReasons.contains("unsupported_provider_plan_step_status") == true)
        #expect(payload.omissionReasons.contains("unsupported_provider_plan_step_status"))
    }

    @Test
    func missingProviderStepIDUsesTextIdentityWithOmissionReason() throws {
        let base = FixtureBase()
        let turn = base.turn(status: "started")
        let plan = base.plan(
            id: "plan-text-fallback",
            steps: [
                Self.planStep(id: "", order: 0, text: "Draft milestone contract", status: "in_progress"),
            ],
            turnID: turn.id,
            offset: 5
        )

        let payload = try Self.milestonePayload(from: plan, turn: turn, base: base)
        let milestone = try #require(payload.milestones.first)

        #expect(milestone.identityBasis == .uniquePlanStepText)
        #expect(milestone.omissionReasons == ["provider_plan_step_id_unavailable"])
        #expect(payload.omissionReasons.contains("provider_plan_step_id_unavailable"))
    }

    @Test
    func repeatedTitlesWithoutStableStepIDsRemainSeparateAndAmbiguous() throws {
        let base = FixtureBase()
        let turn = base.turn(status: "started")
        let plan = base.plan(
            id: "plan-repeated-title",
            steps: [
                Self.planStep(id: "", order: 0, text: "Validate milestone inference", status: "in_progress"),
                Self.planStep(id: "   ", order: 1, text: "Validate milestone inference", status: "pending"),
            ],
            turnID: turn.id,
            offset: 5
        )

        let payload = try Self.milestonePayload(from: plan, turn: turn, base: base)

        #expect(Set(payload.milestones.map(\.id)).count == 2)
        #expect(payload.milestones.allSatisfy { $0.identityBasis == .ambiguousPlanStepText })
        #expect(payload.milestones.allSatisfy {
            $0.ambiguityReasons.contains("repeated_plan_step_text_without_stable_identity")
        })
        #expect(payload.ambiguityReasons.contains("repeated_plan_step_text_without_stable_identity"))
    }

    @Test
    func successfulCommandAndCompletedTurnDoNotProveMilestoneCompletion() throws {
        let base = FixtureBase()
        let turn = base.turn(status: "completed", completedOffset: 12)
        let plan = base.plan(
            steps: [(text: "Ship milestone inference", status: "pending")],
            turnID: turn.id,
            offset: 5
        )
        let command = base.command("pwd", turnID: turn.id, offset: 10)
        let snapshot = base.snapshot(turns: [base.turnSnapshot(turn: turn, plan: plan, commands: [command])])
        let records = ProvenanceCodingAgentSessionSemanticInferenceProducer.records(
            for: snapshot,
            createdAt: base.timestamp.addingTimeInterval(20)
        )
        let record = try Self.record(.milestones, scope: .session, scopeID: base.session.id, from: records)
        let payload = try Self.milestonePayload(from: record)

        #expect(payload.milestones.map(\.status) == [.planned])
        #expect(payload.milestones.first?.stateBasis == .providerPlanStepStatus)
    }

    @Test
    func unsupportedPlanHierarchyMarkersDoNotCreateParentRelationships() throws {
        let base = FixtureBase()
        let turn = base.turn(status: "started")
        let plan = base.plan(
            steps: [
                (text: "Implement semantic milestones", status: "in_progress"),
                (text: "  - Add hierarchy support", status: "pending"),
            ],
            turnID: turn.id,
            offset: 5
        )
        let payload = try Self.milestonePayload(from: plan, turn: turn, base: base)

        #expect(payload.milestones.map(\.parentID) == [nil, nil])
        #expect(payload.omissionReasons.contains("hierarchy_not_evidenced_by_plan_steps"))
    }

    @Test
    func planMilestoneOutputIsBoundedWithOmissionReason() throws {
        let base = FixtureBase()
        let turn = base.turn(status: "started")
        let steps = (0...ProvenanceCodingAgentSessionSemanticInferenceProducer.maximumMilestonesPerPlan).map {
            Self.planStep(id: "step-\($0)", order: $0, text: "Milestone \($0)", status: "pending")
        }
        let plan = base.plan(id: "plan-bounded", steps: steps, turnID: turn.id, offset: 5)
        let payload = try Self.milestonePayload(from: plan, turn: turn, base: base)

        #expect(payload.milestones.count == ProvenanceCodingAgentSessionSemanticInferenceProducer.maximumMilestonesPerPlan)
        #expect(payload.omissionReasons.contains("milestone_output_truncated"))
    }

    @Test
    func completedPlanStepsDoNotProduceCurrentMilestone() throws {
        let base = FixtureBase()
        let turn = base.turn(status: "started")
        let plan = base.plan(
            steps: [
                (text: "Inspect existing semantic fields", status: "completed"),
                (text: "Add milestone payload contracts", status: "completed"),
            ],
            turnID: turn.id,
            offset: 6
        )
        let snapshot = base.snapshot(turns: [base.turnSnapshot(turn: turn, plan: plan)])

        let records = ProvenanceCodingAgentSessionSemanticInferenceProducer.records(
            for: snapshot,
            createdAt: base.timestamp.addingTimeInterval(20)
        )
        let milestoneRecord = try Self.record(.milestones, scope: .session, scopeID: base.session.id, from: records)
        let payload = try Self.milestonePayload(from: milestoneRecord)

        #expect(payload.milestones.map(\.status) == [.completed, .completed])
        #expect(payload.currentMilestoneID == nil)
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
            ProvenanceCodingAgentSemanticInferenceKind.blockers.rawValue,
            ProvenanceCodingAgentSemanticInferenceKind.approachChanges.rawValue,
            ProvenanceCodingAgentSemanticInferenceKind.sessionPhase.rawValue,
            ProvenanceCodingAgentSemanticInferenceKind.currentActivity.rawValue,
        ])
        #expect(first.map(\.id) == second.map(\.id))
        #expect(first == second)
    }

    @Test
    func milestonePayloadPreservesSupportedHierarchyAndOmitsInvalidRelationships() throws {
        let payload = ProvenanceCodingAgentMilestonePayload(
            currentMilestoneID: "duplicate",
            milestones: [
                Self.milestone("parent", "Implement milestone semantics", status: .active, order: 0),
                Self.milestone("child", "Add hierarchy contract", status: .planned, order: 1, parentID: "parent"),
                Self.milestone("orphan", "Reference missing parent", status: .planned, order: 2, parentID: "missing"),
                Self.milestone("cycle-a", "Cycle A", status: .planned, order: 3, parentID: "cycle-b"),
                Self.milestone("cycle-b", "Cycle B", status: .planned, order: 4, parentID: "cycle-a"),
                Self.milestone("duplicate", "Duplicate A", status: .planned, order: 5, parentID: "parent"),
                Self.milestone("duplicate", "Duplicate B", status: .planned, order: 6, parentID: "parent"),
            ],
            basis: "test"
        )
        let byTitle = Dictionary(uniqueKeysWithValues: payload.milestones.map { ($0.title, $0) })

        #expect(byTitle["Add hierarchy contract"]?.parentID == "parent")
        #expect(byTitle["Reference missing parent"]?.parentID == nil)
        #expect(byTitle["Cycle A"]?.parentID == nil)
        #expect(byTitle["Cycle B"]?.parentID == nil)
        #expect(byTitle["Duplicate A"]?.parentID == nil)
        #expect(byTitle["Duplicate B"]?.parentID == nil)
        #expect(payload.currentMilestoneID == nil)
        #expect(payload.ambiguityReasons.contains("duplicate_milestone_identity"))
        #expect(payload.omissionReasons.contains("unresolvable_parent_relationship_omitted:orphan"))
        #expect(payload.omissionReasons.contains("cyclic_parent_relationship_omitted:cycle-a"))
        #expect(payload.omissionReasons.contains("cyclic_parent_relationship_omitted:cycle-b"))
        #expect(payload.omissionReasons.contains("current_milestone_identity_ambiguous"))
    }

    @Test
    func legacyMilestonePayloadJSONRemainsReadable() throws {
        let json = """
        {"currentMilestoneID":"legacy-milestone","milestones":[{"id":"legacy-milestone","title":"Legacy milestone","status":"active","order":0}],"basis":"current_plan"}
        """
        let payload = try JSONDecoder().decode(
            ProvenanceCodingAgentMilestonePayload.self,
            from: Data(json.utf8)
        )
        let milestone = try #require(payload.milestones.first)

        #expect(payload.currentMilestoneID == "legacy-milestone")
        #expect(payload.ambiguityReasons.isEmpty)
        #expect(payload.omissionReasons.isEmpty)
        #expect(milestone.identityBasis == .legacyPayload)
        #expect(milestone.stateBasis == .legacyPayload)
        #expect(milestone.sourceEvidenceRefs.isEmpty)
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

    private static func milestonePayload(
        from plan: ProvenanceCodingAgentPlanUpdateRecord,
        turn: ProvenanceCodingAgentTurnRecord,
        base: FixtureBase
    ) throws -> ProvenanceCodingAgentMilestonePayload {
        let snapshot = base.snapshot(turns: [base.turnSnapshot(turn: turn, plan: plan)])
        let records = ProvenanceCodingAgentSessionSemanticInferenceProducer.records(
            for: snapshot,
            createdAt: base.timestamp.addingTimeInterval(20)
        )
        let record = try Self.record(.milestones, scope: .session, scopeID: base.session.id, from: records)
        return try Self.milestonePayload(from: record)
    }

    private static func planStep(
        id: String,
        order: Int,
        text: String,
        status: String
    ) -> ProvenanceCodingAgentPlanStepRecord {
        ProvenanceCodingAgentPlanStepRecord(
            id: id,
            order: order,
            text: text,
            status: status
        )
    }

    private static func milestone(
        _ id: String,
        _ title: String,
        status: ProvenanceCodingAgentMilestoneStatus,
        order: Int,
        parentID: String? = nil
    ) -> ProvenanceCodingAgentMilestone {
        ProvenanceCodingAgentMilestone(
            id: id,
            title: title,
            status: status,
            order: order,
            parentID: parentID
        )
    }
}
