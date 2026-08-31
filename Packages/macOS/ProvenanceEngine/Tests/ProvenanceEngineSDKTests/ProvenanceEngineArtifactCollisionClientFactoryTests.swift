import Foundation
import ProvenanceEngineContracts
import ProvenanceEngineSDK
import Testing

@Suite
struct ProvenanceEngineArtifactCollisionClientFactoryTests {
    @Test
    func sqliteClientReadsArtifactCollisionsThroughPublicContract() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let client = try ProvenanceEngineClientFactory().sqliteClient(databaseURL: url)
        let timestamp = Date(timeIntervalSince1970: 1_800_000_200)
        let repository = ProvenanceRepositoryRecord(
            id: "repository-collision-client",
            path: "/repos/collision-client",
            remoteSlug: "owner/collision-client",
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let worktree = ProvenanceWorktreeRecord(
            id: "worktree-collision-client",
            repositoryID: repository.id,
            path: repository.path,
            branch: "main",
            currentHEAD: "collision-head",
            isDirty: false,
            status: "active",
            updatedAt: timestamp
        )
        let target = ProvenanceSessionRecord(
            id: "session-collision-target-client",
            agentKind: "codex",
            worktreeID: worktree.id,
            status: "active",
            startedAt: timestamp,
            updatedAt: timestamp
        )
        let related = ProvenanceSessionRecord(
            id: "session-collision-related-client",
            agentKind: "codex",
            worktreeID: worktree.id,
            status: "active",
            startedAt: timestamp.addingTimeInterval(1),
            updatedAt: timestamp.addingTimeInterval(1)
        )

        _ = try await client.appendEvent(ProvenanceAppendEventRequest(event: ProvenanceEvent(
            id: "event-collision-client-worktree",
            eventType: .worktreeObserved,
            timestamp: timestamp,
            repositoryID: repository.id,
            worktreeID: worktree.id,
            source: .observed,
            confidence: .high,
            payload: ProvenanceEventPayload(repository: repository, worktree: worktree)
        )))
        for session in [target, related] {
            _ = try await client.appendEvent(ProvenanceAppendEventRequest(event: ProvenanceEvent(
                id: "event-\(session.id)",
                eventType: .sessionObserved,
                timestamp: session.updatedAt,
                worktreeID: session.worktreeID,
                sessionID: session.id,
                source: .observed,
                confidence: .high,
                payload: ProvenanceEventPayload(session: session)
            )))
            let thread = ProvenanceCodingAgentThreadRecord(
                id: "thread-\(session.id)",
                sessionID: session.id,
                provider: "codex",
                providerThreadID: "provider-thread-\(session.id)",
                worktreeID: worktree.id,
                source: .observed,
                confidence: .high,
                firstObservedAt: session.updatedAt,
                updatedAt: session.updatedAt
            )
            let turn = ProvenanceCodingAgentTurnRecord(
                id: "turn-\(session.id)",
                sessionID: session.id,
                threadID: thread.id,
                provider: "codex",
                providerTurnID: "provider-turn-\(session.id)",
                status: "started",
                model: "gpt-5-codex",
                effort: "medium",
                startedAt: session.updatedAt,
                completedAt: nil,
                updatedAt: session.updatedAt,
                source: .observed,
                confidence: .high
            )
            let attribution = ProvenanceCodingAgentFileChangeAttributionRecord(
                id: "file-attribution-\(session.id)",
                sessionID: session.id,
                threadID: thread.id,
                turnID: turn.id,
                provider: "codex",
                operationID: "operation-\(session.id)",
                paths: ["Sources/Shared.swift"],
                observedAt: session.updatedAt.addingTimeInterval(2),
                source: .observed,
                confidence: .high
            )
            _ = try await client.appendEvent(ProvenanceAppendEventRequest(event: ProvenanceEvent(
                id: "event-\(thread.id)",
                eventType: .codingAgentThreadObserved,
                timestamp: thread.updatedAt,
                worktreeID: worktree.id,
                sessionID: session.id,
                source: .observed,
                confidence: .high,
                payload: ProvenanceEventPayload(codingAgentThread: thread)
            )))
            _ = try await client.appendEvent(ProvenanceAppendEventRequest(event: ProvenanceEvent(
                id: "event-\(turn.id)",
                eventType: .codingAgentTurnObserved,
                timestamp: turn.updatedAt,
                sessionID: session.id,
                source: .observed,
                confidence: .high,
                payload: ProvenanceEventPayload(codingAgentTurn: turn)
            )))
            _ = try await client.appendEvent(ProvenanceAppendEventRequest(event: ProvenanceEvent(
                id: "event-\(attribution.id)",
                eventType: .codingAgentFileChangeAttributed,
                timestamp: attribution.observedAt,
                sessionID: session.id,
                source: .observed,
                confidence: .high,
                payload: ProvenanceEventPayload(codingAgentFileChangeAttribution: attribution)
            )))
        }

        let response = try await client.artifactCollisions(
            ProvenanceArtifactCollisionRequest(targetSessionID: target.id)
        )
        let candidate = try #require(response.projection?.candidates.first)

        #expect(response.found == true)
        #expect(candidate.artifactIdentity.normalizedPath == "Sources/Shared.swift")
        #expect(Set(candidate.participants.map(\.sessionID)) == Set([target.id, related.id]))
        #expect(candidate.reasons.map(\.kind).contains(.exactPathOverlap))
    }


