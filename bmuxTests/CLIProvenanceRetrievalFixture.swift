import Foundation
import ProvenanceEngineContracts
import ProvenanceEngineSDK
import Testing

enum CLIProvenanceRetrievalFixture {
    struct Seed {
        let targetSessionID: String
        let relatedSessionID: String
        let sharedArtifactPath: String
    }

    static func jsonPayload(_ output: String) throws -> [String: Any] {
        try #require(JSONSerialization.jsonObject(with: Data(output.utf8)) as? [String: Any])
    }

    static func seed(databaseURL: URL) async throws -> Seed {
        let client = try ProvenanceEngineClientFactory().sqliteClient(databaseURL: databaseURL)
        let timestamp = Date(timeIntervalSince1970: 1_800_020_000)
        let repository = ProvenanceRepositoryRecord(
            id: "repository-retrieval",
            path: "/repos/retrieval",
            remoteSlug: "owner/retrieval",
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let worktreeA = worktree(
            id: "worktree-retrieval-a",
            repositoryID: repository.id,
            path: "/repos/retrieval-a",
            branch: "feature/session-a",
            head: "head-session-a",
            timestamp: timestamp
        )
        let worktreeB = worktree(
            id: "worktree-retrieval-b",
            repositoryID: repository.id,
            path: "/repos/retrieval-b",
            branch: "feature/session-b",
            head: "head-session-b",
            timestamp: timestamp.addingTimeInterval(1)
        )
        let sessionA = session(
            id: "session-retrieval-a",
            worktree: worktreeA,
            timestamp: timestamp.addingTimeInterval(2)
        )
        let sessionB = session(
            id: "session-retrieval-b",
            worktree: worktreeB,
            timestamp: timestamp.addingTimeInterval(4)
        )

        try await appendWorktree(repository, worktreeA, client: client, timestamp: timestamp)
        try await appendWorktree(repository, worktreeB, client: client, timestamp: timestamp.addingTimeInterval(1))
        try await appendSession(sessionA, client: client)
        try await appendSession(sessionB, client: client)
        try await appendCodingAgentActivity(
            session: sessionA,
            worktree: worktreeA,
            artifactPath: "Sources/Shared.swift",
            includeWorkStateSemantics: true,
            client: client,
            timestamp: timestamp.addingTimeInterval(10)
        )
        try await appendCodingAgentActivity(
            session: sessionB,
            worktree: worktreeB,
            artifactPath: "Sources/Shared.swift",
            includeWorkStateSemantics: false,
            client: client,
            timestamp: timestamp.addingTimeInterval(20)
        )
        _ = try await client.publishCodingAgentSessionSemanticInferences(
            ProvenanceCodingAgentSessionSemanticInferenceRequest(
                sessionID: sessionA.id,
                createdAt: timestamp.addingTimeInterval(40)
            )
        )
        return Seed(
            targetSessionID: sessionB.id,
            relatedSessionID: sessionA.id,
            sharedArtifactPath: "Sources/Shared.swift"
        )
    }

    private static func worktree(
        id: String,
        repositoryID: String,
        path: String,
        branch: String,
        head: String,
        timestamp: Date
    ) -> ProvenanceWorktreeRecord {
        ProvenanceWorktreeRecord(
            id: id,
            repositoryID: repositoryID,
            path: path,
            branch: branch,
            currentHEAD: head,
            isDirty: false,
            status: "active",
            updatedAt: timestamp
        )
    }

    private static func session(
        id: String,
        worktree: ProvenanceWorktreeRecord,
        timestamp: Date
    ) -> ProvenanceSessionRecord {
        ProvenanceSessionRecord(
            id: id,
            agentKind: "codex",
            worktreeID: worktree.id,
            cwd: worktree.path,
            status: "active",
            startedAt: timestamp,
            updatedAt: timestamp
        )
    }

    private static func appendWorktree(
        _ repository: ProvenanceRepositoryRecord,
        _ worktree: ProvenanceWorktreeRecord,
        client: any ProvenanceEngineClient,
        timestamp: Date
    ) async throws {
        _ = try await client.appendEvent(ProvenanceAppendEventRequest(event: ProvenanceEvent(
            id: "event-\(worktree.id)",
            eventType: .worktreeObserved,
            timestamp: timestamp,
            repositoryID: repository.id,
            worktreeID: worktree.id,
            source: .observed,
            confidence: .high,
            payload: ProvenanceEventPayload(repository: repository, worktree: worktree)
        )))
    }

    private static func appendSession(
        _ session: ProvenanceSessionRecord,
        client: any ProvenanceEngineClient
    ) async throws {
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
    }

    private static func appendCodingAgentActivity(
        session: ProvenanceSessionRecord,
        worktree: ProvenanceWorktreeRecord,
        artifactPath: String,
        includeWorkStateSemantics: Bool,
        client: any ProvenanceEngineClient,
        timestamp: Date
    ) async throws {
        let thread = ProvenanceCodingAgentThreadRecord(
            id: "thread-\(session.id)",
            sessionID: session.id,
            provider: "codex",
            providerThreadID: "provider-thread-\(session.id)",
            worktreeID: worktree.id,
            source: .observed,
            confidence: .high,
            firstObservedAt: timestamp,
            updatedAt: timestamp
        )
        let turn = ProvenanceCodingAgentTurnRecord(
            id: "turn-\(session.id)",
            sessionID: session.id,
            threadID: thread.id,
            provider: "codex",
            providerTurnID: "provider-turn-\(session.id)",
            status: "completed",
            model: "gpt-5-codex",
            effort: "medium",
            startedAt: timestamp.addingTimeInterval(1),
            completedAt: timestamp.addingTimeInterval(4),
            updatedAt: timestamp.addingTimeInterval(4),
            source: .observed,
            confidence: .high
        )
        let plan = ProvenanceCodingAgentPlanUpdateRecord(
            id: "plan-\(turn.id)",
            sessionID: session.id,
            threadID: thread.id,
            turnID: turn.id,
            provider: "codex",
            steps: [
                ProvenanceCodingAgentPlanStepRecord(
                    id: "plan-step-\(session.id)",
                    order: 0,
                    text: "Validate agent-accessible retrieval",
                    status: "completed"
                ),
            ],
            observedAt: timestamp.addingTimeInterval(2),
            source: .observed,
            confidence: .high
        )
        let command = ProvenanceCodingAgentCommandRecord(
            id: "command-\(turn.id)",
            sessionID: session.id,
            threadID: thread.id,
            turnID: turn.id,
            provider: "codex",
            operationID: "operation-command-\(session.id)",
            command: "swift test --package-path Packages/macOS/ProvenanceEngine",
            cwd: worktree.path,
            status: "succeeded",
            exitCode: 0,
            outputSummary: "deterministic fixture validation",
            startedAt: timestamp.addingTimeInterval(3),
            completedAt: timestamp.addingTimeInterval(4),
            source: .observed,
            confidence: .high
        )
        let fileAttribution = ProvenanceCodingAgentFileChangeAttributionRecord(
            id: "file-attribution-\(session.id)",
            sessionID: session.id,
            threadID: thread.id,
            turnID: turn.id,
            provider: "codex",
            operationID: "operation-file-\(session.id)",
            paths: [artifactPath],
            summary: "Changed \(artifactPath)",
            observedAt: timestamp.addingTimeInterval(5),
            source: .observed,
            confidence: .high
        )
        var events = [
            event(thread, type: .codingAgentThreadObserved, worktree: worktree, session: session),
            event(turn, type: .codingAgentTurnObserved, worktree: worktree, session: session),
            event(plan, type: .codingAgentPlanUpdated, worktree: worktree, session: session),
            event(command, type: .codingAgentCommandCompleted, worktree: worktree, session: session),
            event(
                fileAttribution,
                type: .codingAgentFileChangeAttributed,
                worktree: worktree,
                session: session
            ),
        ]
        if includeWorkStateSemantics {
            let assistant = ProvenanceCodingAgentAssistantMessageRecord(
                id: "assistant-\(session.id)",
                sessionID: session.id,
                threadID: thread.id,
                turnID: turn.id,
                provider: "codex",
                itemID: "assistant-item-\(session.id)",
                text: """
                Blocker: activity=run package suite; condition=database unavailable
                Approach change: objective=validate retrieval; prior=full package suite; replacement=SQLite SDK fixture; state=replaced; reason=database unavailable
                """,
                completedAt: timestamp.addingTimeInterval(6),
                source: .observed,
                confidence: .high
            )
            events.append(event(
                assistant,
                type: .codingAgentAssistantMessageCompleted,
                worktree: worktree,
                session: session
            ))
        }
        for event in events {
            _ = try await client.appendEvent(ProvenanceAppendEventRequest(event: event))
        }
    }
}

private func event(
    _ thread: ProvenanceCodingAgentThreadRecord,
    type: ProvenanceEventType,
    worktree: ProvenanceWorktreeRecord,
    session: ProvenanceSessionRecord
) -> ProvenanceEvent {
    ProvenanceEvent(
        id: "event-\(thread.id)",
        eventType: type,
        timestamp: thread.updatedAt,
        worktreeID: worktree.id,
        sessionID: session.id,
        source: .observed,
        confidence: .high,
        payload: ProvenanceEventPayload(codingAgentThread: thread)
    )
}

private func event(
    _ turn: ProvenanceCodingAgentTurnRecord,
    type: ProvenanceEventType,
    worktree: ProvenanceWorktreeRecord,
    session: ProvenanceSessionRecord
) -> ProvenanceEvent {
    ProvenanceEvent(
        id: "event-\(turn.id)",
        eventType: type,
        timestamp: turn.updatedAt,
        worktreeID: worktree.id,
        sessionID: session.id,
        source: .observed,
        confidence: .high,
        payload: ProvenanceEventPayload(codingAgentTurn: turn)
    )
}

private func event(
    _ plan: ProvenanceCodingAgentPlanUpdateRecord,
    type: ProvenanceEventType,
    worktree: ProvenanceWorktreeRecord,
    session: ProvenanceSessionRecord
) -> ProvenanceEvent {
    ProvenanceEvent(
        id: "event-\(plan.id)",
        eventType: type,
        timestamp: plan.observedAt,
        worktreeID: worktree.id,
        sessionID: session.id,
        source: .observed,
        confidence: .high,
        payload: ProvenanceEventPayload(codingAgentPlanUpdate: plan)
    )
}

private func event(
    _ command: ProvenanceCodingAgentCommandRecord,
    type: ProvenanceEventType,
    worktree: ProvenanceWorktreeRecord,
    session: ProvenanceSessionRecord
) -> ProvenanceEvent {
    ProvenanceEvent(
        id: "event-\(command.id)",
        eventType: type,
        timestamp: command.completedAt,
        worktreeID: worktree.id,
        sessionID: session.id,
        source: .observed,
        confidence: .high,
        payload: ProvenanceEventPayload(codingAgentCommand: command)
    )
}

private func event(
    _ attribution: ProvenanceCodingAgentFileChangeAttributionRecord,
    type: ProvenanceEventType,
    worktree: ProvenanceWorktreeRecord,
    session: ProvenanceSessionRecord
) -> ProvenanceEvent {
    ProvenanceEvent(
        id: "event-\(attribution.id)",
        eventType: type,
        timestamp: attribution.observedAt,
        worktreeID: worktree.id,
        sessionID: session.id,
        source: .observed,
        confidence: .high,
        payload: ProvenanceEventPayload(codingAgentFileChangeAttribution: attribution)
    )
}

private func event(
    _ assistant: ProvenanceCodingAgentAssistantMessageRecord,
    type: ProvenanceEventType,
    worktree: ProvenanceWorktreeRecord,
    session: ProvenanceSessionRecord
) -> ProvenanceEvent {
    ProvenanceEvent(
        id: "event-\(assistant.id)",
        eventType: type,
        timestamp: assistant.completedAt,
        worktreeID: worktree.id,
        sessionID: session.id,
        source: .observed,
        confidence: .high,
        payload: ProvenanceEventPayload(codingAgentAssistantMessage: assistant)
    )
}
