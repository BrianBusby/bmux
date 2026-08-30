import Foundation
import ProvenanceEngineContracts
@testable import ProvenanceEngineSQLite
import Testing

@Suite
struct BlockerApproachChangeCompatibilityTests {
    @Test
    func milestoneLinksRequireExactCurrentSessionMilestoneIDs() throws {
        let base = FixtureBase()
        let turn = base.turn(status: "completed", completedOffset: 14)
        let plan = base.plan(
            steps: [
                (text: "Implement blocker semantics", status: "in_progress"),
                (text: "Validate approach changes", status: "pending"),
            ],
            turnID: turn.id,
            offset: 5
        )
        let initialSnapshot = base.snapshot(turns: [Self.turnSnapshot(base: base, turn: turn, plan: plan)])
        let initialRecords = ProvenanceCodingAgentSessionSemanticInferenceProducer.records(
            for: initialSnapshot,
            createdAt: base.timestamp.addingTimeInterval(20)
        )
        let milestonePayload = try #require(ProvenanceCodingAgentMilestonePayload(
            semanticPayloadValue: try Self.record(.milestones, from: initialRecords, sessionID: base.session.id).payload
        ))
        let milestoneID = try #require(milestonePayload.currentMilestoneID)
        let message = Self.assistantMessage(
            """
            Blocker: activity=finish milestone; condition=fixture corpus incomplete; milestone=\(milestoneID)
            Approach change: objective=finish milestone; prior=manual fixture enumeration; replacement=structured fixture corpus; state=replaced; reason=coverage gaps; milestone=\(milestoneID)
            Blocker: activity=title linked work; condition=title references are unsupported; milestone=title:Implement blocker semantics
            Blocker: activity=foreign linked work; condition=foreign milestone is out of scope; milestone=foreign-milestone
            """,
            id: "assistant-milestone-links",
            turnID: turn.id,
            base: base,
            offset: 9
        )
        let snapshot = base.snapshot(turns: [Self.turnSnapshot(
            base: base,
            turn: turn,
            plan: plan,
            assistantMessages: [message]
        )])

        let records = ProvenanceCodingAgentSessionSemanticInferenceProducer.records(
            for: snapshot,
            createdAt: base.timestamp.addingTimeInterval(30)
        )
        let blockerPayload = try Self.blockerPayload(.blockers, from: records, sessionID: base.session.id)
        let approachPayload = try Self.approachPayload(.approachChanges, from: records, sessionID: base.session.id)
        let linkedBlocker = try #require(blockerPayload.blockers.first { $0.affectedActivity == "finish milestone" })
        let linkedApproach = try #require(approachPayload.approachChanges.first)

        #expect(linkedBlocker.affectedMilestoneID == milestoneID)
        #expect(linkedBlocker.identityBasis == .visibleStatementActivityConditionMilestone)
        #expect(linkedApproach.affectedMilestoneID == milestoneID)
        #expect(linkedApproach.identityBasis == .visibleStatementStrategyTransitionMilestone)
        #expect(blockerPayload.blockers.first { $0.affectedActivity == "title linked work" }?.affectedMilestoneID == nil)
        #expect(blockerPayload.blockers.first { $0.affectedActivity == "foreign linked work" }?.affectedMilestoneID == nil)
        #expect(blockerPayload.omissionReasons.contains("milestone_title_link_unsupported"))
        #expect(blockerPayload.omissionReasons.contains("milestone_reference_unresolved_or_out_of_scope"))
    }

    @Test
    func oldSessionWorkModelPayloadDefaultsNewFieldsToUnknown() throws {
        let base = WorkModelFixture()
        let snapshot = ProvenanceFactualSessionProjectionSnapshot(
            revision: 7,
            session: base.session,
            providerThreadIdentities: [ProvenanceFactualSessionProjectionProviderThreadIdentity(thread: base.thread)],
            providerThreads: [base.thread],
            turns: []
        )
        let identity = ProvenanceSessionWorkModelIdentity(
            session: base.session,
            providerThreadIdentities: [ProvenanceFactualSessionProjectionProviderThreadIdentity(thread: base.thread)]
        )
        let model = ProvenanceSessionWorkModel(
            schemaVersion: 2,
            revision: ProvenanceSessionWorkModelRevision(
                schemaVersion: 2,
                factualRevision: 7,
                semanticInferenceIDs: [],
                latestSemanticInferenceCreatedAt: nil
            ),
            identity: identity,
            thread: nil,
            currentTurn: nil,
            priorTurns: [],
            milestones: ProvenanceSessionWorkModelSemanticField(
                kind: ProvenanceCodingAgentSemanticInferenceKind.milestones.rawValue,
                scope: .session,
                scopeID: base.session.id,
                state: .unknown,
                reason: "no_active_semantic_inference"
            ),
            sessionPhase: ProvenanceSessionWorkModelSemanticField(
                kind: ProvenanceCodingAgentSemanticInferenceKind.sessionPhase.rawValue,
                scope: .session,
                scopeID: base.session.id,
                state: .unknown,
                reason: "no_active_semantic_inference"
            ),
            basis: ProvenanceSessionWorkModelBasis(
                factualSessionProjection: snapshot,
                semanticInferenceRecords: []
            )
        )
        let encoded = try JSONEncoder().encode(model)
        var object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "blockers")
        object.removeValue(forKey: "approachChanges")
        let legacyData = try JSONSerialization.data(withJSONObject: object)

        let decoded = try JSONDecoder().decode(ProvenanceSessionWorkModel.self, from: legacyData)

        #expect(decoded.schemaVersion == 2)
        #expect(decoded.revision.schemaVersion == 2)
        #expect(decoded.blockers.state == .unknown)
        #expect(decoded.blockers.kind == ProvenanceCodingAgentSemanticInferenceKind.blockers.rawValue)
        #expect(decoded.blockers.scopeID == base.session.id)
        #expect(decoded.approachChanges.state == .unknown)
        #expect(decoded.approachChanges.kind == ProvenanceCodingAgentSemanticInferenceKind.approachChanges.rawValue)
        #expect(decoded.approachChanges.scopeID == base.session.id)
    }

    @Test
    func semanticBlockersDoNotEnterFactualOutcomeProjections() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)
        let base = WorkModelFixture()
        let turn = base.turn(status: "completed", completedOffset: 12)
        let message = base.assistantMessage(
            """
            Blocker: activity=run integration tests; condition=database dependency unavailable
            Approach change: objective=validate migration behavior; prior=full integration tests; replacement=SQLite fixture coverage; state=replaced; reason=database dependency unavailable
            """,
            turnID: turn.id,
            offset: 8
        )

        try await base.appendSessionThreadAndTurn(turn, into: repository)
        try await base.append(message, into: repository)
        let factualBefore = try await repository.factualSessionProjection(
            ProvenanceFactualSessionProjectionRequest(sessionID: base.session.id)
        )
        _ = try await repository.publishCodingAgentSessionSemanticInferences(
            ProvenanceCodingAgentSessionSemanticInferenceRequest(
                sessionID: base.session.id,
                createdAt: base.timestamp.addingTimeInterval(20)
            )
        )
        let factualAfter = try await repository.factualSessionProjection(
            ProvenanceFactualSessionProjectionRequest(sessionID: base.session.id)
        )
        let turnOutcome = try #require(try await repository.turnOutcome(
            ProvenanceTurnOutcomeRequest(turnID: turn.id)
        ).outcome)
        let sessionOutcome = try #require(try await repository.sessionOutcome(
            ProvenanceSessionOutcomeRequest(sessionID: base.session.id)
        ).outcome)

        #expect(factualAfter == factualBefore)
        #expect(turnOutcome.blockers.isEmpty)
        #expect(turnOutcome.decisions.isEmpty)
        #expect(sessionOutcome.blockers.isEmpty)
        #expect(sessionOutcome.decisions.isEmpty)
    }

    private static func blockerPayload(
        _ kind: ProvenanceCodingAgentSemanticInferenceKind,
        from records: [ProvenanceSemanticInferenceRecord],
        sessionID: String
    ) throws -> ProvenanceCodingAgentBlockerPayload {
        let inference = try record(kind, from: records, sessionID: sessionID)
        return try #require(ProvenanceCodingAgentBlockerPayload(
            semanticPayloadValue: inference.payload
        ))
    }

    private static func approachPayload(
        _ kind: ProvenanceCodingAgentSemanticInferenceKind,
        from records: [ProvenanceSemanticInferenceRecord],
        sessionID: String
    ) throws -> ProvenanceCodingAgentApproachChangePayload {
        let inference = try record(kind, from: records, sessionID: sessionID)
        return try #require(ProvenanceCodingAgentApproachChangePayload(
            semanticPayloadValue: inference.payload
        ))
    }

    private static func record(
        _ kind: ProvenanceCodingAgentSemanticInferenceKind,
        from records: [ProvenanceSemanticInferenceRecord],
        sessionID: String
    ) throws -> ProvenanceSemanticInferenceRecord {
        try #require(records.first {
            $0.kind == kind.rawValue && $0.scope == .session && $0.scopeID == sessionID
        })
    }

    private static func turnSnapshot(
        base _: FixtureBase,
        turn: ProvenanceCodingAgentTurnRecord,
        plan: ProvenanceCodingAgentPlanUpdateRecord? = nil,
        assistantMessages: [ProvenanceCodingAgentAssistantMessageRecord] = []
    ) -> ProvenanceFactualSessionProjectionTurnSnapshot {
        ProvenanceFactualSessionProjectionTurnSnapshot(
            turn: turn,
            submittedPrompt: nil,
            currentPlan: plan,
            completedCommands: [],
            visibleReasoningSummaries: [],
            fileChangeAttributions: [],
            assistantMessages: assistantMessages
        )
    }

    private static func assistantMessage(
        _ text: String,
        id: String,
        turnID: String,
        base: FixtureBase,
        offset: TimeInterval
    ) -> ProvenanceCodingAgentAssistantMessageRecord {
        ProvenanceCodingAgentAssistantMessageRecord(
            id: id,
            sessionID: base.session.id,
            threadID: base.thread.id,
            provider: "codex",
            itemID: "item-\(id)",
            text: text,
            completedAt: base.timestamp.addingTimeInterval(offset),
            source: .observed,
            confidence: .high
        )
    }

    private static func temporaryDatabaseURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("provenance-engine-blocker-approach-compatibility-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("provenance.sqlite")
    }

    private static func removeTemporaryDatabaseDirectory(for url: URL) {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }
}
