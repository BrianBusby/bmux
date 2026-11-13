import Foundation
import ProvenanceEngineContracts
@testable import ProvenanceEngineSQLite
import Testing

#if DEBUG
extension ProvenanceSQLiteRepository {
    func setFactualReadObserver(_ observer: (@Sendable () -> Void)?) {
        didReadFactualSessionForTesting = observer
    }
}

@Suite
struct SessionProjectionSnapshotTests {
    private static func waitForSignal(_ semaphore: DispatchSemaphore) -> Bool {
        semaphore.wait(timeout: .now() + 10) == .success
    }
    private static func finishedQuickly(_ semaphore: DispatchSemaphore) -> Bool {
        semaphore.wait(timeout: .now() + 0.2) == .success
    }

    @Test
    func proposalsAreScopedHistoricalEvidenceAfterReopen() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("pe-proposal-projection-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("provenance.sqlite")
        let writer = try ProvenanceSQLiteRepository(url: url)
        let fixture = WorkModelFixture()
        try await fixture.appendSessionThreadAndTurn(fixture.turn(status: "started"), into: writer)
        func proposal(_ id: String, eventSession: String, payloadSession: String) -> ProvenanceEvent {
            ProvenanceEvent(id: id, eventType: .codingAgentProposedPlanObserved,
                timestamp: fixture.timestamp, sessionID: eventSession, source: .observed, confidence: .high,
                payload: ProvenanceEventPayload(codingAgentProposedPlan: .init(
                    sessionID: payloadSession, provider: "codex", providerSessionID: "provider-session",
                    providerTurnID: "unmatched-turn", providerItemID: id, text: id, truncated: false)))
        }
        try await writer.appendEvent(proposal("first", eventSession: fixture.session.id, payloadSession: fixture.session.id))
        try await writer.appendEvent(proposal("foreign-payload", eventSession: fixture.session.id, payloadSession: "foreign"))
        try await writer.appendEvent(proposal("foreign-event", eventSession: "foreign", payloadSession: "foreign"))
        try await writer.appendEvent(proposal("second", eventSession: fixture.session.id, payloadSession: fixture.session.id))
        let reader = try ProvenanceSQLiteRepository(url: url)
        let snapshot = try #require(await reader.factualSessionProjection(
            ProvenanceFactualSessionProjectionRequest(sessionID: fixture.session.id)).snapshot)
        #expect(snapshot.proposedPlanObservations.map(\.id) == ["second", "first"])
        #expect(snapshot.proposedPlanObservations.allSatisfy { $0.proposal.providerTurnID == "unmatched-turn" })
        #expect(snapshot.proposedPlanObservations.allSatisfy { $0.sequence <= (snapshot.revision ?? 0) })
        #expect(snapshot.latestTurn?.currentPlan == nil)
    }

    @Test
    func nestedSnapshotFailurePreservesOuterTransaction() throws {
        enum TestError: Error { case expected }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("pe-nested-snapshot-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let db = try ProvenanceSQLiteDatabase(url: directory.appendingPathComponent("provenance.sqlite"))
        try db.execute("CREATE TABLE fixture (value INTEGER)")
        try db.execute("BEGIN IMMEDIATE TRANSACTION")
        try db.execute("INSERT INTO fixture VALUES (1)")
        #expect(throws: TestError.self) {
            try db.withReadSnapshot {
                try db.withReadSnapshot { throw TestError.expected }
            }
        }
        try db.execute("INSERT INTO fixture VALUES (2)")
        try db.execute("COMMIT")
        let query = try db.prepare("SELECT COUNT(*) FROM fixture")
        defer { query.finalize() }
        #expect(try query.step())
        #expect(query.int(at: 0) == 2)
        try db.withReadSnapshot { try db.execute("SELECT value FROM fixture") }
    }

    @Test
    func workModelDoesNotMixConcurrentSemanticPublication() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("pe-semantic-snapshot-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("provenance.sqlite")
        let reader = try ProvenanceSQLiteRepository(url: url)
        let writer = try ProvenanceSQLiteRepository(url: url)
        let fixture = WorkModelFixture()
        let turn = fixture.turn(status: "started")
        try await fixture.appendSessionThreadAndTurn(turn, into: writer)
        try await fixture.append(fixture.prompt("Investigate the session", turnID: turn.id), into: writer)
        let readStarted = DispatchSemaphore(value: 0)
        let continueRead = DispatchSemaphore(value: 0)
        await reader.setFactualReadObserver {
            readStarted.signal()
            _ = continueRead.wait(timeout: .now() + 10)
        }
        let readTask = Task.detached {
            try await reader.sessionWorkModel(ProvenanceSessionWorkModelRequest(sessionID: fixture.session.id))
        }
        let entered = await Task.detached { Self.waitForSignal(readStarted) }.value
        guard entered else { continueRead.signal(); Issue.record("Reader did not reach the interleaving point"); _ = try? await readTask.value; return }
        do {
            _ = try await writer.publishCodingAgentSessionSemanticInferences(
                ProvenanceCodingAgentSessionSemanticInferenceRequest(sessionID: fixture.session.id, createdAt: fixture.timestamp.addingTimeInterval(20)))
        } catch {
            continueRead.signal()
            _ = try? await readTask.value
            throw error
        }
        continueRead.signal()
        let old = try #require(await readTask.value.model)
        await reader.setFactualReadObserver(nil)
        let current = try #require(await reader.sessionWorkModel(ProvenanceSessionWorkModelRequest(sessionID: fixture.session.id)).model)
        #expect(old.basis.semanticInferenceRecords.isEmpty)
        #expect(!current.basis.semanticInferenceRecords.isEmpty)
    }

    @Test(arguments: [false, true])
    func readsOneRevisionWhileAnotherConnectionAppends(workModel: Bool) async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("pe-snapshot-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("provenance.sqlite")
        let reader = try ProvenanceSQLiteRepository(url: url)
        let writer = try ProvenanceSQLiteRepository(url: url)
        let fixture = WorkModelFixture()
        let turn = fixture.turn(status: "started")
        try await fixture.appendSessionThreadAndTurn(turn, into: writer)
        let original = try #require(await reader.factualSessionProjection(
            ProvenanceFactualSessionProjectionRequest(sessionID: fixture.session.id)).snapshot)
        let readStarted = DispatchSemaphore(value: 0)
        let continueRead = DispatchSemaphore(value: 0)
        await reader.setFactualReadObserver {
            readStarted.signal()
            _ = continueRead.wait(timeout: .now() + 10)
        }
        let readTask = Task.detached { () throws -> ProvenanceFactualSessionProjectionSnapshot in
            if workModel {
                let response = try await reader.sessionWorkModel(ProvenanceSessionWorkModelRequest(sessionID: fixture.session.id))
                return try #require(response.model?.basis.factualSessionProjection)
            }
            let response = try await reader.factualSessionProjection(ProvenanceFactualSessionProjectionRequest(sessionID: fixture.session.id))
            return try #require(response.snapshot)
        }
        let entered = await Task.detached { Self.waitForSignal(readStarted) }.value
        guard entered else { continueRead.signal(); Issue.record("Reader did not reach the interleaving point"); _ = try? await readTask.value; return }
        do {
            try await fixture.append(fixture.prompt("New evidence", turnID: turn.id), into: writer)
            try await writer.appendEvent(ProvenanceEvent(
                id: "concurrent-proposal", eventType: .codingAgentProposedPlanObserved,
                sessionID: fixture.session.id, source: .observed, confidence: .high,
                payload: ProvenanceEventPayload(codingAgentProposedPlan: .init(
                    sessionID: fixture.session.id, provider: "codex", text: "Plan", truncated: false))))
        } catch {
            continueRead.signal()
            _ = try? await readTask.value
            throw error
        }
        continueRead.signal()
        let observed = try await readTask.value
        await reader.setFactualReadObserver(nil)
        let current = try #require(await reader.factualSessionProjection(
            ProvenanceFactualSessionProjectionRequest(sessionID: fixture.session.id)).snapshot)
        #expect(observed.revision == original.revision)
        #expect(observed.latestTurn?.submittedPrompt == nil)
        #expect(observed.proposedPlanObservations.isEmpty)
        #expect(current.proposedPlanObservations.map(\.id) == ["concurrent-proposal"])
        #expect(current.revision != original.revision)
        #expect(current.latestTurn?.submittedPrompt?.text == "New evidence")
    }
}
#endif


