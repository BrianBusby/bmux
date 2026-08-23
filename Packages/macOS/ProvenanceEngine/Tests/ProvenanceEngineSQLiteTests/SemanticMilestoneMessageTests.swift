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
