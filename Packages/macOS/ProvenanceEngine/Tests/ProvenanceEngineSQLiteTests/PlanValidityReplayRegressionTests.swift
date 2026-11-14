import Foundation
import ProvenanceEngineContracts
@testable import ProvenanceEngineSQLite
import Testing

/// Proposed safety contract; synthetic origins are labels, not provider attestations.
@Suite struct PlanValidityReplayRegressionTests {
    @Test func ambiguousLaterPlanStaysUnknownAfterReopenAndReplay() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("pe-plan-validity-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("test.sqlite")
        let repository = try ProvenanceSQLiteRepository(url: url)
        let time = Date(timeIntervalSince1970: 1_800_000_000)
        let session = ProvenanceSessionRecord(id: "session-A", agentKind: "codex", status: "active", updatedAt: time)
        let turn = ProvenanceCodingAgentTurnRecord(id: "turn-shared", sessionID: session.id, provider: "codex", providerTurnID: "shared", status: "started", startedAt: time, updatedAt: time, source: .observed, confidence: .high)
        let plans = ["structured-synthetic", "request-synthetic-1", "request-synthetic-2"].enumerated().map { index, id in
            ProvenanceCodingAgentPlanUpdateRecord(id: id, sessionID: session.id, turnID: turn.id, provider: "codex", steps: [.init(id: "step-\(index)", order: 0, text: "Synthetic step \(index)", status: index == 0 ? "in_progress" : "completed")], observedAt: time.addingTimeInterval(Double(index + 1)), source: .observed, confidence: .high)
        }
        let initial = [
            ProvenanceEvent(id: "session-event", eventType: .sessionObserved, timestamp: time, sessionID: session.id, source: .observed, confidence: .high, payload: .init(session: session)),
            ProvenanceEvent(id: "turn-event", eventType: .codingAgentTurnObserved, timestamp: time, sessionID: session.id, source: .observed, confidence: .high, payload: .init(codingAgentTurn: turn))
        ]
        for event in initial { try await repository.appendEvent(event) }
        for plan in plans {
            try await repository.appendEvent(ProvenanceEvent(id: "event-\(plan.id)", eventType: .codingAgentPlanUpdated, timestamp: plan.observedAt, sessionID: session.id, source: .observed, evidenceOrigin: .init(rawValue: plan.id), confidence: .high, payload: .init(codingAgentPlanUpdate: plan)))
        }
        // Existing payload cannot represent requests, results, causal links, or coverage.
        // These labels model indistinguishable legacy rows; proposed reason is not implemented.
        let reopened = try ProvenanceSQLiteRepository(url: url)
        for phase in 0..<2 {
            if phase == 1 { _ = try await reopened.rebuildProjectionsFromEventLedger(batchSize: 2) }
            let ledger = try await reopened.eventLedgerEntries(limit: 20)
            #expect(ledger.map(\.event.id) == initial.map(\.id) + plans.map { "event-\($0.id)" })
            #expect(ledger.compactMap(\.event.payload.codingAgentPlanUpdate) == plans)
            let result = try await reopened.turnOutcome(.init(turnID: turn.id))
            let outcome = try #require(result.outcome)
            let availability = outcome.completeness.fields.first { $0.field == "plan_items" }
            #expect(availability?.reason == "unverified_plan_evidence")
            #expect(availability?.status == "unavailable" || availability?.status == "partial")
            #expect(outcome.planItems.isEmpty)
            #expect(outcome.actionsCompleted.isEmpty)
        }
    }

    @Test func conflictingTurnOwnerRemainsUnresolvedAfterReplay() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("pe-plan-owner-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("test.sqlite")
        let repository = try ProvenanceSQLiteRepository(url: url)
        let time = Date(timeIntervalSince1970: 1_800_000_000)
        for (index, id) in ["session-A", "session-B"].enumerated() {
            let session = ProvenanceSessionRecord(id: id, agentKind: "codex", status: "active", updatedAt: time)
            try await repository.appendEvent(.init(id: "session-\(index)", eventType: .sessionObserved, timestamp: time, sessionID: id, source: .observed, confidence: .high, payload: .init(session: session)))
            let turn = ProvenanceCodingAgentTurnRecord(id: "shared-turn", sessionID: id, provider: "codex", providerTurnID: "shared", status: "started", startedAt: time, updatedAt: time, source: .observed, confidence: .high)
            try await repository.appendEvent(.init(id: "turn-\(index)", eventType: .codingAgentTurnObserved, timestamp: time, sessionID: id, source: .observed, confidence: .high, payload: .init(codingAgentTurn: turn)))
        }
        let reopened = try ProvenanceSQLiteRepository(url: url)
        for phase in 0..<2 {
            if phase == 1 { _ = try await reopened.rebuildProjectionsFromEventLedger(batchSize: 2) }
            let ledger = try await reopened.eventLedgerEntries(limit: 20)
            #expect(ledger.map(\.event.id) == ["session-0", "turn-0", "session-1", "turn-1"])
            let result = try await reopened.turnOutcome(.init(turnID: "shared-turn"))
            #expect(!result.found)
            #expect(result.outcome == nil)
            #expect(result.reason == "ownership_unresolved")
        }
    }
}
