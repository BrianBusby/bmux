import Foundation
import ProvenanceEngineContracts
@testable import ProvenanceEngineSQLite
import Testing

@Suite
struct SessionWorkModelFoundationTests {
    @Test
    func missingSessionReturnsNoSession() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)

        let response = try await repository.sessionWorkModel(
            ProvenanceSessionWorkModelRequest(sessionID: "missing-session")
        )

        #expect(response.found == false)
        #expect(response.reason == "no_session")
        #expect(response.model == nil)
    }

    @Test
    func factualOnlyModelKeepsSemanticFieldsUnknownAndPreservesFacts() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)
        let base = WorkModelFixture()
        let turn = base.turn(status: "started")

        try await base.appendSessionThreadAndTurn(turn, into: repository)
        try await base.append(base.prompt("Add a PE SessionWorkModel contract.", turnID: turn.id), into: repository)
        try await base.append(base.plan("Define the public contract", turnID: turn.id), into: repository)
        try await base.append(base.command("swift test", turnID: turn.id, offset: 7), into: repository)
        let factualBefore = try await repository.factualSessionProjection(
            ProvenanceFactualSessionProjectionRequest(sessionID: base.session.id)
        )

        let response = try await repository.sessionWorkModel(
            ProvenanceSessionWorkModelRequest(sessionID: base.session.id)
        )
        let model = try #require(response.model)
        let currentTurn = try #require(model.currentTurn)

        #expect(response.found == true)
        #expect(model.identity.session.id == base.session.id)
        #expect(model.thread?.identity.threadID == base.thread.id)
        #expect(currentTurn.turn.id == turn.id)
        #expect(currentTurn.prompt?.text == "Add a PE SessionWorkModel contract.")
        #expect(currentTurn.plan?.steps.map(\.text) == ["Define the public contract"])
        #expect(currentTurn.completedCommands.map(\.command) == ["swift test"])
        #expect(model.thread?.intent.state == .unknown)
        #expect(currentTurn.intent.state == .unknown)
        #expect(currentTurn.currentActivity.state == .unknown)
        #expect(model.sessionPhase.state == .unknown)
        #expect(model.basis.semanticInferenceRecords.isEmpty)
        #expect(try await repository.factualSessionProjection(
            ProvenanceFactualSessionProjectionRequest(sessionID: base.session.id)
        ) == factualBefore)
    }

    @Test
    func modelLeavesCurrentThreadAbsentWhenThreadIdentityIsAmbiguous() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)
        let base = WorkModelFixture()
        let secondThread = ProvenanceCodingAgentThreadRecord(
            id: "thread-work-model-fixture-2",
            sessionID: base.session.id,
            provider: "codex",
            providerThreadID: "provider-thread-work-model-fixture-2",
            worktreeID: "worktree-work-model-fixture",
            source: .observed,
            confidence: .high,
            firstObservedAt: base.timestamp.addingTimeInterval(2),
            updatedAt: base.timestamp.addingTimeInterval(2)
        )

        try await Self.append(base.session, into: repository)
        try await Self.append(base.thread, eventID: "event-thread-work-model-fixture-1", into: repository)
        try await Self.append(secondThread, eventID: "event-thread-work-model-fixture-2", into: repository)

        let model = try #require(try await repository.sessionWorkModel(
            ProvenanceSessionWorkModelRequest(sessionID: base.session.id)
        ).model)

        #expect(model.identity.providerThreadIdentities.map(\.threadID).sorted() == [
            base.thread.id,
            secondThread.id,
        ])
        #expect(model.thread == nil)
        #expect(model.currentTurn == nil)
        #expect(model.sessionPhase.state == .unknown)
        #expect(model.basis.semanticInferenceRecords.isEmpty)
    }

    @Test
    func modelSelectsActiveSemanticInferencesWithProvenance() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)
        let base = WorkModelFixture()
        let turn = base.turn(status: "started")

        try await base.appendSessionThreadAndTurn(turn, into: repository)
        try await base.append(base.prompt("Implement the SessionWorkModel read path.", turnID: turn.id), into: repository)
        try await base.append(base.reasoning("Inspecting semantic inference records", turnID: turn.id, offset: 5), into: repository)
        let published = try await repository.publishCodingAgentSessionSemanticInferences(
            ProvenanceCodingAgentSessionSemanticInferenceRequest(
                sessionID: base.session.id,
                createdAt: base.timestamp.addingTimeInterval(20)
            )
        )

        let response = try await repository.sessionWorkModel(
            ProvenanceSessionWorkModelRequest(sessionID: base.session.id)
        )
        let model = try #require(response.model)
        let currentTurn = try #require(model.currentTurn)
        let threadIntent = try #require(model.thread?.intent.record)
        let turnIntent = try #require(currentTurn.intent.record)
        let currentActivity = try #require(currentTurn.currentActivity.record)
        let phase = try #require(model.sessionPhase.record)
        let activityPayload = try #require(ProvenanceCodingAgentCurrentActivityPayload(
            semanticPayloadValue: currentActivity.payload
        ))

        #expect(published.publishedInferenceIDs.count == 4)
        #expect(model.revision.semanticInferenceIDs.sorted() == model.basis.semanticInferenceRecords.map(\.id).sorted())
        #expect(model.basis.semanticInferenceRecords.count == 4)
        #expect(model.thread?.intent.state == .known)
        #expect(currentTurn.intent.state == .known)
        #expect(currentTurn.currentActivity.state == .known)
        #expect(model.sessionPhase.state == .known)
        #expect(threadIntent.supportingFactualRevision == model.revision.factualRevision)
        #expect(turnIntent.supportingFactualRevision == model.revision.factualRevision)
        #expect(currentActivity.supportingEvidenceRefs.isEmpty == false)
        #expect(phase.producerID == ProvenanceCodingAgentSessionSemanticInferenceProducer.producerID)
        #expect(activityPayload.activityKind == .investigation)
        #expect(activityPayload.summary == "Inspecting semantic inference records")
    }

    @Test
    func semanticMessagesAloneDoNotBecomeModelTruth() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)
        let base = WorkModelFixture()
        let turn = base.turn(status: "started")
        let payload = ProvenanceCodingAgentIntentPayload(
            summary: "Implement SessionWorkModel",
            action: "implementing",
            subject: "SessionWorkModel",
            target: nil,
            purpose: nil,
            components: [],
            sourceText: "Implement SessionWorkModel"
        )
        let message = ProvenanceSemanticMessageRecord(
            id: "message-without-inference",
            semanticInferenceID: "missing-inference",
            semanticInferenceKind: ProvenanceCodingAgentSemanticInferenceKind.threadIntent.rawValue,
            scope: .thread,
            scopeID: base.thread.id,
            concisePhrase: "Implementing SessionWorkModel",
            expandedMeaning: "The session is implementing SessionWorkModel.",
            structuredSemanticPayload: payload.semanticPayloadValue,
            supportingEvidenceRefs: [],
            supportingFactualRevision: 7,
            confidence: .high,
            specificity: .scoped,
            presentationProducerType: .rule,
            presentationProducerID: "test.semantic-message",
            presentationProducerVersion: "v1",
            presentationPolicyID: "test.policy",
            presentationPolicyVersion: "v1",
            localeIdentifier: "en-US",
            createdAt: base.timestamp.addingTimeInterval(20)
        )

        try await base.appendSessionThreadAndTurn(turn, into: repository)
        let publish = try await repository.publishSemanticMessage(
            ProvenanceSemanticMessagePublishRequest(record: message)
        )
        let messages = try await repository.semanticMessages(
            ProvenanceSemanticMessageQueryRequest(
                scope: .thread,
                scopeID: base.thread.id,
                semanticInferenceKind: ProvenanceCodingAgentSemanticInferenceKind.threadIntent.rawValue
            )
        )
        let model = try #require(try await repository.sessionWorkModel(
            ProvenanceSessionWorkModelRequest(sessionID: base.session.id)
        ).model)

        #expect(publish.accepted == true)
        #expect(messages.records.map(\.id) == [message.id])
        #expect(model.thread?.intent.state == .unknown)
        #expect(model.thread?.intent.record == nil)
        #expect(model.basis.semanticInferenceRecords.isEmpty)
        #expect(model.revision.semanticInferenceIDs.isEmpty)
    }

    @Test
    func supersededSemanticRecordsAreNotSelectedAsCurrent() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)
        let base = WorkModelFixture()
        let turn = base.turn(status: "started")

        try await base.appendSessionThreadAndTurn(turn, into: repository)
        try await base.append(base.prompt("Update Smart Session evidence.", turnID: turn.id), into: repository)
        try await base.append(base.reasoning("Reading existing Smart Session files", turnID: turn.id, offset: 5), into: repository)
        let first = try await repository.publishCodingAgentSessionSemanticInferences(
            ProvenanceCodingAgentSessionSemanticInferenceRequest(
                sessionID: base.session.id,
                createdAt: base.timestamp.addingTimeInterval(20)
            )
        )
        let oldActivityID = try #require(first.records.first {
            $0.kind == ProvenanceCodingAgentSemanticInferenceKind.currentActivity.rawValue
        }).id

        try await base.append(base.fileAttribution("Changing Smart Session bridge files", turnID: turn.id, offset: 8), into: repository)
        let second = try await repository.publishCodingAgentSessionSemanticInferences(
            ProvenanceCodingAgentSessionSemanticInferenceRequest(
                sessionID: base.session.id,
                createdAt: base.timestamp.addingTimeInterval(30)
            )
        )
        let newActivityID = try #require(second.records.first {
            $0.kind == ProvenanceCodingAgentSemanticInferenceKind.currentActivity.rawValue
        }).id

        let model = try #require(try await repository.sessionWorkModel(
            ProvenanceSessionWorkModelRequest(sessionID: base.session.id)
        ).model)
        let activityRecord = try #require(model.currentTurn?.currentActivity.record)
        let history = try await repository.semanticInferences(
            ProvenanceSemanticInferenceQueryRequest(
                scope: .turn,
                scopeID: turn.id,
                kind: ProvenanceCodingAgentSemanticInferenceKind.currentActivity.rawValue,
                includeInactive: true
            )
        )

        #expect(activityRecord.inferenceID == newActivityID)
        #expect(activityRecord.inferenceID != oldActivityID)
        #expect(model.basis.semanticInferenceRecords.map(\.id).contains(oldActivityID) == false)
        #expect(history.records.map(\.status) == [.active, .superseded])
        #expect(history.records.first?.id == newActivityID)
        #expect(history.records.last?.id == oldActivityID)
    }

    @Test
    func modelRevisionChangesWhenFactualOrSemanticInputsChange() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)
        let base = WorkModelFixture()
        let turn = base.turn(status: "started")

        try await base.appendSessionThreadAndTurn(turn, into: repository)
        try await base.append(base.prompt("Build model revision semantics.", turnID: turn.id), into: repository)
        let first = try #require(try await repository.sessionWorkModel(
            ProvenanceSessionWorkModelRequest(sessionID: base.session.id)
        ).model)

        try await base.append(base.command("swift test --filter SessionWorkModel", turnID: turn.id, offset: 7), into: repository)
        let afterFactualChange = try #require(try await repository.sessionWorkModel(
            ProvenanceSessionWorkModelRequest(sessionID: base.session.id)
        ).model)

        _ = try await repository.publishCodingAgentSessionSemanticInferences(
            ProvenanceCodingAgentSessionSemanticInferenceRequest(
                sessionID: base.session.id,
                createdAt: base.timestamp.addingTimeInterval(20)
            )
        )
        let afterSemanticChange = try #require(try await repository.sessionWorkModel(
            ProvenanceSessionWorkModelRequest(sessionID: base.session.id)
        ).model)

        #expect(afterFactualChange.revision.factualRevision != first.revision.factualRevision)
        #expect(afterFactualChange.revision.modelRevisionKey != first.revision.modelRevisionKey)
        #expect(afterSemanticChange.revision.semanticInferenceIDs.isEmpty == false)
        #expect(afterSemanticChange.revision.modelRevisionKey != afterFactualChange.revision.modelRevisionKey)
    }

    @Test
    func priorTurnReferencesRemainStableAndLowerLevelApisRemainAvailable() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)
        let base = WorkModelFixture()
        let firstTurn = base.turn(id: "turn-1", providerTurnID: "provider-turn-1", status: "completed", completedOffset: 6)
        let secondTurn = base.turn(id: "turn-2", providerTurnID: "provider-turn-2", status: "started", startOffset: 9)

        try await base.appendSessionThreadAndTurn(firstTurn, into: repository)
        try await base.append(base.prompt("First turn", turnID: firstTurn.id, offset: 3), into: repository)
        try await base.append(secondTurn, into: repository)
        try await base.append(base.prompt("Second turn", turnID: secondTurn.id, offset: 10), into: repository)

        let model = try #require(try await repository.sessionWorkModel(
            ProvenanceSessionWorkModelRequest(sessionID: base.session.id, turnLimit: 1)
        ).model)
        let factualProjection = try await repository.factualSessionProjection(
            ProvenanceFactualSessionProjectionRequest(sessionID: base.session.id, turnLimit: 1)
        )
        let turnDetail = try await repository.factualSessionTurnDetail(
            ProvenanceFactualSessionTurnDetailRequest(turnID: firstTurn.id)
        )

        #expect(model.currentTurn?.turn.id == secondTurn.id)
        #expect(model.priorTurns.map(\.turnID) == [firstTurn.id])
        #expect(model.basis.factualSessionProjection.turns.map(\.turn.id) == factualProjection.snapshot?.turns.map(\.turn.id))
        #expect(turnDetail.found == true)
        #expect(turnDetail.turnDetail?.turn.id == firstTurn.id)
    }

    private static func temporaryDatabaseURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("provenance-engine-session-work-model-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("provenance.sqlite")
    }

    private static func removeTemporaryDatabaseDirectory(for url: URL) {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }

    private static func append(
        _ session: ProvenanceSessionRecord,
        into repository: ProvenanceSQLiteRepository
    ) async throws {
        try await repository.appendEvent(event(
            id: "event-session-work-model-fixture",
            type: .sessionObserved,
            timestamp: session.updatedAt,
            sessionID: session.id,
            payload: ProvenanceEventPayload(session: session)
        ))
    }

    private static func append(
        _ thread: ProvenanceCodingAgentThreadRecord,
        eventID: String,
        into repository: ProvenanceSQLiteRepository
    ) async throws {
        try await repository.appendEvent(event(
            id: eventID,
            type: .codingAgentThreadObserved,
            timestamp: thread.updatedAt,
            sessionID: thread.sessionID,
            payload: ProvenanceEventPayload(codingAgentThread: thread)
        ))
    }

    private static func event(
        id: String,
        type: ProvenanceEventType,
        timestamp: Date,
        sessionID: String,
        payload: ProvenanceEventPayload
    ) -> ProvenanceEvent {
        ProvenanceEvent(
            id: id,
            eventType: type,
            timestamp: timestamp,
            sessionID: sessionID,
            source: .observed,
            evidenceOrigin: .codexSession,
            evidenceScope: ProvenanceEvidenceScope(level: .personal, id: "session-work-model-fixture"),
            confidence: .high,
            payload: payload
        )
    }
}