#if DEBUG
extension SessionProjectionSnapshotTests {
    @Test
    func concurrentProducerCannotReplaceNewerEvidenceWithOldClaims() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("pe-producer-race-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("provenance.sqlite")
        let older = try ProvenanceSQLiteRepository(url: url)
        let newer = try ProvenanceSQLiteRepository(url: url)
        let fixture = WorkModelFixture()
        let turn = fixture.turn(status: "started")
        try await fixture.appendSessionThreadAndTurn(turn, into: newer)
        try await fixture.append(fixture.prompt("Investigate the issue", turnID: turn.id), into: newer)
        let entered = DispatchSemaphore(value: 0)
        let resume = DispatchSemaphore(value: 0)
        let newerFinished = DispatchSemaphore(value: 0)
        await older.setFactualReadObserver {
            entered.signal()
            _ = resume.wait(timeout: .now() + 10)
        }
        let oldTask = Task.detached {
            try await older.publishCodingAgentSessionSemanticInferences(
                ProvenanceCodingAgentSessionSemanticInferenceRequest(sessionID: fixture.session.id, createdAt: fixture.timestamp.addingTimeInterval(30)))
        }
        let reached = await Task.detached { Self.waitForSignal(entered) }.value
        guard reached else { resume.signal(); Issue.record("Producer did not reach the interleaving point"); _ = try? await oldTask.value; return }
        let newTask = Task.detached {
            defer { newerFinished.signal() }
            try await fixture.append(fixture.prompt("Fix the regression", turnID: turn.id, offset: 4), into: newer)
            return try await newer.publishCodingAgentSessionSemanticInferences(
                ProvenanceCodingAgentSessionSemanticInferenceRequest(sessionID: fixture.session.id, createdAt: fixture.timestamp.addingTimeInterval(40)))
        }
        _ = await Task.detached { Self.finishedQuickly(newerFinished) }.value
        resume.signal()
        _ = try await oldTask.value
        _ = try await newTask.value
        await older.setFactualReadObserver(nil)
        let model = try #require(await older.sessionWorkModel(ProvenanceSessionWorkModelRequest(sessionID: fixture.session.id)).model)
        let milestone = try #require(model.milestones.record)
        let payload = try #require(ProvenanceCodingAgentMilestonePayload(semanticPayloadValue: milestone.payload))
        #expect(payload.milestones.map(\.title) == ["Fix the regression"])
        #expect(milestone.supportingFactualRevision == model.revision.factualRevision)
    }
}
#endif

