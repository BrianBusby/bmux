import Foundation
import ProvenanceEngineContracts
@testable import ProvenanceEngineSQLite

struct WorkModelFixture {
    let timestamp = Date(timeIntervalSince1970: 1_840_000_000)
    let session: ProvenanceSessionRecord
    let thread: ProvenanceCodingAgentThreadRecord

    init() {
        let timestamp = Date(timeIntervalSince1970: 1_840_000_000)
        self.session = ProvenanceSessionRecord(
            id: "session-work-model-fixture",
            agentKind: "codex",
            workspaceID: "workspace-work-model-fixture",
            surfaceID: "surface-work-model-fixture",
            worktreeID: "worktree-work-model-fixture",
            cwd: "/repos/work-model-fixture",
            status: "active",
            startedAt: timestamp,
            updatedAt: timestamp
        )
        self.thread = ProvenanceCodingAgentThreadRecord(
            id: "thread-work-model-fixture",
            sessionID: session.id,
            provider: "codex",
            providerThreadID: "provider-thread-work-model-fixture",
            worktreeID: "worktree-work-model-fixture",
            source: .observed,
            confidence: .high,
            firstObservedAt: timestamp.addingTimeInterval(1),
            updatedAt: timestamp.addingTimeInterval(1)
        )
    }

    func turn(
        id: String = "turn-work-model-fixture",
        providerTurnID: String = "provider-turn-work-model-fixture",
        status: String,
        startOffset: TimeInterval = 2,
        completedOffset: TimeInterval? = nil
    ) -> ProvenanceCodingAgentTurnRecord {
        ProvenanceCodingAgentTurnRecord(
            id: id,
            sessionID: session.id,
            threadID: thread.id,
            provider: "codex",
            providerTurnID: providerTurnID,
            status: status,
            model: "gpt-5-codex",
            effort: "medium",
            startedAt: timestamp.addingTimeInterval(startOffset),
            completedAt: completedOffset.map { timestamp.addingTimeInterval($0) },
            updatedAt: timestamp.addingTimeInterval(completedOffset ?? startOffset),
            source: .observed,
            confidence: .high
        )
    }

    func prompt(_ text: String, turnID: String, offset: TimeInterval = 3) -> ProvenanceCodingAgentPromptRecord {
        ProvenanceCodingAgentPromptRecord(
            id: "prompt-\(turnID)-\(Int(offset))",
            sessionID: session.id,
            threadID: thread.id,
            turnID: turnID,
            provider: "codex",
            text: text,
            submittedAt: timestamp.addingTimeInterval(offset),
            source: .observed,
            confidence: .high
        )
    }

    func plan(_ text: String, turnID: String, offset: TimeInterval = 5) -> ProvenanceCodingAgentPlanUpdateRecord {
        ProvenanceCodingAgentPlanUpdateRecord(
            id: "plan-\(turnID)-\(Int(offset))",
            sessionID: session.id,
            threadID: thread.id,
            turnID: turnID,
            provider: "codex",
            explanation: nil,
            steps: [
                ProvenanceCodingAgentPlanStepRecord(
                    id: "plan-step-\(turnID)-\(Int(offset))",
                    order: 0,
                    text: text,
                    status: "in_progress"
                ),
            ],
            observedAt: timestamp.addingTimeInterval(offset),
            source: .observed,
            confidence: .high
        )
    }

    func command(
        _ text: String,
        status: String = "succeeded",
        exitCode: Int? = 0,
        turnID: String,
        offset: TimeInterval
    ) -> ProvenanceCodingAgentCommandRecord {
        ProvenanceCodingAgentCommandRecord(
            id: "command-\(turnID)-\(Int(offset))",
            sessionID: session.id,
            threadID: thread.id,
            turnID: turnID,
            provider: "codex",
            operationID: "operation-\(turnID)-\(Int(offset))",
            command: text,
            cwd: "/repos/work-model-fixture",
            status: status,
            exitCode: exitCode,
            outputSummary: nil,
            startedAt: timestamp.addingTimeInterval(offset - 1),
            completedAt: timestamp.addingTimeInterval(offset),
            source: .observed,
            confidence: .high
        )
    }

    func reasoning(_ text: String, turnID: String, offset: TimeInterval) -> ProvenanceCodingAgentReasoningSummaryRecord {
        ProvenanceCodingAgentReasoningSummaryRecord(
            id: "reasoning-\(turnID)-\(Int(offset))",
            sessionID: session.id,
            threadID: thread.id,
            turnID: turnID,
            provider: "codex",
            itemID: "reasoning-item-\(turnID)-\(Int(offset))",
            text: text,
            completedAt: timestamp.addingTimeInterval(offset),
            source: .observed,
            confidence: .high
        )
    }

