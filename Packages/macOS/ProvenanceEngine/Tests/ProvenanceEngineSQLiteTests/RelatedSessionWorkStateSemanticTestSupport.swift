import Foundation
import ProvenanceEngineContracts
 @testable import ProvenanceEngineSQLite

enum RelatedSessionWorkStateSemanticTestSupport {
    static let expectedSemanticFieldKinds = [
        ProvenanceCodingAgentSemanticInferenceKind.threadIntent.rawValue,
        ProvenanceCodingAgentSemanticInferenceKind.turnIntent.rawValue,
        ProvenanceCodingAgentSemanticInferenceKind.currentActivity.rawValue,
        ProvenanceCodingAgentSemanticInferenceKind.milestones.rawValue,
        ProvenanceCodingAgentSemanticInferenceKind.blockers.rawValue,
        ProvenanceCodingAgentSemanticInferenceKind.approachChanges.rawValue,
        ProvenanceCodingAgentSemanticInferenceKind.sessionPhase.rawValue,
    ]

    static func appendAssistantMessage(
        _ text: String,
        id: String,
        sessionID: String,
        threadID: String,
        turnID: String,
        offset: TimeInterval,
        fixture: RelatedSessionFixture,
        into repository: ProvenanceSQLiteRepository
    ) async throws -> String {
        let assistant = ProvenanceCodingAgentAssistantMessageRecord(
            id: id,
            sessionID: sessionID,
            threadID: threadID,
            turnID: turnID,
            provider: "codex",
            itemID: "item-\(id)",
            text: text,
            completedAt: fixture.time(offset),
            source: .observed,
            confidence: .high
        )
        try await fixture.append(
            eventID: "event-\(id)",
            eventType: .codingAgentAssistantMessageCompleted,
            timestamp: assistant.completedAt,
            repositoryID: nil,
            worktreeID: nil,
            sessionID: assistant.sessionID,
            payload: ProvenanceEventPayload(codingAgentAssistantMessage: assistant),
            into: repository
        )
        return id
    }

    struct SeededWorkStateSessions {
        let fixture: RelatedSessionFixture
        let target: SeededRelatedSession
        let open: SeededRelatedSession
        let bypassed: SeededRelatedSession
        let openEvidenceID: String
        let bypassedResolutionEvidenceID: String
    }

    static func seedWorkStateSessions(
        into repository: ProvenanceSQLiteRepository
    ) async throws -> SeededWorkStateSessions {
        let fixture = RelatedSessionFixture()
        let repo = fixture.repository()
        let worktree = fixture.worktree(
            id: "worktree-work-state",
            repository: repo,
            path: "/repos/work-state",
            branch: "feature/work-state",
            head: "work-state-head",
            offset: 1
        )
        let target = try await RelatedSessionProjectionTestSupport.seedSession(
            id: "session-target",
            status: "active",
            worktree: worktree,
            repository: repo,
            sessionOffset: 10,
            fixture: fixture,
            into: repository
        )
        let open = try await RelatedSessionProjectionTestSupport.seedSession(
            id: "session-open",
            status: "completed",
            worktree: worktree,
            repository: repo,
            sessionOffset: 30,
            fixture: fixture,
            into: repository
        )
        let bypassed = try await RelatedSessionProjectionTestSupport.seedSession(
            id: "session-bypassed",
            status: "completed",
            worktree: worktree,
            repository: repo,
            sessionOffset: 50,
            fixture: fixture,
            into: repository
        )
        let openEvidenceID = try await appendAssistantMessage(
            """
            Blocker: activity=run package suite; condition=database offline
            Approach change: objective=validate persistence; prior=full package suite; replacement=SQLite semantic fixture; state=replaced; reason=database offline
            """,
            id: "assistant-open",
            sessionID: open.session.id,
            threadID: open.thread.id,
            turnID: open.turn.id,
            offset: 38,
            fixture: fixture,
            into: repository
        )
        _ = try await appendAssistantMessage(
            "Blocker: activity=run package suite; condition=database offline",
            id: "assistant-bypassed-open",
            sessionID: bypassed.session.id,
            threadID: bypassed.thread.id,
            turnID: bypassed.turn.id,
            offset: 58,
            fixture: fixture,
            into: repository
        )
        let resolutionEvidenceID = try await appendAssistantMessage(
            "Blocker resolved: activity=run package suite; condition=database offline; outcome=bypassed",
            id: "assistant-bypassed-resolution",
            sessionID: bypassed.session.id,
            threadID: bypassed.thread.id,
            turnID: bypassed.turn.id,
            offset: 59,
            fixture: fixture,
            into: repository
        )
        _ = try await publishSemantics(sessionID: open.session.id, offset: 70, fixture: fixture, into: repository)
        _ = try await publishSemantics(sessionID: bypassed.session.id, offset: 71, fixture: fixture, into: repository)
        return SeededWorkStateSessions(
            fixture: fixture,
            target: target,
            open: open,
            bypassed: bypassed,
            openEvidenceID: openEvidenceID,
            bypassedResolutionEvidenceID: resolutionEvidenceID
        )
    }

    static func publishSemantics(
        sessionID: String,
        turnLimit: Int? = nil,
        offset: TimeInterval,
        fixture: RelatedSessionFixture,
        into repository: ProvenanceSQLiteRepository
    ) async throws -> ProvenanceCodingAgentSessionSemanticInferenceResponse {
        try await repository.publishCodingAgentSessionSemanticInferences(
            ProvenanceCodingAgentSessionSemanticInferenceRequest(
                sessionID: sessionID,
                turnLimit: turnLimit,
                createdAt: fixture.time(offset)
            )
        )
    }

