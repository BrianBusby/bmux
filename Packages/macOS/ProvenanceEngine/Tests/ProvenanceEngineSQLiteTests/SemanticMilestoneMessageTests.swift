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


    @Test
    func blockerRendererPrefersOpenBlockerOverEarlierResolvedItem() throws {
        let payload = ProvenanceCodingAgentBlockerPayload(
            blockers: [
                ProvenanceCodingAgentBlocker(
                    id: "blocker-cleared",
                    description: "Database recovered",
                    affectedActivity: "run integration tests",
                    condition: "database dependency unavailable",
                    state: .reportedCleared
                ),
                ProvenanceCodingAgentBlocker(
                    id: "blocker-open",
                    description: "Signing key unavailable",
                    affectedActivity: "ship release",
                    condition: "signing key unavailable",
                    state: .reportedOpen
                ),
            ],
            basis: "explicit_visible_agent_statement"
        )
        let inference = Self.semanticRecord(
            id: "semantic-blocker-selection",
            kind: ProvenanceCodingAgentSemanticInferenceKind.blockers.rawValue,
            scope: .session,
            scopeID: "session-1",
            payload: payload.semanticPayloadValue,
            confidence: .medium,
            specificity: .scoped
        )

        let message = try #require(ProvenanceSemanticMessageRenderer.record(
            for: inference,
            createdAt: Self.timestamp
        ))

        #expect(message.concisePhrase == "Blocked: ship release")
        #expect(message.expandedMeaning == "The provider reported ship release is blocked by signing key unavailable.")
    }

    @Test
    func blockerAndApproachMessagesUsePresentationPolicyLocale() throws {
        let policy = ProvenanceSemanticMessagePresentationPolicy(localeIdentifier: "ja-JP")
        let blockerPayload = ProvenanceCodingAgentBlockerPayload(
            blockers: [ProvenanceCodingAgentBlocker(
                id: "blocker-ja",
                description: "Database dependency unavailable",
                affectedActivity: "run integration tests",
                condition: "database dependency unavailable",
                state: .reportedOpen
            )],
            basis: "explicit_visible_agent_statement"
        )
        let approachPayload = ProvenanceCodingAgentApproachChangePayload(
            approachChanges: [ProvenanceCodingAgentApproachChange(
                id: "approach-change-ja",
                objective: "validate migration behavior",
                priorApproach: "full integration tests",
                replacementApproach: "SQLite fixture coverage",
                state: .reportedReplaced
            )],
            basis: "explicit_visible_agent_statement"
        )
        let blockerInference = Self.semanticRecord(
            id: "semantic-blocker-ja",
            kind: ProvenanceCodingAgentSemanticInferenceKind.blockers.rawValue,
            scope: .session,
            scopeID: "session-1",
            payload: blockerPayload.semanticPayloadValue,
            confidence: .medium,
            specificity: .scoped
        )
        let approachInference = Self.semanticRecord(
            id: "semantic-approach-ja",
            kind: ProvenanceCodingAgentSemanticInferenceKind.approachChanges.rawValue,
            scope: .session,
            scopeID: "session-1",
            payload: approachPayload.semanticPayloadValue,
            confidence: .medium,
            specificity: .scoped
        )

        let blockerMessage = try #require(ProvenanceSemanticMessageRenderer.record(
            for: blockerInference,
            presentationPolicy: policy,
            createdAt: Self.timestamp
        ))
        let approachMessage = try #require(ProvenanceSemanticMessageRenderer.record(
            for: approachInference,
            presentationPolicy: policy,
            createdAt: Self.timestamp
        ))

        #expect(blockerMessage.localeIdentifier == "ja-JP")
        #expect(blockerMessage.concisePhrase == "ブロック中: run integration tests")
        #expect(blockerMessage.expandedMeaning == "プロバイダーはrun integration testsがdatabase dependency unavailableによってブロックされていると報告しました。")
        #expect(approachMessage.localeIdentifier == "ja-JP")
        #expect(approachMessage.concisePhrase == "アプローチ置換済み")
        #expect(approachMessage.expandedMeaning == "プロバイダーはfull integration testsをSQLite fixture coverageに置き換えると報告しました。")
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
