import Foundation
import ProvenanceEngineContracts
@testable import ProvenanceEngineSQLite
import Testing

@Suite
struct OutcomeRetentionTests {
    @Test
    func currentAndCitedRevisionsSurviveAutomaticRetentionAndReplay() async throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let repository = try ProvenanceSQLiteRepository(url: url)
        let fixture = TurnOutcomeFixture(suffix: "retention-current")
        for event in fixture.baseEvents(turnStatus: "completed") { try await repository.appendEvent(event) }
        let cited = try #require(try await repository.sessionOutcome(
            ProvenanceSessionOutcomeRequest(sessionID: fixture.session.id)
        ).outcome)
        try await repository.pinOutcomeRevision(cited.projection.revisionID, reason: "test citation")

        for index in 0..<15 { try await appendCommand(index, fixture: fixture, to: repository) }
        let retainedHistory = try #require(try await repository.sessionOutcome(
            ProvenanceSessionOutcomeRequest(sessionID: fixture.session.id)
        ).outcome)
        for index in 15..<18 { try await appendCommand(index, fixture: fixture, to: repository) }
        let current = try #require(try await repository.sessionOutcome(
            ProvenanceSessionOutcomeRequest(sessionID: fixture.session.id)
        ).outcome)
        let citedRead = try await repository.sessionOutcome(
            ProvenanceSessionOutcomeRequest(sessionID: fixture.session.id, revisionID: cited.projection.revisionID)
        )
        #expect(citedRead.outcome == cited)
        #expect(try await repository.sessionOutcome(
            ProvenanceSessionOutcomeRequest(sessionID: fixture.session.id, revisionID: retainedHistory.projection.revisionID)
        ).outcome == retainedHistory)
        #expect(current.commandsCompleted.count == 18)
        #expect(try payloadCount(url, table: "provenance_coding_agent_session_outcome_revisions") <= 10)

        _ = try await repository.rebuildProjectionsFromEventLedger(batchSize: 3)
        let replayed = try #require(try await repository.sessionOutcome(
            ProvenanceSessionOutcomeRequest(sessionID: fixture.session.id)
        ).outcome)
        #expect(replayed == current)
        #expect(try await repository.sessionOutcome(
            ProvenanceSessionOutcomeRequest(sessionID: fixture.session.id, revisionID: cited.projection.revisionID)
        ).outcome == cited)
    }

    @Test
    func legacyPruningNeedsCitationIndexAndRerunsAfterInterruption() async throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let fixture = TurnOutcomeFixture(suffix: "retention-légacy")
        let old = try ProvenanceSQLiteRepository(
            url: url, migrations: ProvenanceSQLiteRepository.migrations.filter { $0.version <= 28 }
        )
        for event in fixture.baseEvents(turnStatus: "completed") { try await old.appendEvent(event) }
        let oldest = try #require(try await old.sessionOutcome(
            ProvenanceSessionOutcomeRequest(sessionID: fixture.session.id)
        ).outcome)
        for index in 0..<18 { try await appendCommand(index, fixture: fixture, to: old) }
        let before = try #require(try await old.sessionOutcome(
            ProvenanceSessionOutcomeRequest(sessionID: fixture.session.id)
        ).outcome)

        let migrated = try ProvenanceSQLiteRepository(url: url)
        // A legacy ID can be refreshed after migration without becoming a new revision.
        // Simulate the resulting watermark advance and prove the live writer still protects it.
        let legacyDatabase = try ProvenanceSQLiteDatabase(url: url)
        try legacyDatabase.execute(
            """
            UPDATE provenance_coding_agent_session_outcome_revisions
            SET source_watermark_sequence = (SELECT legacy_event_watermark + 1 FROM provenance_outcome_retention_state)
            WHERE id IN (
                SELECT id FROM provenance_coding_agent_session_outcome_revisions
                ORDER BY source_watermark_sequence DESC LIMIT 12
            )
            """
        )
        let legacyPayloads = try payloadCount(url, table: "provenance_coding_agent_session_outcome_revisions")
        try await migrated.retireSupersededOutcomePayloads(sessionIDs: [fixture.session.id], turnIDs: [])
        #expect(try payloadCount(url, table: "provenance_coding_agent_session_outcome_revisions") == legacyPayloads)
        try await appendCommand(18, fixture: fixture, to: migrated)
        let mixedCurrent = try #require(try await migrated.sessionOutcome(
            ProvenanceSessionOutcomeRequest(sessionID: fixture.session.id)
        ).outcome)
        #expect(mixedCurrent.commandsCompleted.count == 19)
        await #expect(throws: ProvenanceSQLiteError.self) {
            _ = try await migrated.pruneOutcomePayloads(dryRun: true)
        }
        try await migrated.indexLegacyOutcomeCitations()
        let estimate = try await migrated.pruneOutcomePayloads(dryRun: true, batchSize: 1)
        #expect(estimate.candidateRows == 1)
        let candidatePayload = try #require(try firstSessionPruneCandidatePayload(url))
        #expect(candidatePayload.utf8.count > candidatePayload.count)
        #expect(estimate.candidateBytes == Int64(candidatePayload.utf8.count))
        #expect(estimate.prunedRows == 0)
        let first = try await migrated.pruneOutcomePayloads(dryRun: false, batchSize: 1)
        #expect(first.prunedRows == 1)

        let resumed = try ProvenanceSQLiteRepository(url: url)
        var removed = 1
        while true {
            let pass = try await resumed.pruneOutcomePayloads(dryRun: false, batchSize: 3)
            removed += pass.prunedRows
            if pass.prunedRows == 0 { break }
        }
        #expect(removed > 1)
        #expect(try await resumed.pruneOutcomePayloads(dryRun: false).prunedRows == 0)
        let after = try #require(try await resumed.sessionOutcome(
            ProvenanceSessionOutcomeRequest(sessionID: fixture.session.id)
        ).outcome)
        #expect(after == mixedCurrent)
        #expect(after.projection.revisionID != before.projection.revisionID)
        let retired = try await resumed.sessionOutcome(
            ProvenanceSessionOutcomeRequest(sessionID: fixture.session.id, revisionID: oldest.projection.revisionID)
        )
        #expect(retired.found == false)
        #expect(retired.reason == "revision_payload_expired")
    }

    private func appendCommand(
        _ index: Int,
        fixture: TurnOutcomeFixture,
        to repository: ProvenanceSQLiteRepository
    ) async throws {
        let command = fixture.command(
            id: "retention-command-\(index)",
            command: "swift test --filter Retention\(index)",
            status: "succeeded",
            exitCode: 0
        )
        try await repository.appendEvent(fixture.event(
            id: "retention-event-\(index)",
            eventType: .codingAgentCommandCompleted,
            timestamp: fixture.time(Double(index) + 10),
            payload: ProvenanceEventPayload(codingAgentCommand: command)
        ))
    }

    private func firstSessionPruneCandidatePayload(_ url: URL) throws -> String? {
        let database = try ProvenanceSQLiteDatabase(url: url)
        let query = try database.prepare(
            """
            WITH eligible AS (
                SELECT r.outcome_json,
                       row_number() OVER (PARTITION BY r.session_id
                                          ORDER BY r.source_watermark_sequence DESC, r.id DESC) AS ordinal
                FROM provenance_coding_agent_session_outcome_revisions r
                WHERE r.outcome_json <> ''
                  AND NOT EXISTS (
                      SELECT 1 FROM provenance_coding_agent_session_outcomes c WHERE c.latest_revision_id = r.id
                  )
                  AND NOT EXISTS (SELECT 1 FROM provenance_outcome_revision_pins p WHERE p.revision_id = r.id)
                  AND NOT EXISTS (
                      SELECT 1 FROM provenance_outcome_revision_citations c WHERE c.target_revision_id = r.id
                  )
            )
            SELECT outcome_json FROM eligible WHERE ordinal > 8 LIMIT 1
            """
        )
        defer { query.finalize() }
        guard try query.step() else { return nil }
        return query.string(at: 0)
    }

    private func payloadCount(_ url: URL, table: String) throws -> Int {
        let database = try ProvenanceSQLiteDatabase(url: url)
        let query = try database.prepare("SELECT count(*) FROM \(table) WHERE outcome_json <> ''")
        defer { query.finalize() }
        guard try query.step() else { return 0 }
        return query.int(at: 0)
    }

    private func temporaryURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("provenance-outcome-retention", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("provenance.sqlite")
    }
}
