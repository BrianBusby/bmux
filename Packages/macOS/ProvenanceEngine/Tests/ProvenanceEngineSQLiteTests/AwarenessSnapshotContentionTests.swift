import Foundation
import ProvenanceEngineContracts
@testable import ProvenanceEngineSQLite
import Testing

#if DEBUG
@Suite struct AwarenessSnapshotContentionTests {
    private static func waitForSignal(_ semaphore: DispatchSemaphore) -> Bool {
        semaphore.wait(timeout: .now() + 10) == .success
    }
    @Test(arguments: [false, true], [false, true])
    func retriesStaleOutcomeSnapshotBeforeWriting(prepared: Bool, nested: Bool) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("pe-retry-snapshot-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("provenance.sqlite")
        let reader = try ProvenanceSQLiteDatabase(url: url)
        let writer = try ProvenanceSQLiteDatabase(url: url)
        try reader.execute("CREATE TABLE fixture (value INTEGER)")
        var attempts = 0
        let readAndWrite = {
            attempts += 1
            let query = try reader.prepare("SELECT COUNT(*) FROM fixture")
            defer { query.finalize() }
            guard try query.step() else { throw ProvenanceSQLiteError.sqlite(message: "missing fixture count") }
            let count = query.int(at: 0)
            if attempts == 1 { try writer.execute("INSERT INTO fixture VALUES (1)") }
            if prepared {
                let insert = try reader.prepare("INSERT INTO fixture VALUES (2)")
                defer { insert.finalize() }
                _ = try insert.step()
            } else {
                try reader.execute("INSERT INTO fixture VALUES (2)")
            }
            return count
        }
        let count = try reader.withReadSnapshotRetryingWrites {
            if nested { return try reader.withReadSnapshotRetryingWrites(readAndWrite) }
            return try readAndWrite()
        }
        #expect(attempts == 2)
        #expect(count == 1)
    }

    @Test
    func relatedSessionProjectionSurvivesConcurrentAppend() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("pe-awareness-race-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("provenance.sqlite")
        let reader = try ProvenanceSQLiteRepository(url: url)
        let writer = try ProvenanceSQLiteRepository(url: url)
        let fixture = WorkModelFixture()
        let turn = fixture.turn(status: "started")
        try await fixture.appendSessionThreadAndTurn(turn, into: writer)

        let entered = DispatchSemaphore(value: 0)
        let firstRead = DispatchSemaphore(value: 1)
        let resume = DispatchSemaphore(value: 0)
        let writerProgress = DispatchSemaphore(value: 0)
        let resumeWriter = DispatchSemaphore(value: 0)
        defer { firstRead.signal(); resume.signal(); resumeWriter.signal() }
        await reader.setFactualReadObserver {
            guard firstRead.wait(timeout: .now()) == .success else { return }
            entered.signal()
            _ = resume.wait(timeout: .now() + 10)
        }
        await writer.setBusyObserver {
            writerProgress.signal()
            _ = resumeWriter.wait(timeout: .now() + 10)
        }
        let readTask = Task.detached {
            try await reader.relatedSessions(.init(targetSessionID: fixture.session.id))
        }
        guard await Task.detached(operation: { Self.waitForSignal(entered) }).value else {
            resume.signal()
            Issue.record("Reader did not reach the interleaving point")
            _ = try? await readTask.value
            return
        }
        let writeTask = Task.detached {
            defer { writerProgress.signal() }
            try await fixture.append(fixture.prompt("New evidence", turnID: turn.id), into: writer)
        }
        guard await Task.detached(operation: { Self.waitForSignal(writerProgress) }).value else {
            resume.signal(); resumeWriter.signal()
            Issue.record("Writer did not reach the interleaving point")
            _ = try? await readTask.value; _ = try? await writeTask.value
            return
        }
        resume.signal()
        let result: Result<ProvenanceRelatedSessionResponse, any Error>
        do { result = .success(try await readTask.value) }
        catch { result = .failure(error) }
        resumeWriter.signal()
        try await writeTask.value
        #expect(try result.get().found)
    }
}
#endif
