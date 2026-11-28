import CryptoKit
import Foundation
import ProvenanceEngineContracts
import ProvenanceEngineSDK
import Testing

/// Synthetic ownership regression; no provider process or app is launched.
@Suite struct TurnOwnershipIsolationRegressionTests {
    @Test func disputedChildWithoutParentMarksProposalCoveragePartial() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("pe-child-proposal-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let client = try ProvenanceEngineClientFactory().sqliteClient(databaseURL: directory.appendingPathComponent("test.sqlite"))
        let time = Date(timeIntervalSince1970: 1_800_000_000)
        for id in ["A", "B"] {
            let session = ProvenanceSessionRecord(id: id, agentKind: "codex", status: "active", updatedAt: time)
            _ = try await client.appendEvent(.init(event: .init(id: "session-\(id)", eventType: .sessionObserved,
                timestamp: time, sessionID: id, source: .observed, confidence: .high, payload: .init(session: session))))
            let prompt = ProvenanceCodingAgentPromptRecord(id: "prompt-\(id)", sessionID: id, turnID: "unknown-parent",
                provider: "codex", text: "Evidence", submittedAt: time, source: .observed, confidence: .high)
            _ = try await client.appendEvent(.init(event: .init(id: "prompt-event-\(id)", eventType: .codingAgentPromptSubmitted,
                timestamp: time, sessionID: id, source: .observed, confidence: .high, payload: .init(codingAgentPrompt: prompt))))
        }
        let proposal = ProvenanceCodingAgentProposedPlanRecord(sessionID: "A", provider: "codex",
            providerSessionID: "provider-A", providerTurnID: "unmapped", providerItemID: "item",
            text: "Unknown association", truncated: false)
        _ = try await client.appendEvent(.init(event: .init(id: "proposal", eventType: .codingAgentProposedPlanObserved,
            timestamp: time, sessionID: "A", source: .observed, evidenceOrigin: .init(rawValue: "codex-transcript"),
            confidence: .high, payload: .init(codingAgentProposedPlan: proposal))))
        let snapshot = try #require(try await client.factualSessionProjection(.init(sessionID: "A")).snapshot)
        #expect(snapshot.unresolvedTurnIDs == ["unknown-parent"])
        #expect(snapshot.proposedPlanObservations.isEmpty)
        #expect(snapshot.proposedPlanCoverage?.omittedObservations == true)
    }

