import Foundation
import ProvenanceEngineContracts
@testable import ProvenanceEngineSQLite
import Testing

@Suite
struct BlockerApproachChangeInferenceTests {
    @Test
    func explicitStatementsMaterializeThroughPublicSessionWorkModel() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)
        let base = WorkModelFixture()
        let turn = base.turn(status: "completed", completedOffset: 12)
        let message = base.assistantMessage(
            """
            Blocker: activity=run integration tests; condition=database dependency unavailable; description=Integration tests cannot run until the database service is available
            Approach change: objective=validate migration behavior; prior=full integration test suite; replacement=SQLite fixture coverage; state=replaced; reason=database dependency unavailable
            """,
            turnID: turn.id,
            offset: 10
        )

        try await base.appendSessionThreadAndTurn(turn, into: repository)
        try await base.append(message, into: repository)
        let published = try await repository.publishCodingAgentSessionSemanticInferences(
            ProvenanceCodingAgentSessionSemanticInferenceRequest(
                sessionID: base.session.id,
                createdAt: base.timestamp.addingTimeInterval(20)
            )
        )
        let model = try #require(try await repository.sessionWorkModel(
            ProvenanceSessionWorkModelRequest(sessionID: base.session.id)
        ).model)
        let blockerRecord = try #require(model.blockers.record)
        let approachRecord = try #require(model.approachChanges.record)
        let blockerPayload = try Self.blockerPayload(from: blockerRecord)
        let approachPayload = try Self.approachPayload(from: approachRecord)
        let blocker = try #require(blockerPayload.blockers.first)
        let approachChange = try #require(approachPayload.approachChanges.first)

        #expect(published.publishedInferenceIDs.count == 7)
        #expect(model.blockers.state == .known)
        #expect(model.approachChanges.state == .known)
        #expect(blockerPayload.basis == "explicit_visible_agent_statement")
        #expect(blockerPayload.sourceHistoryState == .complete)
        #expect(blockerPayload.unknownReason == nil)
        #expect(blocker.description == "Integration tests cannot run until the database service is available")
        #expect(blocker.affectedActivity == "run integration tests")
        #expect(blocker.condition == "database dependency unavailable")
        #expect(blocker.affectedMilestoneID == nil)
        #expect(blocker.state == .reportedOpen)
        #expect(blocker.identityBasis == .visibleStatementActivityCondition)
        #expect(blocker.stateBasis == .visibleAgentStatement)
        #expect(blocker.reportedByProvider == "codex")
        #expect(blocker.reportedBySource == ProvenanceSource.observed.rawValue)
        #expect(blocker.sourceEvidenceRefs.contains { $0.kind == "coding_agent_assistant_message" && $0.id == message.id })
        #expect(blockerRecord.supportingFactualRevision == model.revision.factualRevision)
        #expect(blockerRecord.producerVersion == ProvenanceCodingAgentSessionSemanticInferenceProducer.producerVersion)
        #expect(blockerRecord.confidence == .medium)
        #expect(blockerRecord.specificity == .scoped)

        #expect(approachPayload.basis == "explicit_visible_agent_statement")
        #expect(approachPayload.sourceHistoryState == .complete)
        #expect(approachPayload.unknownReason == nil)
        #expect(approachChange.objective == "validate migration behavior")
        #expect(approachChange.priorApproach == "full integration test suite")
        #expect(approachChange.replacementApproach == "SQLite fixture coverage")
        #expect(approachChange.reason == "database dependency unavailable")
        #expect(approachChange.state == .reportedReplaced)
        #expect(approachChange.identityBasis == .visibleStatementStrategyTransition)
        #expect(approachChange.stateBasis == .visibleAgentStatement)
        #expect(approachChange.reportedByProvider == "codex")
        #expect(approachChange.reportedBySource == ProvenanceSource.observed.rawValue)
        #expect(approachChange.sourceEvidenceRefs.contains {
            $0.kind == "coding_agent_assistant_message" && $0.id == message.id
        })
        #expect(approachRecord.supportingFactualRevision == model.revision.factualRevision)
        #expect(approachRecord.producerVersion == ProvenanceCodingAgentSessionSemanticInferenceProducer.producerVersion)
        #expect(approachRecord.confidence == .medium)
        #expect(approachRecord.specificity == .scoped)
    }

    @Test
    func visibleReasoningSummaryStatementsMaterializeWithSourceAttribution() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)
        let base = WorkModelFixture()
        let turn = base.turn(status: "completed", completedOffset: 12)
        let summary = base.reasoning(
            """
            Blocker: activity=validate migrations; condition=database dependency unavailable
            Approach change: objective=validate migrations; prior=remote integration suite; replacement=SQLite fixture coverage; state=replaced; reason=database dependency unavailable
            """,
            turnID: turn.id,
            offset: 8
        )

        try await base.appendSessionThreadAndTurn(turn, into: repository)
        try await base.append(summary, into: repository)
        _ = try await repository.publishCodingAgentSessionSemanticInferences(
            ProvenanceCodingAgentSessionSemanticInferenceRequest(
                sessionID: base.session.id,
                createdAt: base.timestamp.addingTimeInterval(20)
            )
        )
        let model = try #require(try await repository.sessionWorkModel(
            ProvenanceSessionWorkModelRequest(sessionID: base.session.id)
        ).model)
        let blockerRecord = try #require(model.blockers.record)
        let approachRecord = try #require(model.approachChanges.record)
        let blocker = try #require(try Self.blockerPayload(from: blockerRecord).blockers.first)
        let approach = try #require(try Self.approachPayload(from: approachRecord).approachChanges.first)

        #expect(blocker.sourceEvidenceRefs == [.init(kind: "coding_agent_reasoning_summary", id: summary.id)])
        #expect(approach.sourceEvidenceRefs == [.init(kind: "coding_agent_reasoning_summary", id: summary.id)])
        #expect(blocker.reportedBySource == ProvenanceSource.observed.rawValue)
        #expect(approach.reportedByProvider == "codex")
    }

    @Test
    func failedCommandsWarningsCompletedTurnsAndReorderedPlansAbstain() throws {
        let base = FixtureBase()
        let turn = base.turn(status: "completed", completedOffset: 12)
        let plan = base.plan(
            steps: [
                (text: "Run integration tests", status: "pending"),
                (text: "Inspect logs", status: "completed"),
            ],
            turnID: turn.id,
            offset: 5
        )
        let failedCommand = base.command(
            "swift test --package-path Packages/macOS/ProvenanceEngine",
            status: "failed",
            exitCode: 1,
            turnID: turn.id,
            offset: 8
        )
        let warning = Self.assistantMessage(
            "The command failed and emitted warnings; I will retry after reordering the plan.",
            id: "assistant-warning",
            turnID: turn.id,
            base: base,
            offset: 9
        )
        let snapshot = base.snapshot(turns: [Self.turnSnapshot(
            base: base,
            turn: turn,
            plan: plan,
            commands: [failedCommand],
            assistantMessages: [warning]
        )])

        let records = ProvenanceCodingAgentSessionSemanticInferenceProducer.records(
            for: snapshot,
            createdAt: base.timestamp.addingTimeInterval(20)
        )
        let blockerPayload = try Self.blockerPayload(.blockers, from: records, sessionID: base.session.id)
        let approachPayload = try Self.approachPayload(.approachChanges, from: records, sessionID: base.session.id)

        #expect(blockerPayload.blockers.isEmpty)
        #expect(blockerPayload.unknownReason != nil)
        #expect(approachPayload.approachChanges.isEmpty)
        #expect(approachPayload.unknownReason != nil)
    }

    @Test
    func unsupportedLanguageContextsAbstain() throws {
        let base = FixtureBase()
        let turn = base.turn(status: "completed", completedOffset: 12)
        let fence = String(repeating: String(UnicodeScalar(96)!), count: 3)
        let message = Self.assistantMessage(
            """
            Blocker: activity=run tests; condition=is the database blocked?
            Blocker: activity=run tests; condition=not blocked
            Approach change: objective=validate persistence; prior=integration tests; state=replaced
            Hypothetical Blocker: activity=ship; condition=approval pending
            \(fence)
            Blocker: activity=quoted example; condition=do not parse code fences
            \(fence)
            """,
            id: "assistant-unsupported",
            turnID: turn.id,
            base: base,
            offset: 8
        )
        let snapshot = base.snapshot(turns: [Self.turnSnapshot(
            base: base,
            turn: turn,
            assistantMessages: [message]
        )])

        let records = ProvenanceCodingAgentSessionSemanticInferenceProducer.records(
            for: snapshot,
            createdAt: base.timestamp.addingTimeInterval(20)
        )
        let blockerPayload = try Self.blockerPayload(.blockers, from: records, sessionID: base.session.id)
        let approachPayload = try Self.approachPayload(.approachChanges, from: records, sessionID: base.session.id)

        #expect(blockerPayload.blockers.isEmpty)
        #expect(blockerPayload.omissionReasons.contains("unsupported_blocker_statement_context"))
        #expect(approachPayload.approachChanges.isEmpty)
        #expect(approachPayload.omissionReasons.contains("replacement_approach_required_for_reported_replacement"))
    }

    @Test
    func blockerResolutionBypassRecurrenceAndMultipleBlockersStayIndependent() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)
        let base = WorkModelFixture()
        let firstTurn = base.turn(
            id: "turn-blockers-1",
            providerTurnID: "provider-turn-blockers-1",
            status: "completed",
            completedOffset: 12
        )
        let firstMessage = base.assistantMessage(
            """
            Blocker: activity=run integration tests; condition=database offline; description=Integration tests cannot run while the database is offline
            Blocker: activity=ship release; condition=signing key unavailable; description=Release signing cannot proceed without the key
            """,
            turnID: firstTurn.id,
            offset: 8
        )

        try await base.appendSessionThreadAndTurn(firstTurn, into: repository)
        try await base.append(firstMessage, into: repository)
        _ = try await repository.publishCodingAgentSessionSemanticInferences(
            ProvenanceCodingAgentSessionSemanticInferenceRequest(
                sessionID: base.session.id,
                createdAt: base.timestamp.addingTimeInterval(20)
            )
        )
        let firstPayload = try await Self.currentBlockerPayload(repository: repository, sessionID: base.session.id)
        let originalIntegrationBlocker = try #require(firstPayload.blockers.first {
            $0.affectedActivity == "run integration tests"
        })
        let originalIntegrationBlockerID = originalIntegrationBlocker.id

        let secondTurn = base.turn(
            id: "turn-blockers-2",
            providerTurnID: "provider-turn-blockers-2",
            status: "completed",
            startOffset: 20,
            completedOffset: 28
        )
        let resolutionMessage = base.assistantMessage(
            "Blocker resolved: activity=run integration tests; condition=database offline; outcome=bypassed; description=Using SQLite fixtures until the database is restored",
            turnID: secondTurn.id,
            offset: 24
        )

        try await base.append(secondTurn, into: repository)
        try await base.append(resolutionMessage, into: repository)
        _ = try await repository.publishCodingAgentSessionSemanticInferences(
            ProvenanceCodingAgentSessionSemanticInferenceRequest(
                sessionID: base.session.id,
                createdAt: base.timestamp.addingTimeInterval(30)
            )
        )
        let resolvedPayload = try await Self.currentBlockerPayload(repository: repository, sessionID: base.session.id)
        let bypassed = try #require(resolvedPayload.blockers.first { $0.affectedActivity == "run integration tests" })
        let signing = try #require(resolvedPayload.blockers.first { $0.affectedActivity == "ship release" })

        #expect(bypassed.id == originalIntegrationBlockerID)
        #expect(bypassed.state == .reportedBypassed)
        #expect(bypassed.stateBasis == .visibleAgentResolutionStatement)
        #expect(signing.state == .reportedOpen)

        let thirdTurn = base.turn(
            id: "turn-blockers-3",
            providerTurnID: "provider-turn-blockers-3",
            status: "completed",
            startOffset: 32,
            completedOffset: 38
        )
        let recurrenceMessage = base.assistantMessage(
            "Blocker: activity=run integration tests; condition=database offline; description=Cloud database is offline again",
            turnID: thirdTurn.id,
            offset: 36
        )

        try await base.append(thirdTurn, into: repository)
        try await base.append(recurrenceMessage, into: repository)
        _ = try await repository.publishCodingAgentSessionSemanticInferences(
            ProvenanceCodingAgentSessionSemanticInferenceRequest(
                sessionID: base.session.id,
                createdAt: base.timestamp.addingTimeInterval(40)
            )
        )
        let recurrencePayload = try await Self.currentBlockerPayload(repository: repository, sessionID: base.session.id)
        let recurrence = try #require(recurrencePayload.blockers.first { $0.affectedActivity == "run integration tests" })
        let history = try await repository.semanticInferences(ProvenanceSemanticInferenceQueryRequest(
            scope: .session,
            scopeID: base.session.id,
            kind: ProvenanceCodingAgentSemanticInferenceKind.blockers.rawValue,
            includeInactive: true
        ))
        let historicalPayloads = try history.records.map { try Self.blockerPayload(from: $0) }

        #expect(recurrence.state == .reportedOpen)
        #expect(recurrence.id != originalIntegrationBlockerID)
        #expect(recurrencePayload.blockers.first { $0.affectedActivity == "ship release" }?.state == .reportedOpen)
        #expect(history.records.first?.status == .active)
        #expect(history.records.contains { $0.status == .superseded })
        #expect(historicalPayloads.contains { payload in
            payload.blockers.contains {
                $0.id == originalIntegrationBlockerID && $0.state == .reportedBypassed
            }
        })
    }

    @Test
    func partialSourceHistoryDoesNotClearPriorBlocker() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)
        let base = WorkModelFixture()
        let firstTurn = base.turn(
            id: "turn-partial-1",
            providerTurnID: "provider-turn-partial-1",
            status: "completed",
            completedOffset: 12
        )
        let blockerMessage = base.assistantMessage(
            "Blocker: activity=run integration tests; condition=database offline",
            turnID: firstTurn.id,
            offset: 8
        )

        try await base.appendSessionThreadAndTurn(firstTurn, into: repository)
        try await base.append(blockerMessage, into: repository)
        _ = try await repository.publishCodingAgentSessionSemanticInferences(
            ProvenanceCodingAgentSessionSemanticInferenceRequest(
                sessionID: base.session.id,
                createdAt: base.timestamp.addingTimeInterval(20)
            )
        )
        let firstRecordID = try #require(try await repository.sessionWorkModel(
            ProvenanceSessionWorkModelRequest(sessionID: base.session.id)
        ).model?.blockers.record?.inferenceID)

        let secondTurn = base.turn(
            id: "turn-partial-2",
            providerTurnID: "provider-turn-partial-2",
            status: "completed",
            startOffset: 20,
            completedOffset: 24
        )
        try await base.append(secondTurn, into: repository)
        let limited = try await repository.publishCodingAgentSessionSemanticInferences(
            ProvenanceCodingAgentSessionSemanticInferenceRequest(
                sessionID: base.session.id,
                turnLimit: 0,
                createdAt: base.timestamp.addingTimeInterval(30)
            )
        )
        let model = try #require(try await repository.sessionWorkModel(
            ProvenanceSessionWorkModelRequest(sessionID: base.session.id)
        ).model)
        let retainedPayload = try Self.blockerPayload(from: try #require(model.blockers.record))

        #expect(limited.unchangedInferenceIDs.contains(firstRecordID))
        #expect(model.blockers.record?.inferenceID == firstRecordID)
        #expect(retainedPayload.blockers.map(\.state) == [.reportedOpen])
        #expect(retainedPayload.blockers.first?.affectedActivity == "run integration tests")
    }

    private static func currentBlockerPayload(
        repository: ProvenanceSQLiteRepository,
        sessionID: String
    ) async throws -> ProvenanceCodingAgentBlockerPayload {
        let model = try #require(try await repository.sessionWorkModel(
            ProvenanceSessionWorkModelRequest(sessionID: sessionID)
        ).model)
        return try blockerPayload(from: try #require(model.blockers.record))
    }

    private static func blockerPayload(
        _ kind: ProvenanceCodingAgentSemanticInferenceKind,
        from records: [ProvenanceSemanticInferenceRecord],
        sessionID: String
    ) throws -> ProvenanceCodingAgentBlockerPayload {
        try blockerPayload(from: record(kind, from: records, sessionID: sessionID))
    }

    private static func blockerPayload(
        from record: ProvenanceSessionWorkModelSemanticRecord
    ) throws -> ProvenanceCodingAgentBlockerPayload {
        try #require(ProvenanceCodingAgentBlockerPayload(semanticPayloadValue: record.payload))
    }

    private static func blockerPayload(
        from record: ProvenanceSemanticInferenceRecord
    ) throws -> ProvenanceCodingAgentBlockerPayload {
        try #require(ProvenanceCodingAgentBlockerPayload(semanticPayloadValue: record.payload))
    }

    private static func approachPayload(
        _ kind: ProvenanceCodingAgentSemanticInferenceKind,
        from records: [ProvenanceSemanticInferenceRecord],
        sessionID: String
    ) throws -> ProvenanceCodingAgentApproachChangePayload {
        try approachPayload(from: record(kind, from: records, sessionID: sessionID))
    }

    private static func approachPayload(
        from record: ProvenanceSessionWorkModelSemanticRecord
    ) throws -> ProvenanceCodingAgentApproachChangePayload {
        try #require(ProvenanceCodingAgentApproachChangePayload(semanticPayloadValue: record.payload))
    }

    private static func approachPayload(
        from record: ProvenanceSemanticInferenceRecord
    ) throws -> ProvenanceCodingAgentApproachChangePayload {
        try #require(ProvenanceCodingAgentApproachChangePayload(semanticPayloadValue: record.payload))
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
        prompt: ProvenanceCodingAgentPromptRecord? = nil,
        plan: ProvenanceCodingAgentPlanUpdateRecord? = nil,
        commands: [ProvenanceCodingAgentCommandRecord] = [],
        reasoningSummaries: [ProvenanceCodingAgentReasoningSummaryRecord] = [],
        assistantMessages: [ProvenanceCodingAgentAssistantMessageRecord] = []
    ) -> ProvenanceFactualSessionProjectionTurnSnapshot {
        ProvenanceFactualSessionProjectionTurnSnapshot(
            turn: turn,
            submittedPrompt: prompt,
            currentPlan: plan,
            completedCommands: commands,
            visibleReasoningSummaries: reasoningSummaries,
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
            .appendingPathComponent("provenance-engine-blocker-approach-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("provenance.sqlite")
    }

    private static func removeTemporaryDatabaseDirectory(for url: URL) {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }
}
