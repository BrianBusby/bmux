import Foundation
import ProvenanceEngineContracts
@testable import ProvenanceEngineSQLite
import Testing

@Suite
struct ProposedPlanLedgerTests {
    @Test
    func proposedPlanRemainsDistinctInLedgerAfterReopen() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("pe-proposed-plan-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("provenance.sqlite")
        let plan = ProvenanceCodingAgentProposedPlanRecord(
            sessionID: "session", provider: "codex", providerSessionID: "thread",
            providerTurnID: "turn", providerItemID: "item", text: "Inspect then validate", truncated: false
        )
        let event = ProvenanceEvent(
            id: "proposal", eventType: .codingAgentProposedPlanObserved,
            timestamp: Date(timeIntervalSince1970: 1_800_000_000),
            sessionID: "session", source: .observed, confidence: .high,
            payload: ProvenanceEventPayload(codingAgentProposedPlan: plan)
        )
        let writer = try ProvenanceSQLiteRepository(url: url)
        try await writer.appendEvent(event)
        let reader = try ProvenanceSQLiteRepository(url: url)
        let stored = try await reader.event(id: event.id)
        #expect(stored?.payload.codingAgentProposedPlan == plan)
        #expect(stored?.payload.codingAgentPlanUpdate == nil)
        #expect(try await reader.eventLedgerEntries(limit: 10).first?.event == event)
    }

}
