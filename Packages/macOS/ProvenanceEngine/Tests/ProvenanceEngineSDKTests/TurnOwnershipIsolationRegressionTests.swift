import CryptoKit
import Foundation
import ProvenanceEngineContracts
import ProvenanceEngineSDK
import Testing

/// Synthetic ownership regression; no provider process or app is launched.
@Suite struct TurnOwnershipIsolationRegressionTests {
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
        #expect(try await client.factualSessionTurnDetail(.init(turnID: turnID)).sessionID == "session-A")
        let original = try await client.turnOutcome(.init(turnID: turnID))
        #expect(original.outcome?.objective?.evidence.contains(where: { $0.eventID == "prompt-event-A" }) == true)
        try await appendTurn(sessionID: "session-B", eventID: "turn-event-B", offset: 3)
        let bProjection = try await client.factualSessionProjection(.init(sessionID: "session-B"))
        #expect(!(bProjection.snapshot?.turns.contains(where: { $0.submittedPrompt?.sessionID == "session-A" }) ?? false))
        let detail = try await client.factualSessionTurnDetail(.init(turnID: turnID))
        #expect(detail.turnDetail == nil)
        let outcome = try await client.turnOutcome(.init(turnID: turnID))
        #expect(outcome.outcome == nil)
        // The public SDK exposes no raw ledger event lookup; append acknowledgment
        // alone does not prove later inspectability or quarantine.
    }
}
