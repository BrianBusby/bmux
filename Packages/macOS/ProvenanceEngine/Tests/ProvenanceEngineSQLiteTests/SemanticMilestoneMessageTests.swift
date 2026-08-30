import Foundation
import ProvenanceEngineContracts
import Testing

@Suite
struct SemanticMilestoneMessageTests {
    @Test
    func rendererCoversMilestoneMessages() throws {
        let activeMilestone = ProvenanceCodingAgentMilestone(
            id: "milestone-1",
            title: "Add milestone payload contracts",
            status: .active,
            order: 1
        )
        let cases: [(ProvenanceCodingAgentMilestonePayload, String, String)] = [
            (
                ProvenanceCodingAgentMilestonePayload(
                    currentMilestoneID: activeMilestone.id,
                    milestones: [
                        ProvenanceCodingAgentMilestone(
                            id: "milestone-0",
                            title: "Inspect existing semantic fields",
                            status: .completed,
                            order: 0
                        ),
                        activeMilestone,
                    ],
                    basis: "current_plan"
                ),
                "Add milestone payload contracts",
                "The current milestone is add milestone payload contracts."
            ),
            (
                ProvenanceCodingAgentMilestonePayload(
                    currentMilestoneID: nil,
                    milestones: [],
                    basis: "insufficient_milestone_evidence",
                    unknownReason: "No bounded plan or submitted prompt evidence is available for this turn."
                ),
                "Milestones unknown",
                "No bounded plan or submitted prompt evidence is available for this turn."
            ),
        ]

        for (index, fixture) in cases.enumerated() {
            let inference = Self.semanticRecord(
                id: "semantic-milestones-\(index)",
                kind: ProvenanceCodingAgentSemanticInferenceKind.milestones.rawValue,
                scope: .session,
                scopeID: "session-1",
                payload: fixture.0.semanticPayloadValue,
                confidence: index == 1 ? .unknown : .medium,
                specificity: index == 1 ? .broad : .scoped
            )
            let message = try #require(ProvenanceSemanticMessageRenderer.record(
                for: inference,
                createdAt: Self.timestamp
            ))

            #expect(message.concisePhrase == fixture.1)
            #expect(message.expandedMeaning == fixture.2)
            #expect(message.structuredSemanticPayload == inference.payload)
        }
    }

    @Test
    func rendererCoversBlockerAndApproachChangeMessages() throws {
        let blockerPayload = ProvenanceCodingAgentBlockerPayload(
            blockers: [ProvenanceCodingAgentBlocker(
                id: "blocker-1",
                description: "Database dependency unavailable",
                affectedActivity: "run integration tests",
                condition: "database dependency unavailable",
                state: .reportedOpen,
                identityBasis: .visibleStatementActivityCondition,
                stateBasis: .visibleAgentStatement
            )],
            basis: "explicit_visible_agent_statement"
        )
        let approachPayload = ProvenanceCodingAgentApproachChangePayload(
            approachChanges: [ProvenanceCodingAgentApproachChange(
                id: "approach-change-1",
                objective: "validate migration behavior",
                priorApproach: "full integration tests",
                replacementApproach: "SQLite fixture coverage",
                reason: "database dependency unavailable",
                state: .reportedReplaced,
                identityBasis: .visibleStatementStrategyTransition,
                stateBasis: .visibleAgentStatement
            )],
            basis: "explicit_visible_agent_statement"
        )
        let cases: [(ProvenanceCodingAgentSemanticInferenceKind, ProvenanceSemanticPayloadValue, String, String)] = [
            (
                .blockers,
                blockerPayload.semanticPayloadValue,
                "Blocked: run integration tests",
                "The provider reported run integration tests is blocked by database dependency unavailable."
            ),
            (
                .approachChanges,
                approachPayload.semanticPayloadValue,
                "Approach replaced",
                "The provider reported replacing full integration tests with SQLite fixture coverage."
            ),
        ]

        for (index, fixture) in cases.enumerated() {
            let inference = Self.semanticRecord(
                id: "semantic-blocker-approach-\(index)",
                kind: fixture.0.rawValue,
                scope: .session,
                scopeID: "session-1",
                payload: fixture.1,
                confidence: .medium,
                specificity: .scoped
            )
            let message = try #require(ProvenanceSemanticMessageRenderer.record(
                for: inference,
                createdAt: Self.timestamp
            ))

            #expect(message.concisePhrase == fixture.2)
            #expect(message.expandedMeaning == fixture.3)
            #expect(message.structuredSemanticPayload == inference.payload)
        }
    }


    private static let timestamp = Date(timeIntervalSince1970: 1_800_000_000)

    private static func semanticRecord(
        id: String,
        kind: String,
        scope: ProvenanceSemanticInferenceScope,
        scopeID: String,
        payload: ProvenanceSemanticPayloadValue,
        confidence: ProvenanceConfidence = .medium,
        specificity: ProvenanceSemanticSpecificity = .granular
    ) -> ProvenanceSemanticInferenceRecord {
        ProvenanceSemanticInferenceRecord(
            id: id,
            kind: kind,
            scope: scope,
            scopeID: scopeID,
            payload: payload,
            supportingEvidenceRefs: [],
            supportingFactualRevision: nil,
            confidence: confidence,
            specificity: specificity,
            producerType: .rule,
            producerID: "semantic-fixture-worker",
            producerVersion: "semantic-fixture-v1",
            createdAt: timestamp
        )
    }
}