    static func semanticField(
        _ kind: ProvenanceCodingAgentSemanticInferenceKind,
        in brief: ProvenanceRelatedSessionBrief
    ) throws -> ProvenanceSessionWorkModelSemanticField {
        try require(brief.semanticFields.first { $0.kind == kind.rawValue })
    }

    static func availability(
        _ field: String,
        in brief: ProvenanceRelatedSessionBrief
    ) -> ProvenanceRelatedSessionAvailability? {
        brief.completeness.fields.first { $0.field == field }
    }

    static func availability(
        _ kind: ProvenanceCodingAgentSemanticInferenceKind,
        in brief: ProvenanceRelatedSessionBrief
    ) -> ProvenanceRelatedSessionAvailability? {
        availability("semantic_field:\(kind.rawValue)", in: brief)
    }

    static func milestonePayload(
        from brief: ProvenanceRelatedSessionBrief
    ) throws -> ProvenanceCodingAgentMilestonePayload {
        try milestonePayload(from: semanticField(.milestones, in: brief))
    }

    static func milestonePayload(
        from field: ProvenanceSessionWorkModelSemanticField
    ) throws -> ProvenanceCodingAgentMilestonePayload {
        try require(field.record.flatMap {
            ProvenanceCodingAgentMilestonePayload(semanticPayloadValue: $0.payload)
        })
    }

    static func blockerPayload(
        from brief: ProvenanceRelatedSessionBrief
    ) throws -> ProvenanceCodingAgentBlockerPayload {
        try blockerPayload(from: semanticField(.blockers, in: brief))
    }

    static func blockerPayload(
        from field: ProvenanceSessionWorkModelSemanticField
    ) throws -> ProvenanceCodingAgentBlockerPayload {
        try require(field.record.flatMap {
            ProvenanceCodingAgentBlockerPayload(semanticPayloadValue: $0.payload)
        })
    }

    static func approachPayload(
        from brief: ProvenanceRelatedSessionBrief
    ) throws -> ProvenanceCodingAgentApproachChangePayload {
        try approachPayload(from: semanticField(.approachChanges, in: brief))
    }

    static func approachPayload(
        from field: ProvenanceSessionWorkModelSemanticField
    ) throws -> ProvenanceCodingAgentApproachChangePayload {
        try require(field.record.flatMap {
            ProvenanceCodingAgentApproachChangePayload(semanticPayloadValue: $0.payload)
        })
    }

    static func largePlan(
        sessionID: String,
        threadID: String,
        turnID: String,
        observedAt: Date
    ) -> ProvenanceCodingAgentPlanUpdateRecord {
        let steps = (0..<12).map { index in
            ProvenanceCodingAgentPlanStepRecord(
                id: "large-plan-step-\(index)",
                order: index,
                text: "Milestone \(index)",
                status: index == 11 ? "in_progress" : "completed"
            )
        }
        return ProvenanceCodingAgentPlanUpdateRecord(
            id: "large-plan-\(turnID)",
            sessionID: sessionID,
            threadID: threadID,
            turnID: turnID,
            provider: "codex",
            steps: steps,
            observedAt: observedAt,
            source: .observed,
            confidence: .high
        )
    }

    static func partialBlockerRecord(
        id: String? = nil,
        sessionID: String,
        evidenceID: String,
        factualRevision: Int?,
        createdAt: Date,
        supersedes: [String] = []
    ) -> ProvenanceSemanticInferenceRecord {
        let evidence = ProvenanceSemanticEvidenceReference(
            kind: "coding_agent_assistant_message",
            id: evidenceID
        )
        let payload = ProvenanceCodingAgentBlockerPayload(
            blockers: [
                ProvenanceCodingAgentBlocker(
                    id: "blocker-partial-source",
                    description: "older turn omitted",
                    affectedActivity: "rerun validation",
                    condition: "older turn omitted",
                    state: .reportedOpen,
                    identityBasis: .visibleStatementActivityCondition,
                    stateBasis: .visibleAgentStatement,
                    reportedByProvider: "codex",
                    reportedBySource: ProvenanceSource.observed.rawValue,
                    sourceEvidenceRefs: [evidence]
                ),
            ],
            basis: "explicit_visible_agent_statement",
            sourceHistoryState: .partial,
            omissionReasons: ["partial_factual_source_history"]
        )
        return ProvenanceSemanticInferenceRecord(
            id: id ?? "semantic-partial-blocker-\(sessionID)",
            kind: ProvenanceCodingAgentSemanticInferenceKind.blockers.rawValue,
            scope: .session,
            scopeID: sessionID,
            payload: payload.semanticPayloadValue,
            supportingEvidenceRefs: [evidence],
            supportingFactualRevision: factualRevision,
            confidence: .medium,
            specificity: .scoped,
            producerType: .rule,
            producerID: ProvenanceCodingAgentSessionSemanticInferenceProducer.producerID,
            producerVersion: ProvenanceCodingAgentSessionSemanticInferenceProducer.producerVersion,
            createdAt: createdAt,
            supersedes: supersedes
        )
    }

    static func semanticStatementBatch(_ range: Range<Int>) -> String {
        range.flatMap { index in
            [
                "Blocker: activity=task \(index); condition=condition \(index)",
                "Approach change: objective=objective \(index); prior=prior \(index); replacement=replacement \(index); state=replaced",
            ]
        }.joined(separator: "\n")
    }

    static func require<Value>(_ value: Value?) throws -> Value {
        guard let value else {
            throw NSError(domain: "RelatedSessionWorkStateSemanticTestSupport", code: 1)
        }
        return value
    }
}
