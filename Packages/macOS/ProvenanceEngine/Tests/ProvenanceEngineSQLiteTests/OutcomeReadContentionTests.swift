import Foundation
import ProvenanceEngineContracts
@testable import ProvenanceEngineSQLite
import Testing

@Suite
struct OutcomeReadContentionTests {
    @Test(arguments: [false, true])
    func materializedOutcomeReadsDoNotNeedTheWriterLock(session: Bool) async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("outcome-read-\(UUID())/provenance.sqlite")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let repository = try ProvenanceSQLiteRepository(url: url)
        let fixture = TurnOutcomeFixture(suffix: "read-contention")
        for event in fixture.normalEvents { try await repository.appendEvent(event) }

        // Another bmux process can be importing transcripts while the UI reads outcomes.
        let writer = try ProvenanceSQLiteDatabase(url: url)
        try writer.execute("BEGIN IMMEDIATE")
        defer { try? writer.execute("ROLLBACK") }
        if session {
            let result = try await repository.sessionOutcome(
                ProvenanceSessionOutcomeRequest(sessionID: fixture.session.id)
            )
            #expect(result.outcome?.objectives.first?.text == fixture.prompt.text)
        } else {
            let result = try await repository.turnOutcome(
                ProvenanceTurnOutcomeRequest(turnID: fixture.turnCompleted.id)
            )
            #expect(result.outcome?.objective?.text == fixture.prompt.text)
        }
    }

    @Test
    func anotherTurnWithUnchangedGitContextDoesNotRewriteCompletedTurns() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("outcome-scope-\(UUID())/provenance.sqlite")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let repository = try ProvenanceSQLiteRepository(url: url)
        let fixture = TurnOutcomeFixture(suffix: "scoped")
        for event in fixture.normalEvents { try await repository.appendEvent(event) }
        let before = try await repository.turnOutcome(.init(turnID: fixture.turnCompleted.id))
        let second = ProvenanceCodingAgentTurnRecord(
            id: "second-turn", sessionID: fixture.session.id, threadID: fixture.thread.id,
            provider: "codex", providerTurnID: "second-provider-turn", status: "started",
            startedAt: fixture.time(20), updatedAt: fixture.time(20), source: .observed, confidence: .high
        )
        try await repository.appendEvent(fixture.event(
            id: "second-turn-event", eventType: .codingAgentTurnObserved, timestamp: fixture.time(20),
            payload: .init(repository: fixture.repository, worktree: fixture.worktree, codingAgentTurn: second)
        ))
        let after = try await repository.turnOutcome(.init(turnID: fixture.turnCompleted.id))
        #expect(after.outcome == before.outcome)
        let session = try await repository.sessionOutcome(.init(sessionID: fixture.session.id))
        #expect(session.outcome?.constituentTurns.count == 2)
    }

    @Test(arguments: [false, true])
    func oldProjectionRulesAreRecomputedOnRead(session: Bool) async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("outcome-rule-\(UUID())/provenance.sqlite")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let repository = try ProvenanceSQLiteRepository(url: url)
        let fixture = TurnOutcomeFixture(suffix: "old-rule")
        for event in fixture.normalEvents { try await repository.appendEvent(event) }
        let database = try ProvenanceSQLiteDatabase(url: url)
        let table = session ? "provenance_coding_agent_session_outcomes" : "provenance_coding_agent_turn_outcomes"
        try database.execute("UPDATE \(table) SET projection_rule_version = 'obsolete', latest_revision_id = 'obsolete'")
        if session {
            let result = try await repository.sessionOutcome(
                ProvenanceSessionOutcomeRequest(sessionID: fixture.session.id)
            )
            #expect(result.outcome?.projection.projectionRuleVersion == "1")
        } else {
            let result = try await repository.turnOutcome(
                ProvenanceTurnOutcomeRequest(turnID: fixture.turnCompleted.id)
            )
            #expect(result.outcome?.projection.projectionRuleVersion == "1")
        }
    }
}
