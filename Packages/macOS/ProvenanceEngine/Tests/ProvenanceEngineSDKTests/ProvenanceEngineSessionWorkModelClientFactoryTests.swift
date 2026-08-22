import Foundation
import ProvenanceEngineContracts
import ProvenanceEngineSDK
import Testing

@Suite
struct ProvenanceEngineSessionWorkModelClientFactoryTests {
    @Test
    func sqliteClientReadsSessionWorkModelThroughPublicContract() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let client = try ProvenanceEngineClientFactory().sqliteClient(databaseURL: url)
        let timestamp = Date(timeIntervalSince1970: 1_800_000_000)
        let session = ProvenanceSessionRecord(
            id: "session-work-model-sdk",
            agentKind: "codex",
            worktreeID: "worktree-work-model-sdk",
            status: "active",
            startedAt: timestamp,
            updatedAt: timestamp
        )
        let thread = ProvenanceCodingAgentThreadRecord(
            id: "thread-work-model-sdk",
            sessionID: session.id,
            provider: "codex",
            providerThreadID: "provider-thread-work-model-sdk",
            worktreeID: session.worktreeID,
            source: .observed,
            confidence: .high,
            firstObservedAt: timestamp.addingTimeInterval(1),
            updatedAt: timestamp.addingTimeInterval(1)
        )
        let turn = ProvenanceCodingAgentTurnRecord(
            id: "turn-work-model-sdk",
            sessionID: session.id,
            threadID: thread.id,
            provider: "codex",
            providerTurnID: "provider-turn-work-model-sdk",
            status: "started",
            model: "gpt-5-codex",
            effort: "medium",
            startedAt: timestamp.addingTimeInterval(2),
            completedAt: nil,
            updatedAt: timestamp.addingTimeInterval(2),
            source: .observed,
            confidence: .high
        )
        let prompt = ProvenanceCodingAgentPromptRecord(
            id: "prompt-work-model-sdk",
            sessionID: session.id,
            threadID: thread.id,
            turnID: turn.id,
            provider: "codex",
            text: "Expose SessionWorkModel through the public SDK.",
            submittedAt: timestamp.addingTimeInterval(3),
            source: .observed,
            confidence: .high
        )

        let events = [
            ProvenanceEvent(
                id: "event-\(session.id)",
                eventType: .sessionObserved,
                timestamp: session.updatedAt,
                sessionID: session.id,
                source: .observed,
                confidence: .high,
                payload: ProvenanceEventPayload(session: session)
            ),
            ProvenanceEvent(
                id: "event-\(thread.id)",
                eventType: .codingAgentThreadObserved,
                timestamp: thread.updatedAt,
                sessionID: session.id,
                source: .observed,
                confidence: .high,
                payload: ProvenanceEventPayload(codingAgentThread: thread)
            ),
            ProvenanceEvent(
                id: "event-\(turn.id)",
                eventType: .codingAgentTurnObserved,
                timestamp: turn.updatedAt,
                sessionID: session.id,
                source: .observed,
                confidence: .high,
                payload: ProvenanceEventPayload(codingAgentTurn: turn)
            ),
            ProvenanceEvent(
                id: "event-\(prompt.id)",
                eventType: .codingAgentPromptSubmitted,
                timestamp: prompt.submittedAt,
                sessionID: session.id,
                source: .observed,
                confidence: .high,
                payload: ProvenanceEventPayload(codingAgentPrompt: prompt)
            ),
        ]
        for event in events {
            _ = try await client.appendEvent(ProvenanceAppendEventRequest(event: event))
        }

        let health = try await client.health()
        let response = try await client.sessionWorkModel(
            ProvenanceSessionWorkModelRequest(sessionID: session.id)
        )
        let model = try #require(response.model)

        #expect(health.capabilities.contains(.querySessionWorkModel))
        #expect(response.found == true)
        #expect(model.identity.session == session)
        #expect(model.thread?.identity.threadID == thread.id)
        #expect(model.currentTurn?.turn == turn)
        #expect(model.currentTurn?.prompt == prompt)
        #expect(model.currentTurn?.intent.state == .unknown)
        #expect(model.milestones.state == .unknown)
    }

    private static func temporaryDatabaseURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("provenance-engine-session-work-model-sdk-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("provenance.sqlite")
    }

    private static func removeTemporaryDatabaseDirectory(for url: URL) {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }
}
