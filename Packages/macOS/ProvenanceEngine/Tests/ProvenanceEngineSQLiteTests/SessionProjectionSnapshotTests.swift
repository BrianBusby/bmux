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
                timestamp: fixture.timestamp, sessionID: eventSession, source: .observed,
                evidenceOrigin: .init(rawValue: "codex-transcript"), confidence: .high,
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
    func rejectsOversizedMalformedAndInferredEvidenceWithoutLosingLedger() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("pe-proposal-bounds-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("provenance.sqlite")
        let writer = try ProvenanceSQLiteRepository(url: url)
        let fixture = WorkModelFixture()
        try await fixture.appendSessionThreadAndTurn(fixture.turn(status: "started"), into: writer)
        func event(_ id: String, source: ProvenanceSource, text: String) -> ProvenanceEvent {
            ProvenanceEvent(id: id, eventType: .codingAgentProposedPlanObserved, sessionID: fixture.session.id,
                source: source, evidenceOrigin: .init(rawValue: "codex-transcript"), confidence: .high,
                payload: .init(codingAgentProposedPlan: .init(sessionID: fixture.session.id, provider: "codex",
                    providerSessionID: "thread", providerTurnID: "turn", providerItemID: id, text: text, truncated: false)))
        }
        try await writer.appendEvent(event("valid", source: .observed, text: "Valid"))
        try await writer.appendEvent(event("inferred", source: .inferred, text: "Inferred"))
        try await writer.appendEvent(event("large", source: .observed, text: String(repeating: "x", count: 100_000)))
        try await writer.appendEvent(event("malformed", source: .observed, text: "Before corruption"))
        try await writer.appendEvent(event("numeric", source: .observed, text: "Before corruption"))
        let db = try ProvenanceSQLiteDatabase(url: url)
        try db.execute("UPDATE provenance_events SET payload_json = '{' WHERE id = 'malformed'")
        try db.execute("UPDATE provenance_events SET payload_json = X'31323334' WHERE id = 'numeric'")
        let reader = try ProvenanceSQLiteRepository(url: url)
        let snapshot = try #require(await reader.factualSessionProjection(
            ProvenanceFactualSessionProjectionRequest(sessionID: fixture.session.id)).snapshot)
        #expect(snapshot.proposedPlanObservations.map(\.id) == ["valid"])
        #expect(snapshot.proposedPlanObservations.first?.source == .observed)
        #expect(snapshot.proposedPlanObservations.first?.origin?.rawValue == "codex-transcript")
        #expect(snapshot.proposedPlanObservations.first?.eventSchemaVersion == 1)
        #expect(snapshot.proposedPlanObservations.first?.confidence == .high)
        #expect(snapshot.proposedPlanCoverage?.omittedObservations == true)
        #expect(try await reader.event(id: "large")?.payload.codingAgentProposedPlan?.text.count == 100_000)
    }

    @Test
    func rejectsInvalidProviderIdentitiesAndRetainsRawEvents() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("pe-proposal-identity-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("provenance.sqlite")
        let writer = try ProvenanceSQLiteRepository(url: url)
        let fixture = WorkModelFixture()
        try await fixture.appendSessionThreadAndTurn(fixture.turn(status: "started"), into: writer)
        let invalid = ["", " \n", " leading", "trailing ", String(repeating: "é", count: 129)]
        for (index, value) in invalid.enumerated() {
            for field in 0..<3 {
                let proposal = ProvenanceCodingAgentProposedPlanRecord(sessionID: fixture.session.id, provider: "codex",
                    providerSessionID: field == 0 ? value : "thread", providerTurnID: field == 1 ? value : "turn",
                    providerItemID: field == 2 ? value : "item", text: "Plan", truncated: false)
                try await writer.appendEvent(ProvenanceEvent(id: "invalid-\(index)-\(field)",
                    eventType: .codingAgentProposedPlanObserved, sessionID: fixture.session.id, source: .observed,
                    evidenceOrigin: .init(rawValue: "codex-transcript"), confidence: .high,
                    payload: .init(codingAgentProposedPlan: proposal)))
            }
        }
        let valid = ProvenanceCodingAgentProposedPlanRecord(sessionID: fixture.session.id, provider: "codex",
            providerSessionID: "thread", providerTurnID: "turn", providerItemID: String(repeating: "x", count: 256),
            text: "Valid", truncated: false)
        #expect(valid.hasValidProviderIdentity)
        try await writer.appendEvent(ProvenanceEvent(id: "valid", eventType: .codingAgentProposedPlanObserved,
            sessionID: fixture.session.id, source: .observed, evidenceOrigin: .init(rawValue: "codex-transcript"),
            confidence: .high, payload: .init(codingAgentProposedPlan: valid)))
        let reader = try ProvenanceSQLiteRepository(url: url)
        let storedValid = try #require(await reader.event(id: "valid")?.payload.codingAgentProposedPlan)
        #expect(storedValid.hasValidProviderIdentity)
        #expect(storedValid.providerItemID?.utf8.count == 256)
        let snapshot = try #require(await reader.factualSessionProjection(
            ProvenanceFactualSessionProjectionRequest(sessionID: fixture.session.id)).snapshot)
        #expect(snapshot.proposedPlanObservations.map(\.id) == ["valid"])
        #expect(snapshot.proposedPlanCoverage?.omittedObservations == true)
        #expect(try await reader.event(id: "invalid-0-0")?.payload.codingAgentProposedPlan?.providerSessionID == "")
        #expect(try await reader.event(id: "invalid-4-2")?.payload.codingAgentProposedPlan?.providerItemID == invalid[4])
    }

    @Test
    func reportsExcludedLedgerWindow() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("pe-proposal-window-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("provenance.sqlite")
        let writer = try ProvenanceSQLiteRepository(url: url)
        let fixture = WorkModelFixture()
        try await fixture.appendSessionThreadAndTurn(fixture.turn(status: "started"), into: writer)
        let event = ProvenanceEvent(id: "seed", eventType: .codingAgentProposedPlanObserved,
            sessionID: fixture.session.id, source: .observed,
            evidenceOrigin: .init(rawValue: "codex-transcript"), confidence: .high,
            payload: .init(codingAgentProposedPlan: .init(sessionID: fixture.session.id, provider: "codex",
                providerSessionID: "thread", providerTurnID: "turn", providerItemID: "item", text: "Plan", truncated: false)))
        try await writer.appendEvent(event)
        let db = try ProvenanceSQLiteDatabase(url: url)
        let inserts = try db.prepare("""
            WITH RECURSIVE n(x) AS (VALUES(1) UNION ALL SELECT x+1 FROM n WHERE x < 5001)
            INSERT INTO provenance_events (id, schema_version, event_type, timestamp_seconds, session_id, source, confidence, payload_json)
            SELECT 'noise-' || x, 1, 'noise', 1, ?, 'observed', 'high', '{}' FROM n
            """)
        try inserts.bind(fixture.session.id, at: 1)
        _ = try inserts.step()
        inserts.finalize()
        let reader = try ProvenanceSQLiteRepository(url: url)
        let snapshot = try #require(await reader.factualSessionProjection(
            ProvenanceFactualSessionProjectionRequest(sessionID: fixture.session.id)).snapshot)
        #expect(snapshot.proposedPlanCoverage?.scanWindowTruncated == true)
        #expect(snapshot.proposedPlanObservations.isEmpty)
        #expect(try await reader.event(id: "seed")?.payload.codingAgentProposedPlan?.text == "Plan")
    }

    @Test
    func boundsTotalProposalBytesAndReportsOmissions() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("pe-proposal-total-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("provenance.sqlite")
        let writer = try ProvenanceSQLiteRepository(url: url)
        let fixture = WorkModelFixture()
        try await fixture.appendSessionThreadAndTurn(fixture.turn(status: "started"), into: writer)
        for index in 0..<20 {
            try await writer.appendEvent(ProvenanceEvent(id: "proposal-\(index)", eventType: .codingAgentProposedPlanObserved,
                sessionID: fixture.session.id, source: .observed,
                evidenceOrigin: .init(rawValue: "codex-transcript"), confidence: .high,
                payload: .init(codingAgentProposedPlan: .init(sessionID: fixture.session.id, provider: "codex",
                    providerSessionID: "thread", providerTurnID: "turn", providerItemID: "item-\(index)",
                    text: String(repeating: "x", count: 20_000), truncated: false))))
        }
        let snapshot = try #require(await writer.factualSessionProjection(
            ProvenanceFactualSessionProjectionRequest(sessionID: fixture.session.id)).snapshot)
        #expect(snapshot.proposedPlanCoverage?.omittedObservations == true)
        #expect(snapshot.proposedPlanObservations.count < 20)
        #expect(snapshot.proposedPlanObservations.reduce(0) { $0 + $1.proposal.text.utf8.count } <= 256 * 1024)
        #expect(try await writer.event(id: "proposal-0")?.payload.codingAgentProposedPlan?.text.count == 20_000)
        for index in 0..<51 {
            try await writer.appendEvent(ProvenanceEvent(id: "small-\(index)", eventType: .codingAgentProposedPlanObserved,
                sessionID: fixture.session.id, source: .observed,
                evidenceOrigin: .init(rawValue: "codex-transcript"), confidence: .high,
                payload: .init(codingAgentProposedPlan: .init(sessionID: fixture.session.id, provider: "codex",
                    providerSessionID: "thread", providerTurnID: "turn", providerItemID: "small-\(index)",
                    text: "Plan", truncated: false))))
        }
        let limited = try #require(await writer.factualSessionProjection(
            ProvenanceFactualSessionProjectionRequest(sessionID: fixture.session.id)).snapshot)
        #expect(limited.proposedPlanObservations.count == 50)
        #expect(limited.proposedPlanCoverage?.omittedObservations == true)
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
                sessionID: fixture.session.id, source: .observed,
                evidenceOrigin: .init(rawValue: "codex-transcript"), confidence: .high,
                payload: ProvenanceEventPayload(codingAgentProposedPlan: .init(
                    sessionID: fixture.session.id, provider: "codex", providerSessionID: "thread",
                    providerTurnID: "turn", providerItemID: "item", text: "Plan", truncated: false))))
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