    private static func temporaryDatabaseURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("provenance-engine-artifact-collision-sdk-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("provenance.sqlite")
    }

    private static func removeTemporaryDatabaseDirectory(for url: URL) {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }
}

@Suite
struct ProvenanceEngineRelatedSessionWorkStateSDKTests {
    @Test
    func sqliteClientReadsRelatedWorkStateSemanticsThroughPublicContract() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let client = try ProvenanceEngineClientFactory().sqliteClient(databaseURL: url)
        let timestamp = Date(timeIntervalSince1970: 1_800_000_700)
        let repository = ProvenanceRepositoryRecord(
            id: "repository-related-work-state-sdk",
            path: "/repos/related-work-state-sdk",
            remoteSlug: "owner/related-work-state-sdk",
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let worktree = ProvenanceWorktreeRecord(
            id: "worktree-related-work-state-sdk",
            repositoryID: repository.id,
            path: repository.path,
            branch: "main",
            currentHEAD: "related-work-state-head",
            isDirty: false,
            status: "active",
            updatedAt: timestamp
        )
        let target = Self.session("target", worktreeID: worktree.id, timestamp: timestamp)
        let related = Self.session("related", worktreeID: worktree.id, timestamp: timestamp.addingTimeInterval(1))
        let relatedThread = Self.thread(sessionID: related.id, worktreeID: worktree.id, timestamp: timestamp.addingTimeInterval(2))
        let relatedTurn = Self.turn(sessionID: related.id, threadID: relatedThread.id, timestamp: timestamp.addingTimeInterval(3))
        let plan = ProvenanceCodingAgentPlanUpdateRecord(
            id: "plan-\(relatedTurn.id)",
            sessionID: related.id,
            threadID: relatedThread.id,
            turnID: relatedTurn.id,
            provider: "codex",
            steps: [.init(id: "plan-step-related-sdk", order: 0, text: "Validate public related work state", status: "completed")],
            observedAt: timestamp.addingTimeInterval(4),
            source: .observed,
            confidence: .high
        )
        let assistant = ProvenanceCodingAgentAssistantMessageRecord(
            id: "assistant-related-work-state-sdk",
            sessionID: related.id,
            threadID: relatedThread.id,
            turnID: relatedTurn.id,
            provider: "codex",
            itemID: "assistant-related-work-state-sdk-item",
            text: """
            Blocker: activity=run package suite; condition=database unavailable
            Approach change: objective=validate related work state; prior=full package suite; replacement=SQLite SDK fixture; state=replaced; reason=database unavailable
            """,
            completedAt: timestamp.addingTimeInterval(5),
            source: .observed,
            confidence: .high
        )

        try await Self.appendWorktree(repository, worktree, client: client, timestamp: timestamp)
        for session in [target, related] {
            try await Self.appendSession(session, client: client)
        }
        for event in [
            ProvenanceEvent(id: "event-\(relatedThread.id)", eventType: .codingAgentThreadObserved, timestamp: relatedThread.updatedAt, worktreeID: worktree.id, sessionID: related.id, source: .observed, confidence: .high, payload: .init(codingAgentThread: relatedThread)),
            ProvenanceEvent(id: "event-\(relatedTurn.id)", eventType: .codingAgentTurnObserved, timestamp: relatedTurn.updatedAt, sessionID: related.id, source: .observed, confidence: .high, payload: .init(codingAgentTurn: relatedTurn)),
            ProvenanceEvent(id: "event-\(plan.id)", eventType: .codingAgentPlanUpdated, timestamp: plan.observedAt, sessionID: related.id, source: .observed, confidence: .high, payload: .init(codingAgentPlanUpdate: plan)),
            ProvenanceEvent(id: "event-\(assistant.id)", eventType: .codingAgentAssistantMessageCompleted, timestamp: assistant.completedAt, sessionID: related.id, source: .observed, confidence: .high, payload: .init(codingAgentAssistantMessage: assistant)),
        ] {
            _ = try await client.appendEvent(ProvenanceAppendEventRequest(event: event))
        }
        _ = try await client.publishCodingAgentSessionSemanticInferences(
            ProvenanceCodingAgentSessionSemanticInferenceRequest(sessionID: related.id, createdAt: timestamp.addingTimeInterval(20))
        )

        let brief = try #require(try await client.relatedSessions(
            ProvenanceRelatedSessionRequest(targetSessionID: target.id)
        ).projection?.relatedSessions.first)
        let blockerField = try #require(brief.semanticFields.first { $0.kind == ProvenanceCodingAgentSemanticInferenceKind.blockers.rawValue })
        let approachField = try #require(brief.semanticFields.first { $0.kind == ProvenanceCodingAgentSemanticInferenceKind.approachChanges.rawValue })
        let blockerPayload = try #require(blockerField.record.flatMap { ProvenanceCodingAgentBlockerPayload(semanticPayloadValue: $0.payload) })
        let approachPayload = try #require(approachField.record.flatMap { ProvenanceCodingAgentApproachChangePayload(semanticPayloadValue: $0.payload) })

        #expect(brief.sessionID == related.id)
        #expect(blockerField.scopeID == related.id)
        #expect(approachField.scopeID == related.id)
        #expect(blockerPayload.blockers.first?.state == .reportedOpen)
        #expect(blockerPayload.blockers.first?.sourceEvidenceRefs == [.init(kind: "coding_agent_assistant_message", id: assistant.id)])
        #expect(approachPayload.approachChanges.first?.state == .reportedReplaced)
    }

    private static func session(_ suffix: String, worktreeID: String, timestamp: Date) -> ProvenanceSessionRecord {
        ProvenanceSessionRecord(id: "session-\(suffix)-related-work-state-sdk", agentKind: "codex", worktreeID: worktreeID, status: "active", startedAt: timestamp, updatedAt: timestamp)
    }

    private static func thread(sessionID: String, worktreeID: String, timestamp: Date) -> ProvenanceCodingAgentThreadRecord {
        ProvenanceCodingAgentThreadRecord(id: "thread-\(sessionID)", sessionID: sessionID, provider: "codex", providerThreadID: "provider-thread-\(sessionID)", worktreeID: worktreeID, source: .observed, confidence: .high, firstObservedAt: timestamp, updatedAt: timestamp)
    }

    private static func turn(sessionID: String, threadID: String, timestamp: Date) -> ProvenanceCodingAgentTurnRecord {
        ProvenanceCodingAgentTurnRecord(id: "turn-\(sessionID)", sessionID: sessionID, threadID: threadID, provider: "codex", providerTurnID: "provider-turn-\(sessionID)", status: "completed", model: "gpt-5-codex", effort: "medium", startedAt: timestamp, completedAt: timestamp, updatedAt: timestamp, source: .observed, confidence: .high)
    }

    private static func appendWorktree(
        _ repository: ProvenanceRepositoryRecord,
        _ worktree: ProvenanceWorktreeRecord,
        client: ProvenanceEngineClient,
        timestamp: Date
    ) async throws {
        _ = try await client.appendEvent(ProvenanceAppendEventRequest(event: ProvenanceEvent(id: "event-\(worktree.id)", eventType: .worktreeObserved, timestamp: timestamp, repositoryID: repository.id, worktreeID: worktree.id, source: .observed, confidence: .high, payload: .init(repository: repository, worktree: worktree))))
    }

    private static func appendSession(_ session: ProvenanceSessionRecord, client: ProvenanceEngineClient) async throws {
        _ = try await client.appendEvent(ProvenanceAppendEventRequest(event: ProvenanceEvent(id: "event-\(session.id)", eventType: .sessionObserved, timestamp: session.updatedAt, worktreeID: session.worktreeID, sessionID: session.id, source: .observed, confidence: .high, payload: .init(session: session))))
    }

    private static func temporaryDatabaseURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("provenance-engine-related-work-state-sdk-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("provenance.sqlite")
    }

    private static func removeTemporaryDatabaseDirectory(for url: URL) {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }
}
