import Foundation
import ProvenanceEngineContracts
@testable import ProvenanceEngineSQLite
import Testing

@Suite
struct ReplayEvidenceContinuityTests {
    @Test
    func replayRetainsExactCurrentAndHistoricalOutcomesWithUnrelatedEvidence() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("store.sqlite")
        let repository = try ProvenanceSQLiteRepository(url: url)
        let fixture = TurnOutcomeFixture(suffix: "stream-continuity")
        for event in fixture.normalEvents { try await repository.appendEvent(event) }
        for index in 0..<20 {
            let unrelated = ProvenanceCodingAgentPromptRecord(id: "unrelated-\(index)", sessionID: fixture.session.id,
                threadID: fixture.thread.id, turnID: "unknown-turn-\(index)", provider: "codex", text: "Other work",
                submittedAt: fixture.time(20 + Double(index)), source: .observed, confidence: .high)
            try await repository.appendEvent(fixture.event(id: "unrelated-event-\(index)", eventType: .codingAgentPromptSubmitted,
                timestamp: unrelated.submittedAt, payload: ProvenanceEventPayload(codingAgentPrompt: unrelated)))
        }
        let before = try Self.outcomeRows(url: url)
        #expect(!before.isEmpty)
        _ = try await repository.rebuildProjectionsFromEventLedger(batchSize: 7)
        let after = try Self.outcomeRows(url: url)
        #expect(after == before)
        if let path = ProcessInfo.processInfo.environment["BMUX_REPLAY_CONTINUITY_EXPORT"] {
            try Data(after.joined(separator: "\n").utf8).write(to: URL(fileURLWithPath: path), options: .atomic)
        }
        let outcome = try #require(await repository.turnOutcome(.init(turnID: fixture.turnCompleted.id)).outcome)
        #expect(outcome.objective?.text == fixture.prompt.text)
        #expect(outcome.objective?.evidence.contains { $0.recordID == fixture.prompt.id } == true)
        #expect(outcome.objective?.evidence.allSatisfy { !$0.eventID.hasPrefix("unrelated-event-") } == true)
    }

    private static func outcomeRows(url: URL) throws -> [String] {
        let database = try ProvenanceSQLiteDatabase(url: url)
        var results: [String] = []
        for table in ["provenance_coding_agent_turn_outcome_revisions", "provenance_coding_agent_session_outcome_revisions"] {
            let query = try database.prepare("SELECT id, outcome_json FROM \(table) ORDER BY id")
            defer { query.finalize() }
            while try query.step() {
                let id = try #require(query.string(at: 0))
                let json = try #require(query.string(at: 1))
                if json.isEmpty { results.append("\(table):\(id):retired"); continue }
                let object = try JSONSerialization.jsonObject(with: Data(json.utf8))
                let canonical = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
                results.append("\(table):\(id):\(String(decoding: canonical, as: UTF8.self))")
            }
        }
        return results
    }
}
