import Foundation
import ProvenanceEngineContracts
@testable import ProvenanceEngineSQLite
import Testing

@Suite
struct SessionOutcomeStatusTruthTests {
    @Test(arguments: [
        ("incomplete", "incomplete"), ("uncompleted", "incomplete"),
        ("not_completed", "unknown"), ("unsuccessful", "unknown"),
        ("completed", "completed"), ("stopped", "completed"),
        ("interrupted", "interrupted"), ("cancelled", "cancelled"),
    ])
    func lifecycleCompletionRequiresSupportedStatus(status: String, expected: String) async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("provenance.sqlite")
        let repository = try ProvenanceSQLiteRepository(url: url)
        let fixture = TurnOutcomeFixture(suffix: "status", sessionStatus: status)
        for event in fixture.baseEvents(turnStatus: "started") { try await repository.appendEvent(event) }
        let original = try #require(await repository.sessionOutcome(.init(sessionID: fixture.session.id)).outcome)
        #expect(original.lifecycleState == status)
        #expect(original.completionState == expected)
        #expect(original.projection.projectionRuleVersion == "2")
        let reopened = try ProvenanceSQLiteRepository(url: url)
        #expect(try await reopened.sessionOutcome(.init(sessionID: fixture.session.id)).outcome?.completionState == expected)
        _ = try await reopened.rebuildProjectionsFromEventLedger()
        #expect(try await reopened.sessionOutcome(.init(sessionID: fixture.session.id)).outcome?.completionState == expected)
    }

    @Test
    func lazyUpgradeKeepsPriorSessionArtifactQueryable() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("provenance.sqlite")
        let repository = try ProvenanceSQLiteRepository(url: url)
        let fixture = TurnOutcomeFixture(suffix: "legacy-session", sessionStatus: "uncompleted")
        for event in fixture.baseEvents(turnStatus: "started") { try await repository.appendEvent(event) }
        let database = try ProvenanceSQLiteDatabase(url: url)
        // Simulate an old v1 result, preserving a separately addressable historical artifact.
        let clone = try database.prepare("""
            INSERT INTO provenance_coding_agent_session_outcome_revisions
            SELECT 'legacy-session-v1', session_id, projection_rule_id, '1', source_watermark_sequence,
                   content_fingerprint, json_set(outcome_json, '$.projection.revisionID', 'legacy-session-v1',
                       '$.projection.projectionRuleVersion', '1', '$.completionState', 'completed'), created_at_seconds
            FROM provenance_coding_agent_session_outcome_revisions
            WHERE id = (SELECT latest_revision_id FROM provenance_coding_agent_session_outcomes WHERE session_id = ?)
            """)
        try clone.bind(fixture.session.id, at: 1)
        _ = try clone.step()
        clone.finalize()
        let pointer = try database.prepare("""
            UPDATE provenance_coding_agent_session_outcomes SET latest_revision_id = 'legacy-session-v1',
                projection_rule_version = '1' WHERE session_id = ?
            """)
        try pointer.bind(fixture.session.id, at: 1)
        _ = try pointer.step()
        pointer.finalize()
        let reopened = try ProvenanceSQLiteRepository(url: url)
        let old = try #require(await reopened.sessionOutcome(.init(sessionID: fixture.session.id, revisionID: "legacy-session-v1")).outcome)
        #expect(old.completionState == "completed")
        let current = try #require(await reopened.sessionOutcome(.init(sessionID: fixture.session.id)).outcome)
        #expect(current.projection.projectionRuleVersion == "2")
        #expect(current.completionState == "incomplete")
        let retained = try #require(await reopened.sessionOutcome(.init(sessionID: fixture.session.id, revisionID: "legacy-session-v1")).outcome)
        #expect(retained == old)
    }
}
