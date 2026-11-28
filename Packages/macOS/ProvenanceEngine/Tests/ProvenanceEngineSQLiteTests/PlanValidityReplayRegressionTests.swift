import Foundation
import ProvenanceEngineContracts
@testable import ProvenanceEngineSQLite
import Testing

/// Ownership replay contract; synthetic origins are labels, not provider attestations.
@Suite struct PlanValidityReplayRegressionTests {
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
        let independent = ProvenanceCodingAgentTurnRecord(id: "independent-turn", sessionID: "session-A", provider: "codex", providerTurnID: "independent", status: "started", startedAt: time, updatedAt: time, source: .observed, confidence: .high)
        try await repository.appendEvent(.init(id: "turn-independent", eventType: .codingAgentTurnObserved, timestamp: time, sessionID: "session-A", source: .observed, confidence: .high, payload: .init(codingAgentTurn: independent)))
        // This is a second connection while the original is alive, not a process restart.
        let reopened = try ProvenanceSQLiteRepository(url: url)
        for phase in 0..<2 {
            if phase == 1 { _ = try await reopened.rebuildProjectionsFromEventLedger(batchSize: 2) }
            let ledger = try await reopened.eventLedgerEntries(limit: 20)
            #expect(ledger.map(\.event.id) == ["session-0", "turn-0", "session-1", "turn-1", "turn-independent"])
            let control = try await reopened.turnOutcome(.init(turnID: "independent-turn"))
            #expect(control.found)
            #expect(control.outcome?.sessionID == "session-A")
            let result = try await reopened.turnOutcome(.init(turnID: "shared-turn"))
            #expect(!result.found)
            #expect(result.outcome == nil)
            #expect(result.reason == "ownership_unresolved")
        }
    }
    @Test func childOnlyTurnClaimInvalidatesBothSessionsAndSurvivesReplay() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("pe-child-owner-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("test.sqlite")
        let repository = try ProvenanceSQLiteRepository(url: url)
        let time = Date(timeIntervalSince1970: 1_800_000_000)
        for id in ["session-A", "session-B", "session-C"] {
            let session = ProvenanceSessionRecord(id: id, agentKind: "codex", status: "active", updatedAt: time)
            try await repository.appendEvent(.init(
                id: "event-\(id)", eventType: .sessionObserved, timestamp: time,
                sessionID: id, source: .observed, confidence: .high, payload: .init(session: session)
            ))
        }
        let turn = ProvenanceCodingAgentTurnRecord(
            id: "shared-turn", sessionID: "session-A", provider: "codex", providerTurnID: "provider-turn",
            status: "started", startedAt: time, updatedAt: time, source: .observed, confidence: .high
        )
        try await repository.appendEvent(.init(
            id: "event-owner-A", eventType: .codingAgentTurnObserved, timestamp: time,
            sessionID: "session-A", source: .observed,
            evidenceOrigin: .init(rawValue: "synthetic-turn-owner"), confidence: .high,
            payload: .init(codingAgentTurn: turn)
        ))
        let independentTurn = ProvenanceCodingAgentTurnRecord(
            id: "independent-turn", sessionID: "session-C", provider: "codex", providerTurnID: "other-turn",
            status: "started", startedAt: time, updatedAt: time, source: .observed, confidence: .high
        )
        let independentPrompt = ProvenanceCodingAgentPromptRecord(
            id: "child-C", sessionID: "session-C", turnID: independentTurn.id, provider: "codex",
            text: "Independent C prompt", submittedAt: time, source: .observed, confidence: .high
        )
        try await repository.appendEvent(.init(
            id: "event-owner-C", eventType: .codingAgentTurnObserved, timestamp: time,
            sessionID: "session-C", source: .observed, confidence: .high,
            payload: .init(codingAgentTurn: independentTurn)
        ))
        try await repository.appendEvent(.init(
            id: "event-child-C", eventType: .codingAgentPromptSubmitted, timestamp: time,
            sessionID: "session-C", source: .observed,
            evidenceOrigin: .init(rawValue: "synthetic-independent-child"), confidence: .high,
            payload: .init(codingAgentPrompt: independentPrompt)
        ))
        // Populate both current session/outcome reads before a child-only conflicting claim.
        for sessionID in ["session-A", "session-B"] {
            #expect(try await repository.factualSessionProjection(.init(sessionID: sessionID)).found)
            #expect(try await repository.sessionOutcome(.init(sessionID: sessionID)).found)
        }
        let originalA = try await repository.factualSessionProjection(.init(sessionID: "session-A"))
        let originalB = try await repository.factualSessionProjection(.init(sessionID: "session-B"))
        #expect(originalA.snapshot?.latestTurn?.turn.id == turn.id)
        #expect(originalB.snapshot?.latestTurn == nil)
        let prompt = ProvenanceCodingAgentPromptRecord(
            id: "child-B", sessionID: "session-B", turnID: turn.id, provider: "codex",
            text: "Synthetic B-only prompt", submittedAt: time.addingTimeInterval(1),
            source: .observed, confidence: .high
        )
        let conflicting = ProvenanceEvent(
            id: "event-child-B", eventType: .codingAgentPromptSubmitted, timestamp: prompt.submittedAt,
            sessionID: "session-B", source: .observed,
            evidenceOrigin: .init(rawValue: "synthetic-child-claim"), confidence: .high,
            payload: .init(codingAgentPrompt: prompt)
        )
        try await repository.appendEvent(conflicting)
        // Hide the disputed turn while preserving independent facts.
        // No conflicting codingAgentTurn payload is present in the second claim.
        // The second connection coexists with the first; it is not a process restart.
        let reopened = try ProvenanceSQLiteRepository(url: url)
        for phase in 0..<3 {
            if phase == 2 { _ = try await reopened.rebuildProjectionsFromEventLedger(batchSize: 2) }
            let reader = phase == 0 ? repository : reopened
            let ledger = try await reader.eventLedgerEntries(limit: 20)
            let ownerEvidence = ledger.first { $0.event.id == "event-owner-A" }?.event
            let childEvidence = ledger.first { $0.event.id == conflicting.id }?.event
            #expect(ownerEvidence?.payload.codingAgentTurn == turn)
            #expect(ownerEvidence?.evidenceOrigin?.rawValue == "synthetic-turn-owner")
            #expect(childEvidence == conflicting)
            #expect(childEvidence?.payload.codingAgentTurn == nil)
            let independentEvidence = ledger.first { $0.event.id == "event-child-C" }?.event
            #expect(independentEvidence?.payload.codingAgentPrompt == independentPrompt)
            #expect(independentEvidence?.evidenceOrigin?.rawValue == "synthetic-independent-child")
            let independent = try await reader.factualSessionProjection(.init(sessionID: "session-C"))
            #expect(independent.found)
            #expect(independent.snapshot?.latestTurn?.turn.id == independentTurn.id)
            #expect(independent.snapshot?.latestTurn?.submittedPrompt == independentPrompt)
            let independentDetail = try await reader.factualSessionTurnDetail(.init(turnID: independentTurn.id))
            #expect(independentDetail.found)
            #expect(independentDetail.turnDetail?.submittedPrompt == independentPrompt)
            let independentOutcome = try await reader.sessionOutcome(.init(sessionID: "session-C"))
            #expect(independentOutcome.found)
            #expect(independentOutcome.outcome?.sessionID == "session-C")
            for sessionID in ["session-A", "session-B"] {
                let factual = try await reader.factualSessionProjection(.init(sessionID: sessionID))
                #expect(factual.found)
                #expect(factual.snapshot?.unresolvedTurnIDs == [turn.id])
                #expect(factual.snapshot?.latestTurn == nil)
                #expect(factual.snapshot?.priorTurns.isEmpty == true)
                let outcome = try await reader.sessionOutcome(.init(sessionID: sessionID))
                #expect(outcome.found)
                #expect(outcome.outcome?.sessionID == sessionID)
                #expect(outcome.outcome?.completeness.fields.contains { $0.reason == "ownership_unresolved" } == true)
            }
            let detail = try await reader.factualSessionTurnDetail(.init(turnID: turn.id))
            #expect(!detail.found)
            #expect(detail.reason == "ownership_unresolved")
            #expect(detail.turnDetail == nil)
            let outcome = try await reader.turnOutcome(.init(turnID: turn.id))
            #expect(!outcome.found)
            #expect(outcome.reason == "ownership_unresolved")
            #expect(outcome.outcome == nil)
        }
    }

}