    @Test func conflictingOwnerDoesNotExposeForeignPromptOrCleanTurn() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("pe-turn-owner-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let client = try ProvenanceEngineClientFactory().sqliteClient(databaseURL: directory.appendingPathComponent("test.sqlite"))
        let time = Date(timeIntervalSince1970: 1_800_000_000)
        let providerTurnID = "synthetic-shared-turn"
        // Mirrors CLI/CLIProvenanceCodexTranscriptImporter+IDs.swift and its StableIDFactory.
        let digest = SHA256.hash(data: Data("codex\n\(providerTurnID)".utf8))
            .map { String(format: "%02x", $0) }.joined()
        let turnID = "coding-agent-turn-\(digest.prefix(24))"

        for sessionID in ["session-A", "session-B"] {
            let session = ProvenanceSessionRecord(id: sessionID, agentKind: "codex", status: "active", updatedAt: time)
            _ = try await client.appendEvent(.init(event: ProvenanceEvent(
                id: "event-\(sessionID)", eventType: .sessionObserved, timestamp: time,
                sessionID: sessionID, source: .observed, evidenceOrigin: .init(rawValue: "synthetic-fixture"),
                confidence: .high, payload: .init(session: session))))
        }
        func appendTurn(sessionID: String, eventID: String, offset: TimeInterval) async throws {
            let when = time.addingTimeInterval(offset)
            let turn = ProvenanceCodingAgentTurnRecord(id: turnID, sessionID: sessionID, provider: "codex",
                providerTurnID: providerTurnID, status: "started", startedAt: when, updatedAt: when,
                source: .observed, confidence: .high)
            let result = try await client.appendEvent(.init(event: ProvenanceEvent(
                id: eventID, eventType: .codingAgentTurnObserved, timestamp: when,
                sessionID: sessionID, source: .observed, evidenceOrigin: .init(rawValue: "synthetic-fixture"),
                confidence: .high, payload: .init(codingAgentTurn: turn))))
            #expect(result.eventID == eventID)
        }
        try await appendTurn(sessionID: "session-A", eventID: "turn-event-A-1", offset: 1)
        let prompt = ProvenanceCodingAgentPromptRecord(id: "prompt-A", sessionID: "session-A", turnID: turnID,
            provider: "codex", text: "Synthetic A prompt", submittedAt: time.addingTimeInterval(2),
            source: .observed, confidence: .high)
        _ = try await client.appendEvent(.init(event: ProvenanceEvent(
            id: "prompt-event-A", eventType: .codingAgentPromptSubmitted, timestamp: prompt.submittedAt,
            sessionID: "session-A", source: .observed, evidenceOrigin: .init(rawValue: "synthetic-fixture"),
            confidence: .high, payload: .init(codingAgentPrompt: prompt))))
        let plan = ProvenanceCodingAgentPlanUpdateRecord(
            id: "plan-A", sessionID: "session-A", turnID: turnID, provider: "codex",
            steps: [.init(id: "step-A", order: 0, text: "Disputed plan text", status: "in_progress")],
            observedAt: time.addingTimeInterval(2), source: .observed, confidence: .high
        )
        _ = try await client.appendEvent(.init(event: .init(
            id: "plan-event-A", eventType: .codingAgentPlanUpdated, timestamp: plan.observedAt,
            sessionID: "session-A", source: .observed, confidence: .high, payload: .init(codingAgentPlanUpdate: plan)
        )))
        let proposal = ProvenanceCodingAgentProposedPlanRecord(
            sessionID: "session-A", provider: "codex", providerSessionID: "provider-session-A",
            providerTurnID: providerTurnID, providerItemID: "item-A", text: "Disputed proposal", truncated: false
        )
        _ = try await client.appendEvent(.init(event: .init(
            id: "proposal-A", eventType: .codingAgentProposedPlanObserved, timestamp: time,
            sessionID: "session-A", source: .observed, evidenceOrigin: .init(rawValue: "codex-transcript"),
            confidence: .high, payload: .init(codingAgentProposedPlan: proposal)
        )))
        _ = try await client.publishCodingAgentSessionSemanticInferences(.init(sessionID: "session-A", createdAt: time))
        #expect(try await client.factualSessionTurnDetail(.init(turnID: turnID)).sessionID == "session-A")
        let original = try await client.turnOutcome(.init(turnID: turnID))
        #expect(original.outcome?.objective?.evidence.contains(where: { $0.eventID == "prompt-event-A" }) == true)
        let beforeConflict = try #require(try await client.factualSessionProjection(.init(sessionID: "session-A")).snapshot?.revision)
        try await appendTurn(sessionID: "session-B", eventID: "turn-event-B", offset: 3)
        let afterConflict = try #require(try await client.factualSessionProjection(.init(sessionID: "session-A")).snapshot?.revision)
        #expect(afterConflict > beforeConflict)
        for sessionID in ["session-A", "session-B"] {
            let uniqueTurn = ProvenanceCodingAgentTurnRecord(
                id: "independent-\(sessionID)", sessionID: sessionID, provider: "codex",
                providerTurnID: "independent-\(sessionID)", status: "started",
                startedAt: time.addingTimeInterval(4), updatedAt: time.addingTimeInterval(4),
                source: .observed, confidence: .high
            )
            _ = try await client.appendEvent(.init(event: ProvenanceEvent(
                id: "event-independent-\(sessionID)", eventType: .codingAgentTurnObserved,
                timestamp: uniqueTurn.updatedAt, sessionID: sessionID,
                source: .observed, confidence: .high, payload: .init(codingAgentTurn: uniqueTurn)
            )))
            let independentProposal = ProvenanceCodingAgentProposedPlanRecord(
                sessionID: sessionID, provider: "codex", providerSessionID: "provider-\(sessionID)",
                providerTurnID: uniqueTurn.providerTurnID, providerItemID: "independent-item",
                text: "Independent proposal", truncated: false
            )
            _ = try await client.appendEvent(.init(event: .init(
                id: "independent-proposal-\(sessionID)", eventType: .codingAgentProposedPlanObserved,
                timestamp: time.addingTimeInterval(4), sessionID: sessionID, source: .observed,
                evidenceOrigin: .init(rawValue: "codex-transcript"), confidence: .high,
                payload: .init(codingAgentProposedPlan: independentProposal)
            )))
            let response = try await client.factualSessionProjection(.init(sessionID: sessionID))
            let snapshot = try #require(response.snapshot)
            #expect(snapshot.turns.contains { $0.turn.id == uniqueTurn.id })
            #expect(snapshot.proposedPlanObservations.contains { $0.proposal.text == "Independent proposal" })
            let encoded = try JSONEncoder().encode(snapshot)
            let object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
            #expect((object["unresolvedTurnIDs"] as? [String]) == [turnID])
            #expect(!String(decoding: encoded, as: UTF8.self).contains("Disputed proposal"))
            let model = try #require(try await client.sessionWorkModel(.init(sessionID: sessionID)).model)
            let modelObject = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(model)) as? [String: Any])
            #expect((modelObject["unresolvedTurnIDs"] as? [String]) == [turnID])
            #expect(!String(decoding: try JSONEncoder().encode(model), as: UTF8.self).contains("Disputed plan text"))
            let safeOutcome = try #require(try await client.sessionOutcome(.init(sessionID: sessionID)).outcome)
            #expect(safeOutcome.turnOutcomes.contains { $0.turnID == uniqueTurn.id })
            #expect(!safeOutcome.turnOutcomes.contains { $0.turnID == turnID })
            #expect(safeOutcome.completeness.fields.contains { $0.reason == "ownership_unresolved" })
            let sameRevision = try await client.sessionOutcome(.init(
                sessionID: sessionID, revisionID: safeOutcome.projection.revisionID
            ))
            #expect(sameRevision.outcome == safeOutcome)
            let updatedSession = ProvenanceSessionRecord(id: sessionID, agentKind: "codex", status: "active",
                updatedAt: time.addingTimeInterval(10))
            _ = try await client.appendEvent(.init(event: .init(id: "updated-\(sessionID)", eventType: .sessionObserved,
                timestamp: updatedSession.updatedAt, sessionID: sessionID, source: .observed, confidence: .high,
                payload: .init(session: updatedSession))))
            let retainedRevision = try await client.sessionOutcome(.init(
                sessionID: sessionID, revisionID: safeOutcome.projection.revisionID
            ))
            #expect(retainedRevision.outcome == safeOutcome)
        }
        let safePrompt = ProvenanceCodingAgentPromptRecord(
            id: "safe-prompt", sessionID: "session-A", turnID: "independent-session-A", provider: "codex",
            text: "Independent work remains visible", submittedAt: time.addingTimeInterval(5),
            source: .observed, confidence: .high
        )
        _ = try await client.appendEvent(.init(event: .init(
            id: "safe-prompt-event", eventType: .codingAgentPromptSubmitted, timestamp: safePrompt.submittedAt,
            sessionID: "session-A", source: .observed, confidence: .high, payload: .init(codingAgentPrompt: safePrompt)
        )))
        _ = try await client.publishCodingAgentSessionSemanticInferences(.init(sessionID: "session-A", createdAt: time))
        let safeModel = try #require(try await client.sessionWorkModel(.init(sessionID: "session-A")).model)
        #expect(safeModel.currentTurn?.intent.record != nil)
        #expect(String(decoding: try JSONEncoder().encode(safeModel.currentTurn?.intent), as: UTF8.self)
            .contains("Independent work remains visible"))
        let bProjection = try await client.factualSessionProjection(.init(sessionID: "session-B"))
        // Proposed contract: ownership_unresolved distinguishes a conflict from absence.
        if let snapshot = bProjection.snapshot {
            #expect(bProjection.found)
            #expect(snapshot.session.id == "session-B")
            #expect(!snapshot.turns.contains(where: { $0.submittedPrompt?.sessionID == "session-A" }))
            #expect(!snapshot.turns.contains(where: { $0.turn.id == turnID }))
        } else {
            #expect(!bProjection.found)
            #expect(bProjection.reason == "ownership_unresolved")
        }
        let detail = try await client.factualSessionTurnDetail(.init(turnID: turnID))
        #expect(!detail.found)
        #expect(detail.turnDetail == nil)
        #expect(detail.reason == "ownership_unresolved")
        let outcome = try await client.turnOutcome(.init(turnID: turnID))
        #expect(!outcome.found)
        #expect(outcome.outcome == nil)
        #expect(outcome.reason == "ownership_unresolved")
        // The public SDK exposes no raw ledger event lookup or projection-disposition
        // field. Append acknowledgment does not prove later inspectability or quarantine.
    }
}
