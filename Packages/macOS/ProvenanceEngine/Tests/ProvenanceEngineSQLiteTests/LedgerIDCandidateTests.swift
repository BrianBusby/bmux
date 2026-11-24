import Foundation
import ProvenanceEngineContracts
@testable import ProvenanceEngineSQLite
import Testing

@Suite struct LedgerIDCandidateTests {
    @Test func candidateDoesNotChangeV1DuplicateBehavior() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let repository = try ProvenanceSQLiteRepository(url: fixture.url)
        let client: any ProvenanceEngineClient = repository
        let candidate = try #require(client as? any ProvenanceLedgerIDCandidateClient)
        let event = fixture.event(id: "event")
        #expect(try await candidate.appendLedgerIDCandidate(.init(event: event)) == .inserted)
        #expect(try await candidate.appendLedgerIDCandidate(.init(event: event)) == .idAlreadyPresent)
        let other = fixture.event(id: "different").withID("event")
        #expect(try await candidate.appendLedgerIDCandidate(.init(event: other)) == .idAlreadyPresent)
        await #expect(throws: (any Error).self) { try await client.appendEvent(.init(event: event)) }
        let ledger = try await repository.eventLedgerEntries(limit: 10)
        #expect(ledger.map(\.event) == [event])
    }

    @Test func unrelatedTriggerAndProjectionErrorsRollBack() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let repository = try ProvenanceSQLiteRepository(url: fixture.url)
        let client: any ProvenanceEngineClient = repository
        let candidate = try #require(client as? any ProvenanceLedgerIDCandidateClient)
        let database = try ProvenanceSQLiteDatabase(url: fixture.url)
        try database.execute("CREATE TRIGGER reject_ledger BEFORE INSERT ON provenance_events BEGIN SELECT RAISE(ABORT, 'UNIQUE constraint failed: provenance_events.id'); END")
        await #expect(throws: (any Error).self) { try await candidate.appendLedgerIDCandidate(.init(event: fixture.event(id: "spoof"))) }
        #expect(try await repository.eventLedgerEntries(limit: 10).isEmpty)
        try database.execute("DROP TRIGGER reject_ledger")
        try database.execute("CREATE TABLE synthetic_check (value INTEGER CHECK (value > 0))")
        try database.execute("CREATE TRIGGER check_ledger BEFORE INSERT ON provenance_events BEGIN INSERT INTO synthetic_check VALUES (0); END")
        await #expect(throws: (any Error).self) { try await candidate.appendLedgerIDCandidate(.init(event: fixture.event(id: "check"))) }
        #expect(try await repository.eventLedgerEntries(limit: 10).isEmpty)
        try database.execute("DROP TRIGGER check_ledger")
        try database.execute("CREATE TRIGGER ignore_ledger BEFORE INSERT ON provenance_events BEGIN SELECT RAISE(IGNORE); END")
        await #expect(throws: (any Error).self) { try await candidate.appendLedgerIDCandidate(.init(event: fixture.event(id: "ignored"))) }
        #expect(try await repository.eventLedgerEntries(limit: 10).isEmpty)
        try database.execute("DROP TRIGGER ignore_ledger")
        try database.execute("CREATE TRIGGER reject_projection BEFORE INSERT ON provenance_sessions BEGIN SELECT RAISE(ABORT, 'constraint provenance_events'); END")
        await #expect(throws: (any Error).self) { try await candidate.appendLedgerIDCandidate(.init(event: fixture.event(id: "projection"))) }
        #expect(try await repository.eventLedgerEntries(limit: 10).isEmpty)
        try database.execute("DROP TRIGGER reject_projection")
        #expect(try await candidate.appendLedgerIDCandidate(.init(event: fixture.event(id: "projection"))) == .inserted)
    }

    @Test func separateConnectionsRaceForOneID() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let first = try ProvenanceSQLiteRepository(url: fixture.url)
        let second = try ProvenanceSQLiteRepository(url: fixture.url)
        let firstClient: any ProvenanceEngineClient = first
        let secondClient: any ProvenanceEngineClient = second
        let a = try #require(firstClient as? any ProvenanceLedgerIDCandidateClient)
        let b = try #require(secondClient as? any ProvenanceLedgerIDCandidateClient)
        let event = fixture.event(id: "race")
        async let one = a.appendLedgerIDCandidate(.init(event: event))
        async let two = b.appendLedgerIDCandidate(.init(event: event))
        let results = try await [one, two]
        #expect(results.filter { $0 == .inserted }.count == 1)
        #expect(results.filter { $0 == .idAlreadyPresent }.count == 1)
        #expect(try await first.eventLedgerEntries(limit: 10).map(\.event) == [event])
    }

    private struct Fixture {
        let directory: URL
        var url: URL { directory.appendingPathComponent("test.sqlite") }
        init() throws {
            directory = FileManager.default.temporaryDirectory.appendingPathComponent("pe-id-candidate-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        func remove() { try? FileManager.default.removeItem(at: directory) }
        func event(id: String) -> ProvenanceEvent {
            let date = Date(timeIntervalSince1970: 1_800_000_000)
            let session = ProvenanceSessionRecord(id: "session-\(id)", agentKind: "codex", status: "active", updatedAt: date)
            return ProvenanceEvent(id: id, eventType: .sessionObserved, timestamp: date, sessionID: session.id, source: .observed, confidence: .high, payload: .init(session: session))
        }
    }
}

private extension ProvenanceEvent {
    func withID(_ id: String) -> ProvenanceEvent {
        ProvenanceEvent(id: id, schemaVersion: schemaVersion, eventType: eventType, timestamp: timestamp, repositoryID: repositoryID, worktreeID: worktreeID, sessionID: sessionID, contributionID: contributionID, source: source, evidenceOrigin: evidenceOrigin, evidenceScope: evidenceScope, confidence: confidence, payload: payload)
    }
}
