import Foundation
import ProvenanceEngineContracts
import ProvenanceEngineSDK

@main
struct ProvenanceRetrievalDemoSeed {
    static func main() async throws {
        let options = try DemoOptions.parse(Array(CommandLine.arguments.dropFirst()))
        if options.reset, FileManager.default.fileExists(atPath: options.databaseURL.path) {
            try FileManager.default.removeItem(at: options.databaseURL)
        }
        try FileManager.default.createDirectory(
            at: options.databaseURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let summary = try await DemoSeeder(databaseURL: options.databaseURL).seed()
        if options.json {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            encoder.keyEncodingStrategy = .convertToSnakeCase
            encoder.dateEncodingStrategy = .secondsSince1970
            let data = try encoder.encode(summary)
            print(String(data: data, encoding: .utf8) ?? "{}")
        } else {
            print("Seeded provenance retrieval demo")
            print("database: \(summary.database)")
            print("target_session_id: \(summary.targetSessionID)")
            print("related_session_id: \(summary.relatedSessionID)")
            print("shared_artifact_path: \(summary.sharedArtifactPath)")
        }
    }
}

private struct DemoOptions {
    let databaseURL: URL
    let reset: Bool
    let json: Bool

    static func parse(_ arguments: [String]) throws -> DemoOptions {
        var databasePath: String?
        var reset = false
        var json = false
        var index = 0
        while index < arguments.count {
            switch arguments[index] {
            case "--database":
                guard index + 1 < arguments.count else { throw DemoError.usage }
                databasePath = arguments[index + 1]
                index += 1
            case let argument where argument.hasPrefix("--database="):
                databasePath = String(argument.dropFirst("--database=".count))
            case "--reset":
                reset = true
            case "--json":
                json = true
            case "--help", "-h", "help":
                throw DemoError.usage
            default:
                throw DemoError.usage
            }
            index += 1
        }
        guard let databasePath,
              !databasePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DemoError.usage
        }
        return DemoOptions(
            databaseURL: URL(fileURLWithPath: NSString(string: databasePath).expandingTildeInPath),
            reset: reset,
            json: json
        )
    }
}

private enum DemoError: LocalizedError {
    case usage

    var errorDescription: String? {
        "Usage: swift run --package-path Packages/macOS/ProvenanceEngine ProvenanceRetrievalDemoSeed --database <path> [--reset] [--json]"
    }
}

private struct DemoSummary: Encodable {
    let database: String
    let targetSessionID: String
    let relatedSessionID: String
    let sharedArtifactPath: String
    let seededAt: Date
}

private struct DemoSeeder {
    let databaseURL: URL

    func seed() async throws -> DemoSummary {
        let client = try ProvenanceEngineClientFactory().sqliteClient(databaseURL: databaseURL)
        let timestamp = Date(timeIntervalSince1970: 1_800_030_000)
        let repository = ProvenanceRepositoryRecord(
            id: "repository-retrieval-demo",
            path: "/repos/retrieval-demo",
            remoteSlug: "example/retrieval-demo",
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let worktreeA = worktree(
            id: "worktree-retrieval-demo-a",
            repositoryID: repository.id,
            path: "/repos/retrieval-demo-a",
            branch: "feature/session-a",
            head: "head-session-a",
            timestamp: timestamp
        )
        let worktreeB = worktree(
            id: "worktree-retrieval-demo-b",
            repositoryID: repository.id,
            path: "/repos/retrieval-demo-b",
            branch: "feature/session-b",
            head: "head-session-b",
            timestamp: timestamp.addingTimeInterval(1)
        )
        let sessionA = session(
            id: "session-retrieval-demo-a",
            worktree: worktreeA,
            timestamp: timestamp.addingTimeInterval(2)
        )
        let sessionB = session(
            id: "session-retrieval-demo-b",
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

        return DemoSummary(
            database: databaseURL.path,
            targetSessionID: sessionB.id,
            relatedSessionID: sessionA.id,
            sharedArtifactPath: "Sources/Shared.swift",
            seededAt: Date()
        )
    }

    private func worktree(
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

    private func session(
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

    private func appendWorktree(
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

    private func appendSession(
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

    private func appendCodingAgentActivity(
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
            steps: [ProvenanceCodingAgentPlanStepRecord(
                id: "plan-step-\(session.id)",
                order: 0,
                text: "Validate agent-accessible retrieval",
                status: "completed"
            )],
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
            status: "failed",
            exitCode: 1,
            outputSummary: "database unavailable in fixture setup",
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
            event(fileAttribution, type: .codingAgentFileChangeAttributed, worktree: worktree, session: session),
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
            events.append(event(assistant, type: .codingAgentAssistantMessageCompleted, worktree: worktree, session: session))
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
