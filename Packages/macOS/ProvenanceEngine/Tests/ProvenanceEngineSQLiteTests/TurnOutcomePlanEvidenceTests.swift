import Foundation
import ProvenanceEngineContracts
@testable import ProvenanceEngineSQLite
import Testing

@Suite
struct TurnOutcomePlanEvidenceTests {
    @Test
    func completedPlanStatusRemainsReportedPlanEvidenceNotAnAccomplishment() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)
        let fixture = TurnOutcomeFixture(suffix: "plan-is-not-accomplishment")
        let plan = fixture.plan(steps: [
            ProvenanceCodingAgentPlanStepRecord(id: "reported", order: 0, text: "Apply the fix", status: "completed"),
        ])
        try await Self.seed(fixture.baseEvents(turnStatus: "completed") + [
            fixture.event(id: "reported-plan", eventType: .codingAgentPlanUpdated, timestamp: fixture.time(4),
                          payload: ProvenanceEventPayload(codingAgentPlanUpdate: plan)),
        ], into: repository)

        let turn = try #require(try await repository.turnOutcome(
            ProvenanceTurnOutcomeRequest(turnID: fixture.turnCompleted.id)
        ).outcome)
        let session = try #require(try await repository.sessionOutcome(
            ProvenanceSessionOutcomeRequest(sessionID: fixture.session.id)
        ).outcome)
        #expect(turn.planItems.map(\.status) == ["completed"])
        #expect(turn.planItems.first?.evidence.isEmpty == false)
        #expect(turn.actionsCompleted.isEmpty)
        #expect(session.actionsCompleted.isEmpty)
    }

    @Test
    func currentSessionRefreshesOldRuleWhileHistoricalTurnRemainsReadable() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)
        let fixture = TurnOutcomeFixture(suffix: "old-plan-rule")
        let plan = fixture.plan(steps: [
            ProvenanceCodingAgentPlanStepRecord(id: "old", order: 0, text: "Apply the fix", status: "completed"),
        ])
        try await Self.seed(fixture.baseEvents(turnStatus: "completed") + [
            fixture.event(id: "old-rule-plan", eventType: .codingAgentPlanUpdated, timestamp: fixture.time(4),
                          payload: ProvenanceEventPayload(codingAgentPlanUpdate: plan)),
        ], into: repository)
        let original = try #require(try await repository.turnOutcome(
            ProvenanceTurnOutcomeRequest(turnID: fixture.turnCompleted.id)
        ).outcome)
        let oldSession = try #require(try await repository.sessionOutcome(
            ProvenanceSessionOutcomeRequest(sessionID: fixture.session.id)
        ).outcome)
        let item = try #require(original.planItems.first)
        let oldAction = ProvenanceTurnOutcomeTextFact(
            id: "completed_action:\(item.id)", kind: "completed_plan_item", text: item.text, evidence: item.evidence
        )
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
        var projection = try #require(json["projection"] as? [String: Any])
        let legacyTurnID = "legacy-turn-revision"
        let legacySessionID = "legacy-session-revision"
        projection["revisionID"] = legacyTurnID
        projection["projectionRuleVersion"] = "1"
        json["projection"] = projection
        json["actionsCompleted"] = [try JSONSerialization.jsonObject(with: JSONEncoder().encode(oldAction))]
        let oldJSON = try #require(String(data: JSONSerialization.data(withJSONObject: json), encoding: .utf8))
        let database = try ProvenanceSQLiteDatabase(url: url)
        let insertTurn = try database.prepare("""
            INSERT INTO provenance_coding_agent_turn_outcome_revisions
                (id, turn_id, session_id, projection_rule_id, projection_rule_version,
                 source_watermark_sequence, content_fingerprint, outcome_json, created_at_seconds)
            SELECT ?, turn_id, session_id, projection_rule_id, '1', source_watermark_sequence,
                   content_fingerprint, ?, created_at_seconds
            FROM provenance_coding_agent_turn_outcome_revisions WHERE id = ?
            """)
        defer { insertTurn.finalize() }
        try insertTurn.bind(legacyTurnID, at: 1)
        try insertTurn.bind(oldJSON, at: 2)
        try insertTurn.bind(original.projection.revisionID, at: 3)
        _ = try insertTurn.step()
        let latest = try database.prepare("""
            UPDATE provenance_coding_agent_turn_outcomes
            SET projection_rule_version = '1', latest_revision_id = ? WHERE turn_id = ?
            """)
        defer { latest.finalize() }
        try latest.bind(legacyTurnID, at: 1)
        try latest.bind(fixture.turnCompleted.id, at: 2)
        _ = try latest.step()
        let insertSession = try database.prepare("""
            INSERT INTO provenance_coding_agent_session_outcome_revisions
                (id, session_id, projection_rule_id, projection_rule_version,
                 source_watermark_sequence, content_fingerprint, outcome_json, created_at_seconds)
            SELECT ?, session_id, projection_rule_id, projection_rule_version, source_watermark_sequence,
                   content_fingerprint, replace(replace(outcome_json, ?, ?), ?, ?), created_at_seconds
            FROM provenance_coding_agent_session_outcome_revisions WHERE id = ?
            """)
        defer { insertSession.finalize() }
        try insertSession.bind(legacySessionID, at: 1)
        try insertSession.bind(original.projection.revisionID, at: 2)
        try insertSession.bind(legacyTurnID, at: 3)
        try insertSession.bind(oldSession.projection.revisionID, at: 4)
        try insertSession.bind(legacySessionID, at: 5)
        try insertSession.bind(oldSession.projection.revisionID, at: 6)
        _ = try insertSession.step()
        let latestSession = try database.prepare("""
            UPDATE provenance_coding_agent_session_outcomes SET latest_revision_id = ? WHERE session_id = ?
            """)
        defer { latestSession.finalize() }
        try latestSession.bind(legacySessionID, at: 1)
        try latestSession.bind(fixture.session.id, at: 2)
        _ = try latestSession.step()

        // Read the session first to exercise lazy dependency refresh, not a prior turn read.
        let currentSession = try #require(try await repository.sessionOutcome(
            ProvenanceSessionOutcomeRequest(sessionID: fixture.session.id)
        ).outcome)
        #expect(currentSession.actionsCompleted.isEmpty)
        #expect(currentSession.turnOutcomes.first?.projection.projectionRuleVersion == "2")
        #expect(currentSession.projection.revisionID != legacySessionID)
        let historical = try #require(try await repository.turnOutcome(ProvenanceTurnOutcomeRequest(
            turnID: fixture.turnCompleted.id, revisionID: legacyTurnID
        )).outcome)
        #expect(historical.projection.projectionRuleVersion == "1")
        #expect(historical.actionsCompleted == [oldAction])
        let historicalSession = try #require(try await repository.sessionOutcome(ProvenanceSessionOutcomeRequest(
            sessionID: fixture.session.id, revisionID: legacySessionID
        )).outcome)
        #expect(historicalSession.turnOutcomes.first?.actionsCompleted == [oldAction])
    }

    private static func seed(_ events: [ProvenanceEvent], into repository: ProvenanceSQLiteRepository) async throws {
        for event in events {
            try await append(event, into: repository)
        }
    }

    private static func append(_ event: ProvenanceEvent, into repository: ProvenanceSQLiteRepository) async throws {
        try await repository.appendEvent(event)
    }

    private static func temporaryDatabaseURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("provenance-engine-turn-outcome-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("provenance.sqlite")
    }

    private static func removeTemporaryDatabaseDirectory(for url: URL) {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }
}
