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
        #expect(current.revision != original.revision)
        #expect(current.latestTurn?.submittedPrompt?.text == "New evidence")
    }
}
#endif

#if DEBUG
private enum GuardTestError: Error { case expected }

extension ProvenanceSQLiteRepository {
    func createGuardTestTable() throws { try database.execute("CREATE TABLE guard_test (value INTEGER)") }
    func writeIfMatching(_ request: ProvenanceSessionWorkModelRequest,
                         expected: ProvenanceSessionWorkModelResponse,
                         fail: Bool = false) throws -> Bool {
        try withMatchingWorkModel(request, expected: expected) {
            try database.execute("INSERT INTO guard_test VALUES (1)")
            if fail { throw GuardTestError.expected }
        }
    }
    func waitAndWriteIfMatching(_ request: ProvenanceSessionWorkModelRequest,
                                expected: ProvenanceSessionWorkModelResponse,
                                entered: DispatchSemaphore, resume: DispatchSemaphore) throws -> Bool {
        try withMatchingWorkModel(request, expected: expected) {
            entered.signal()
            _ = resume.wait(timeout: .now() + 10)
            try database.execute("INSERT INTO guard_test VALUES (1)")
        }
    }
    func guardTestCount() throws -> Int {
        let query = try database.prepare("SELECT COUNT(*) FROM guard_test")
        defer { query.finalize() }
        guard try query.step() else { return -1 }
        return query.int(at: 0)
    }
}

extension SessionProjectionSnapshotTests {
    @Test
    func matchingGuardHoldsWriteBoundaryAcrossConnections() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("pe-guard-race-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("provenance.sqlite")
        let reader = try ProvenanceSQLiteRepository(url: url)
        let writer = try ProvenanceSQLiteRepository(url: url)
        let fixture = WorkModelFixture()
        let turn = fixture.turn(status: "started")
        try await fixture.appendSessionThreadAndTurn(turn, into: writer)
        try await reader.createGuardTestTable()
        let request = ProvenanceSessionWorkModelRequest(sessionID: fixture.session.id)
        let original = try await reader.sessionWorkModel(request)
        let entered = DispatchSemaphore(value: 0)
        let resume = DispatchSemaphore(value: 0)
        let writerStarted = DispatchSemaphore(value: 0)
        let writerFinished = DispatchSemaphore(value: 0)
        let guarded = Task.detached {
            try await reader.waitAndWriteIfMatching(request, expected: original, entered: entered, resume: resume)
        }
        let reached = await Task.detached { Self.waitForSignal(entered) }.value
        guard reached else { resume.signal(); Issue.record("Guard did not enter operation"); _ = try? await guarded.value; return }
        let append = Task.detached {
            writerStarted.signal()
            defer { writerFinished.signal() }
            try await fixture.append(fixture.prompt("Concurrent evidence", turnID: turn.id), into: writer)
        }
        let writerRan = await Task.detached { Self.waitForSignal(writerStarted) }.value
        let premature = await Task.detached { Self.finishedQuickly(writerFinished) }.value
        resume.signal()
        #expect(writerRan)
        #expect(try await guarded.value)
        try await append.value
        #expect(!premature)
        #expect(try await reader.guardTestCount() == 1)
        #expect(try await !reader.writeIfMatching(request, expected: original))
    }

    private static func finishedQuickly(_ semaphore: DispatchSemaphore) -> Bool {
        semaphore.wait(timeout: .now() + 0.2) == .success
    }

    @Test
    func matchingWorkModelGuardCommitsOrRollsBackWithoutStaleWrites() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("pe-guard-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("provenance.sqlite")
        let reader = try ProvenanceSQLiteRepository(url: url)
        let writer = try ProvenanceSQLiteRepository(url: url)
        let fixture = WorkModelFixture()
        let turn = fixture.turn(status: "started")
        try await fixture.appendSessionThreadAndTurn(turn, into: writer)
        try await fixture.append(fixture.prompt("Investigate the session", turnID: turn.id), into: writer)
        try await reader.createGuardTestTable()
        let request = ProvenanceSessionWorkModelRequest(sessionID: fixture.session.id)
        let original = try await reader.sessionWorkModel(request)
        #expect(try await reader.writeIfMatching(request, expected: original))
        do {
            _ = try await reader.writeIfMatching(request, expected: original, fail: true)
            Issue.record("Expected operation failure")
        } catch GuardTestError.expected {
        }
        #expect(try await reader.guardTestCount() == 1)
        _ = try await writer.publishCodingAgentSessionSemanticInferences(
            ProvenanceCodingAgentSessionSemanticInferenceRequest(sessionID: fixture.session.id, createdAt: fixture.timestamp.addingTimeInterval(20)))
        #expect(try await !reader.writeIfMatching(request, expected: original))
        let afterSemantic = try await reader.sessionWorkModel(request)
        try await fixture.append(fixture.prompt("New evidence", turnID: turn.id, offset: 4), into: writer)
        #expect(try await !reader.writeIfMatching(request, expected: afterSemantic))
        #expect(try await reader.guardTestCount() == 1)
    }
}
#endif
