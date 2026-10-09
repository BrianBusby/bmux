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
        _ = try await repository.rebuildProjectionsFromEventLedger()
        let rebuilt = try await repository.turnOutcome(.init(turnID: fixture.turnCompleted.id))
        #expect(rebuilt.outcome == after.outcome)
        let rebuiltSession = try await repository.sessionOutcome(.init(sessionID: fixture.session.id))
        #expect(rebuiltSession.outcome == session.outcome)
    }

    @Test
    func movingPromptRefreshesBothTurnOwners() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("outcome-move-\(UUID())/provenance.sqlite")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let repository = try ProvenanceSQLiteRepository(url: url)
        let fixture = TurnOutcomeFixture(suffix: "move")
        for event in fixture.normalEvents { try await repository.appendEvent(event) }
        let second = ProvenanceCodingAgentTurnRecord(
            id: "second-turn", sessionID: fixture.session.id, threadID: fixture.thread.id,
            provider: "codex", providerTurnID: "second-provider-turn", status: "started",
            startedAt: fixture.time(20), updatedAt: fixture.time(20), source: .observed, confidence: .high
        )
        try await repository.appendEvent(fixture.event(
            id: "second-turn-event", eventType: .codingAgentTurnObserved, timestamp: fixture.time(20),
            payload: .init(codingAgentTurn: second)
        ))
        let prompt = ProvenanceCodingAgentPromptRecord(
            id: fixture.prompt.id, sessionID: fixture.session.id, threadID: fixture.thread.id,
            turnID: second.id, provider: "codex", text: fixture.prompt.text,
            submittedAt: fixture.time(21), source: .observed, confidence: .high
        )
        try await repository.appendEvent(fixture.event(
            id: "moved-prompt-event", eventType: .codingAgentPromptSubmitted, timestamp: fixture.time(21),
            payload: .init(codingAgentPrompt: prompt)
        ))
        let previous = try await repository.turnOutcome(.init(turnID: fixture.turnCompleted.id))
        let current = try await repository.turnOutcome(.init(turnID: second.id))
        #expect(previous.outcome?.objective == nil)
        #expect(current.outcome?.objective?.text == prompt.text)
    }

    @Test
    func sessionReadRecoversObsoleteConstituentTurn() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("outcome-dependency-\(UUID())/provenance.sqlite")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let repository = try ProvenanceSQLiteRepository(url: url)
        let fixture = TurnOutcomeFixture(suffix: "dependency")
        for event in fixture.normalEvents { try await repository.appendEvent(event) }
        let database = try ProvenanceSQLiteDatabase(url: url)
        try database.execute("UPDATE provenance_coding_agent_turn_outcomes SET projection_rule_version = 'obsolete', latest_revision_id = 'obsolete'")
        let result = try await repository.sessionOutcome(.init(sessionID: fixture.session.id))
        #expect(result.outcome?.objectives.first?.text == fixture.prompt.text)
        // Recovery must be complete, so a subsequent turn read needs no write lock.
        try database.execute("BEGIN IMMEDIATE")
        defer { try? database.execute("ROLLBACK") }
        let turn = try await repository.turnOutcome(.init(turnID: fixture.turnCompleted.id))
        #expect(turn.outcome?.objective?.text == fixture.prompt.text)
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