#if DEBUG
extension ProvenanceSQLiteRepository {
    func invalidateSemanticForBatchTest(id: String) throws {
        let query = try database.prepare("UPDATE provenance_semantic_inferences SET status = 'invalidated' WHERE id = ?")
        defer { query.finalize() }
        try query.bind(id, at: 1)
        _ = try query.step()
    }
}

extension SessionProjectionSnapshotTests {
    @Test
    func canonicalProducerRollsBackEntireBatchOnLateCollision() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("pe-batch-rollback-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = try ProvenanceSQLiteRepository(url: directory.appendingPathComponent("provenance.sqlite"))
        let fixture = WorkModelFixture()
        let turn = fixture.turn(status: "started")
        try await fixture.appendSessionThreadAndTurn(turn, into: repository)
        try await fixture.append(fixture.prompt("Investigate a failure", turnID: turn.id), into: repository)
        let snapshot = try #require(await repository.factualSessionProjection(
            ProvenanceFactualSessionProjectionRequest(sessionID: fixture.session.id)).snapshot)
        let timestamp = fixture.timestamp.addingTimeInterval(20)
        let candidates = ProvenanceCodingAgentSessionSemanticInferenceProducer.records(for: snapshot, createdAt: timestamp)
        #expect(candidates.count > 1)
        let collision = try #require(candidates.last)
        _ = try await repository.publishSemanticInference(ProvenanceSemanticInferencePublishRequest(record: collision))
        try await repository.invalidateSemanticForBatchTest(id: collision.id)
        do {
            _ = try await repository.publishCodingAgentSessionSemanticInferences(
                ProvenanceCodingAgentSessionSemanticInferenceRequest(sessionID: fixture.session.id, createdAt: timestamp))
            Issue.record("Expected duplicate inference ID to reject the batch")
        } catch {
            // The colliding historical ID causes the write to fail.
        }
        for candidate in candidates {
            let result = try await repository.semanticInferences(ProvenanceSemanticInferenceQueryRequest(
                scope: candidate.scope, scopeID: candidate.scopeID, kind: candidate.kind))
            #expect(result.records.isEmpty)
        }
    }
}
#endif