    func fileAttribution(
        _ summary: String,
        turnID: String,
        offset: TimeInterval
    ) -> ProvenanceCodingAgentFileChangeAttributionRecord {
        ProvenanceCodingAgentFileChangeAttributionRecord(
            id: "file-attribution-\(turnID)-\(Int(offset))",
            sessionID: session.id,
            threadID: thread.id,
            turnID: turnID,
            provider: "codex",
            operationID: "file-operation-\(turnID)-\(Int(offset))",
            changeSetID: nil,
            fileChangeIDs: [],
            paths: ["Sources/SessionWorkModel.swift"],
            summary: summary,
            observedAt: timestamp.addingTimeInterval(offset),
            source: .observed,
            confidence: .high
        )
    }

    func appendSessionThreadAndTurn(
        _ turn: ProvenanceCodingAgentTurnRecord,
        into repository: ProvenanceSQLiteRepository
    ) async throws {
        try await append(
            eventID: "event-session",
            eventType: .sessionObserved,
            timestamp: session.updatedAt,
            payload: ProvenanceEventPayload(session: session),
            into: repository
        )
        try await append(
            eventID: "event-thread",
            eventType: .codingAgentThreadObserved,
            timestamp: thread.updatedAt,
            payload: ProvenanceEventPayload(codingAgentThread: thread),
            into: repository
        )
        try await append(turn, into: repository)
    }

    func append(_ turn: ProvenanceCodingAgentTurnRecord, into repository: ProvenanceSQLiteRepository) async throws {
        try await append(
            eventID: "event-\(turn.id)-\(Int(turn.updatedAt.timeIntervalSince1970))",
            eventType: .codingAgentTurnObserved,
            timestamp: turn.updatedAt,
            payload: ProvenanceEventPayload(codingAgentTurn: turn),
            into: repository
        )
    }

    func append(_ prompt: ProvenanceCodingAgentPromptRecord, into repository: ProvenanceSQLiteRepository) async throws {
        try await append(
            eventID: "event-\(prompt.id)",
            eventType: .codingAgentPromptSubmitted,
            timestamp: prompt.submittedAt,
            payload: ProvenanceEventPayload(codingAgentPrompt: prompt),
            into: repository
        )
    }

    func append(_ plan: ProvenanceCodingAgentPlanUpdateRecord, into repository: ProvenanceSQLiteRepository) async throws {
        try await append(
            eventID: "event-\(plan.id)",
            eventType: .codingAgentPlanUpdated,
            timestamp: plan.observedAt,
            payload: ProvenanceEventPayload(codingAgentPlanUpdate: plan),
            into: repository
        )
    }

    func append(_ command: ProvenanceCodingAgentCommandRecord, into repository: ProvenanceSQLiteRepository) async throws {
        try await append(
            eventID: "event-\(command.id)",
            eventType: .codingAgentCommandCompleted,
            timestamp: command.completedAt,
            payload: ProvenanceEventPayload(codingAgentCommand: command),
            into: repository
        )
    }

    func append(
        _ reasoning: ProvenanceCodingAgentReasoningSummaryRecord,
        into repository: ProvenanceSQLiteRepository
    ) async throws {
        try await append(
            eventID: "event-\(reasoning.id)",
            eventType: .codingAgentReasoningSummaryCompleted,
            timestamp: reasoning.completedAt,
            payload: ProvenanceEventPayload(codingAgentReasoningSummary: reasoning),
            into: repository
        )
    }

    func append(
        _ attribution: ProvenanceCodingAgentFileChangeAttributionRecord,
        into repository: ProvenanceSQLiteRepository
    ) async throws {
        try await append(
            eventID: "event-\(attribution.id)",
            eventType: .codingAgentFileChangeAttributed,
            timestamp: attribution.observedAt,
            payload: ProvenanceEventPayload(codingAgentFileChangeAttribution: attribution),
            into: repository
        )
    }

    private func append(
        eventID: String,
        eventType: ProvenanceEventType,
        timestamp: Date,
        payload: ProvenanceEventPayload,
        into repository: ProvenanceSQLiteRepository
    ) async throws {
        try await repository.appendEvent(
            ProvenanceEvent(
                id: eventID,
                eventType: eventType,
                timestamp: timestamp,
                sessionID: session.id,
                source: .observed,
                evidenceOrigin: .codexSession,
                evidenceScope: ProvenanceEvidenceScope(level: .personal, id: "session-work-model-fixture"),
                confidence: .high,
                payload: payload
            )
        )
    }
}
