import Foundation
import ProvenanceEngineContracts
@testable import ProvenanceEngineSQLite
import Testing

@Suite
struct BlockerApproachChangePartialMergeTests {
    @Test
    func partialHistoryOpenAfterBypassCreatesNewBlockerEpisode() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)
        let base = WorkModelFixture()
        let firstTurn = base.turn(
            id: "turn-partial-recurrence-1",
            providerTurnID: "provider-turn-partial-recurrence-1",
            status: "completed",
            completedOffset: 12
        )
        let initialMessage = base.assistantMessage(
            "Blocker: activity=run integration tests; condition=database offline",
            turnID: firstTurn.id,
            offset: 8
        )

        try await base.appendSessionThreadAndTurn(firstTurn, into: repository)
        try await base.append(initialMessage, into: repository)
        _ = try await Self.publish(repository: repository, base: base, offset: 20)
        let initialPayload = try await Self.currentBlockerPayload(repository: repository, sessionID: base.session.id)
        let original = try #require(initialPayload.blockers.first)

        let secondTurn = base.turn(
            id: "turn-partial-recurrence-2",
            providerTurnID: "provider-turn-partial-recurrence-2",
            status: "completed",
            startOffset: 20,
            completedOffset: 24
        )
        let resolutionMessage = base.assistantMessage(
            "Blocker resolved: activity=run integration tests; condition=database offline; outcome=bypassed",
            turnID: secondTurn.id,
            offset: 22
        )

        try await base.append(secondTurn, into: repository)
        try await base.append(resolutionMessage, into: repository)
        _ = try await Self.publish(repository: repository, base: base, offset: 30)
        let resolvedPayload = try await Self.currentBlockerPayload(repository: repository, sessionID: base.session.id)
        let resolved = try #require(resolvedPayload.blockers.first)
        #expect(resolved.id == original.id)
        #expect(resolved.state == .reportedBypassed)

        let thirdTurn = base.turn(
            id: "turn-partial-recurrence-3",
            providerTurnID: "provider-turn-partial-recurrence-3",
            status: "completed",
            startOffset: 30,
            completedOffset: 34
        )
        let recurrenceMessage = base.assistantMessage(
            "Blocker: activity=run integration tests; condition=database offline",
            turnID: thirdTurn.id,
            offset: 32
        )

        try await base.append(thirdTurn, into: repository)
        try await base.append(recurrenceMessage, into: repository)
        _ = try await Self.publish(repository: repository, base: base, turnLimit: 1, offset: 40)
        let recurrencePayload = try await Self.currentBlockerPayload(repository: repository, sessionID: base.session.id)
        let recurrentBlockers = recurrencePayload.blockers.filter {
            $0.affectedActivity == "run integration tests"
        }

        #expect(recurrentBlockers.map(\.state) == [.reportedBypassed, .reportedOpen])
        #expect(recurrentBlockers.map(\.id).contains(original.id))
        #expect(Set(recurrentBlockers.map(\.id)).count == 2)
        #expect(recurrencePayload.omissionReasons.contains("partial_source_history_retained_prior_blockers"))
    }

    @Test
    func partialHistoryMergesRemainBoundedAndKeepNewCandidates() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)
        let base = WorkModelFixture()
        let oldestTurn = base.turn(
            id: "turn-partial-bound-oldest",
            providerTurnID: "provider-turn-partial-bound-oldest",
            status: "completed",
            completedOffset: 12
        )
        let oldestMessage = base.assistantMessage(
            Self.semanticStatementBatch(0..<(ProvenanceCodingAgentSessionSemanticInferenceProducer.maximumBlockersPerSession - 1)),
            turnID: oldestTurn.id,
            offset: 8
        )
        let extraExistingIndex = ProvenanceCodingAgentSessionSemanticInferenceProducer.maximumBlockersPerSession - 1
        let extraExistingTurn = base.turn(
            id: "turn-partial-bound-extra-existing",
            providerTurnID: "provider-turn-partial-bound-extra-existing",
            status: "completed",
            startOffset: 14,
            completedOffset: 16
        )
        let extraExistingMessage = base.assistantMessage(
            Self.semanticStatementBatch(extraExistingIndex..<(extraExistingIndex + 1)),
            turnID: extraExistingTurn.id,
            offset: 15
        )

        try await base.appendSessionThreadAndTurn(oldestTurn, into: repository)
        try await base.append(oldestMessage, into: repository)
        try await base.append(extraExistingTurn, into: repository)
        try await base.append(extraExistingMessage, into: repository)
        _ = try await Self.publish(repository: repository, base: base, offset: 20)

        let nextIndex = ProvenanceCodingAgentSessionSemanticInferenceProducer.maximumBlockersPerSession
        let partialTurn = base.turn(
            id: "turn-partial-bound-2",
            providerTurnID: "provider-turn-partial-bound-2",
            status: "completed",
            startOffset: 20,
            completedOffset: 24
        )
        let partialMessage = base.assistantMessage(
            Self.semanticStatementBatch(nextIndex..<(nextIndex + 1)),
            turnID: partialTurn.id,
            offset: 22
        )

        try await base.append(partialTurn, into: repository)
        try await base.append(partialMessage, into: repository)
        _ = try await Self.publish(repository: repository, base: base, turnLimit: 1, offset: 30)
        let blockerPayload = try await Self.currentBlockerPayload(repository: repository, sessionID: base.session.id)
        let approachPayload = try await Self.currentApproachPayload(repository: repository, sessionID: base.session.id)

        #expect(blockerPayload.blockers.count == ProvenanceCodingAgentSessionSemanticInferenceProducer.maximumBlockersPerSession)
        #expect(blockerPayload.blockers.contains { $0.affectedActivity == "task \(nextIndex)" })
        #expect(blockerPayload.omissionReasons.contains("partial_source_history_merge_blocker_output_truncated"))
        #expect(approachPayload.approachChanges.count == ProvenanceCodingAgentSessionSemanticInferenceProducer.maximumApproachChangesPerSession)
        #expect(approachPayload.approachChanges.contains { $0.objective == "objective \(nextIndex)" })
        #expect(approachPayload.omissionReasons.contains("partial_source_history_merge_approach_changes_truncated"))
    }

    private static func semanticStatementBatch(_ range: Range<Int>) -> String {
        range.flatMap { index in
            [
                "Blocker: activity=task \(index); condition=condition \(index)",
                "Approach change: objective=objective \(index); prior=prior \(index); replacement=replacement \(index); state=replaced",
            ]
        }.joined(separator: "\n")
    }

    private static func publish(
        repository: ProvenanceSQLiteRepository,
        base: WorkModelFixture,
        turnLimit: Int? = nil,
        offset: TimeInterval
    ) async throws -> ProvenanceCodingAgentSessionSemanticInferenceResponse {
        try await repository.publishCodingAgentSessionSemanticInferences(
            ProvenanceCodingAgentSessionSemanticInferenceRequest(
                sessionID: base.session.id,
                turnLimit: turnLimit,
                createdAt: base.timestamp.addingTimeInterval(offset)
            )
        )
    }

    private static func currentBlockerPayload(
        repository: ProvenanceSQLiteRepository,
        sessionID: String
    ) async throws -> ProvenanceCodingAgentBlockerPayload {
        let model = try #require(try await repository.sessionWorkModel(
            ProvenanceSessionWorkModelRequest(sessionID: sessionID)
        ).model)
        let record = try #require(model.blockers.record)
        return try #require(ProvenanceCodingAgentBlockerPayload(semanticPayloadValue: record.payload))
    }

    private static func currentApproachPayload(
        repository: ProvenanceSQLiteRepository,
        sessionID: String
    ) async throws -> ProvenanceCodingAgentApproachChangePayload {
        let model = try #require(try await repository.sessionWorkModel(
            ProvenanceSessionWorkModelRequest(sessionID: sessionID)
        ).model)
        let record = try #require(model.approachChanges.record)
        return try #require(ProvenanceCodingAgentApproachChangePayload(semanticPayloadValue: record.payload))
    }

    private static func temporaryDatabaseURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("provenance-engine-blocker-approach-partial-merge-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("provenance.sqlite")
    }

    private static func removeTemporaryDatabaseDirectory(for url: URL) {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }
}
