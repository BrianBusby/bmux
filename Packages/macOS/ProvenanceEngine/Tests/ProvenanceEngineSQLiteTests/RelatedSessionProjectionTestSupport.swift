import Foundation
import ProvenanceEngineContracts
@testable import ProvenanceEngineSQLite

enum RelatedSessionProjectionTestSupport {
    static func seedSession(
        id: String,
        status: String,
        worktree: ProvenanceWorktreeRecord,
        repository: ProvenanceRepositoryRecord,
        sessionOffset: TimeInterval = 10,
        promptText: String = "Work on session",
        paths: [String] = [],
        includeReasoning: Bool = false,
        fixture: RelatedSessionFixture,
        into store: ProvenanceSQLiteRepository
    ) async throws -> SeededRelatedSession {
        try await fixture.appendRepositoryAndWorktree(
            repository: repository,
            worktree: worktree,
            eventID: "event-\(worktree.id)-\(id)",
            into: store
        )
        let session = fixture.session(
            id: id,
            worktreeID: worktree.id,
            status: status,
            offset: sessionOffset
        )
        let thread = fixture.thread(
            id: "thread-\(id)",
            sessionID: session.id,
            worktreeID: worktree.id,
            providerThreadID: "provider-thread-\(id)",
            offset: sessionOffset + 1
        )
        let turn = fixture.turn(
            id: "turn-\(id)",
            sessionID: session.id,
            threadID: thread.id,
            providerTurnID: "provider-turn-\(id)",
            status: status == "active" ? "started" : "completed",
            startOffset: sessionOffset + 2,
            completedOffset: status == "active" ? nil : sessionOffset + 6
        )
        try await fixture.appendSession(session, into: store)
        try await fixture.appendThread(thread, into: store)
        try await fixture.appendTurn(turn, into: store)
        try await fixture.appendPrompt(
            fixture.prompt(
                promptText,
                sessionID: session.id,
                threadID: thread.id,
                turnID: turn.id,
                offset: sessionOffset + 3
            ),
            into: store
        )
        try await fixture.appendPlan(
            fixture.plan(
                "Finish session work",
                sessionID: session.id,
                threadID: thread.id,
                turnID: turn.id,
                offset: sessionOffset + 4
            ),
            into: store
        )
        if includeReasoning {
            let reasoning = ProvenanceCodingAgentReasoningSummaryRecord(
                id: "reasoning-\(id)",
                sessionID: session.id,
                threadID: thread.id,
                turnID: turn.id,
                provider: "codex",
                itemID: "reasoning-item-\(id)",
                text: "Reading existing PE evidence.",
                completedAt: fixture.time(sessionOffset + 5),
                source: .observed,
                confidence: .high
            )
            try await fixture.append(
                eventID: "event-\(reasoning.id)",
                eventType: .codingAgentReasoningSummaryCompleted,
                timestamp: reasoning.completedAt,
                repositoryID: nil,
                worktreeID: nil,
                sessionID: session.id,
                payload: ProvenanceEventPayload(codingAgentReasoningSummary: reasoning),
                into: store
            )
        }
        if !paths.isEmpty {
            try await fixture.appendFileAttribution(
                fixture.fileAttribution(
                    paths: paths,
                    sessionID: session.id,
                    threadID: thread.id,
                    turnID: turn.id,
                    offset: sessionOffset + 7
                ),
                into: store
            )
        }
        try await fixture.appendCommand(
            fixture.command(
                "swift test",
                sessionID: session.id,
                threadID: thread.id,
                turnID: turn.id,
                status: "succeeded",
                exitCode: 0,
                offset: sessionOffset + 8
            ),
            into: store
        )
        return SeededRelatedSession(session: session, thread: thread, turn: turn)
    }

    static func temporaryDatabaseURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("provenance-engine-related-session-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("provenance.sqlite")
    }

    static func removeTemporaryDatabaseDirectory(for url: URL) {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }
}

struct SeededRelatedSession {
    let session: ProvenanceSessionRecord
    let thread: ProvenanceCodingAgentThreadRecord
    let turn: ProvenanceCodingAgentTurnRecord
}
