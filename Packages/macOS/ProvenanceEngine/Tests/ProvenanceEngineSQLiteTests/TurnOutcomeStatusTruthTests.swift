import Foundation
import ProvenanceEngineContracts
@testable import ProvenanceEngineSQLite
import Testing

@Suite
struct TurnOutcomeStatusTruthTests {
    @Test(arguments: [
        ("incomplete", "incomplete"), ("uncompleted", "incomplete"),
        ("not_completed", "unknown"), ("unsuccessful", "unknown"),
        ("completed", "completed"), ("success", "completed"),
        ("interrupted", "interrupted"), ("cancelled", "cancelled"),
    ])
    func completionRequiresSupportedStatus(status: String, expected: String) async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("provenance.sqlite")
        let repository = try ProvenanceSQLiteRepository(url: url)
        let fixture = WorkModelFixture()
        let turn = fixture.turn(status: status)
        try await fixture.appendSessionThreadAndTurn(turn, into: repository)
        let original = try #require(await repository.turnOutcome(.init(turnID: turn.id)).outcome)
        #expect(original.lifecycleState == status)
        #expect(original.completionState == expected)
        #expect(original.projection.projectionRuleVersion == "3")
        let reopened = try ProvenanceSQLiteRepository(url: url)
        let loaded = try #require(await reopened.turnOutcome(.init(turnID: turn.id)).outcome)
        #expect(loaded.completionState == expected)
        let session = try #require(await reopened.sessionOutcome(.init(sessionID: fixture.session.id)).outcome)
        #expect(session.turnOutcomes.first?.completionState == expected)
        _ = try await reopened.rebuildProjectionsFromEventLedger()
        let replayed = try #require(await reopened.turnOutcome(.init(turnID: turn.id)).outcome)
        #expect(replayed.completionState == expected)
    }
    @Test
    func lazyUpgradeKeepsPriorArtifactQueryable() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("provenance.sqlite")
        let repository = try ProvenanceSQLiteRepository(url: url)
        let fixture = WorkModelFixture()
        let turn = fixture.turn(status: "incomplete")
        try await fixture.appendSessionThreadAndTurn(turn, into: repository)
        let database = try ProvenanceSQLiteDatabase(url: url)
        // Simulate a v2 artifact without changing its factual inputs or a real user's database.
        let clone = try database.prepare("""
            INSERT INTO provenance_coding_agent_turn_outcome_revisions
            SELECT 'legacy-v2', turn_id, session_id, projection_rule_id, '2', source_watermark_sequence,
                   content_fingerprint, json_set(outcome_json, '$.projection.revisionID', 'legacy-v2',
                       '$.projection.projectionRuleVersion', '2', '$.completionState', 'completed'), created_at_seconds
            FROM provenance_coding_agent_turn_outcome_revisions
            WHERE id = (SELECT latest_revision_id FROM provenance_coding_agent_turn_outcomes WHERE turn_id = ?)
            """)
        try clone.bind(turn.id, at: 1)
        _ = try clone.step()
        clone.finalize()
        let pointer = try database.prepare("""
            UPDATE provenance_coding_agent_turn_outcomes SET latest_revision_id = 'legacy-v2',
                projection_rule_version = '2' WHERE turn_id = ?
            """)
        try pointer.bind(turn.id, at: 1)
        _ = try pointer.step()
        pointer.finalize()
        let reopened = try ProvenanceSQLiteRepository(url: url)
        let old = try #require(await reopened.turnOutcome(.init(turnID: turn.id, revisionID: "legacy-v2")).outcome)
        #expect(old.completionState == "completed")
        let current = try #require(await reopened.turnOutcome(.init(turnID: turn.id)).outcome)
        #expect(current.projection.projectionRuleVersion == "3")
        #expect(current.completionState == "incomplete")
        let session = try #require(await reopened.sessionOutcome(.init(sessionID: fixture.session.id)).outcome)
        #expect(session.turnOutcomes.first?.completionState == "incomplete")
        let retained = try #require(await reopened.turnOutcome(.init(turnID: turn.id, revisionID: "legacy-v2")).outcome)
        #expect(retained == old)
    }

}
