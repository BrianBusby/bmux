import Foundation
import ProvenanceEngineContracts
@testable import ProvenanceEngineSQLite

struct RelatedSessionFixture {
    let timestamp = Date(timeIntervalSince1970: 1_850_000_000)

    func time(_ offset: TimeInterval) -> Date {
        timestamp.addingTimeInterval(offset)
    }

    func repository(
        id: String = "repository-related",
        path: String = "/repos/related",
        remoteSlug: String? = "owner/related",
        offset: TimeInterval = 0
    ) -> ProvenanceRepositoryRecord {
        ProvenanceRepositoryRecord(
            id: id,
            path: path,
            remoteSlug: remoteSlug,
            createdAt: time(offset),
            updatedAt: time(offset)
        )
    }

    func worktree(
        id: String,
        repository: ProvenanceRepositoryRecord,
        path: String,
        branch: String?,
        head: String?,
        offset: TimeInterval
    ) -> ProvenanceWorktreeRecord {
        ProvenanceWorktreeRecord(
            id: id,
            repositoryID: repository.id,
            path: path,
            branch: branch,
            currentHEAD: head,
            isDirty: false,
            status: "active",
            updatedAt: time(offset)
        )
    }

    func session(
        id: String,
        worktreeID: String?,
        status: String = "active",
        offset: TimeInterval
    ) -> ProvenanceSessionRecord {
        ProvenanceSessionRecord(
            id: id,
            agentKind: "codex",
            workspaceID: "workspace-\(id)",
            surfaceID: "surface-\(id)",
            worktreeID: worktreeID,
            cwd: worktreeID.map { "/cwd/\($0)" },
            status: status,
            startedAt: time(offset),
            updatedAt: time(offset)
        )
    }

    func relationship(
        sessionID: String,
        parentSessionID: String,
        rootSessionID: String,
        depth: Int,
        offset: TimeInterval
    ) -> ProvenanceSessionRelationshipRecord {
        ProvenanceSessionRelationshipRecord(
            sessionID: sessionID,
            parentSessionID: parentSessionID,
            rootSessionID: rootSessionID,
            depth: depth,
            source: .observed,
            confidence: .high,
            createdAt: time(offset),
            updatedAt: time(offset)
        )
    }

    func thread(
        id: String,
        sessionID: String,
        worktreeID: String?,
        providerThreadID: String,
        offset: TimeInterval
    ) -> ProvenanceCodingAgentThreadRecord {
        ProvenanceCodingAgentThreadRecord(
            id: id,
            sessionID: sessionID,
            provider: "codex",
            providerThreadID: providerThreadID,
            worktreeID: worktreeID,
            source: .observed,
            confidence: .high,
            firstObservedAt: time(offset),
            updatedAt: time(offset)
        )
    }

    func turn(
        id: String,
        sessionID: String,
        threadID: String,
        providerTurnID: String,
        status: String = "completed",
        startOffset: TimeInterval,
        completedOffset: TimeInterval? = nil
    ) -> ProvenanceCodingAgentTurnRecord {
        ProvenanceCodingAgentTurnRecord(
            id: id,
            sessionID: sessionID,
            threadID: threadID,
            provider: "codex",
            providerTurnID: providerTurnID,
            status: status,
            model: "gpt-5-codex",
            effort: "medium",
            startedAt: time(startOffset),
            completedAt: completedOffset.map(time),
            updatedAt: time(completedOffset ?? startOffset),
            source: .observed,
            confidence: .high
        )
    }

    func prompt(
        _ text: String,
        sessionID: String,
        threadID: String,
        turnID: String,
        offset: TimeInterval
    ) -> ProvenanceCodingAgentPromptRecord {
        ProvenanceCodingAgentPromptRecord(
            id: "prompt-\(turnID)",
            sessionID: sessionID,
            threadID: threadID,
            turnID: turnID,
            provider: "codex",
            text: text,
            submittedAt: time(offset),
            source: .observed,
            confidence: .high
        )
    }

    func plan(
        _ text: String,
        sessionID: String,
        threadID: String,
        turnID: String,
        offset: TimeInterval
    ) -> ProvenanceCodingAgentPlanUpdateRecord {
        ProvenanceCodingAgentPlanUpdateRecord(
            id: "plan-\(turnID)",
            sessionID: sessionID,
            threadID: threadID,
            turnID: turnID,
            provider: "codex",
            explanation: nil,
            steps: [
                ProvenanceCodingAgentPlanStepRecord(
                    id: "plan-step-\(turnID)",
                    order: 0,
                    text: text,
                    status: "completed"
                ),
            ],
            observedAt: time(offset),
            source: .observed,
            confidence: .high
        )
    }

    func command(
        _ text: String,
        sessionID: String,
        threadID: String,
        turnID: String,
        status: String = "succeeded",
        exitCode: Int? = 0,
        offset: TimeInterval
    ) -> ProvenanceCodingAgentCommandRecord {
        ProvenanceCodingAgentCommandRecord(
            id: "command-\(turnID)",
            sessionID: sessionID,
            threadID: threadID,
            turnID: turnID,
            provider: "codex",
            operationID: "operation-\(turnID)",
            command: text,
            cwd: "/repos/related",
            status: status,
            exitCode: exitCode,
            outputSummary: nil,
            startedAt: time(offset - 1),
            completedAt: time(offset),
            source: .observed,
            confidence: .high
        )
    }

    func fileAttribution(
        paths: [String],
        sessionID: String,
        threadID: String,
        turnID: String,
        offset: TimeInterval,
        idSuffix: String? = nil
    ) -> ProvenanceCodingAgentFileChangeAttributionRecord {
        let suffix = idSuffix ?? turnID
        return ProvenanceCodingAgentFileChangeAttributionRecord(
            id: "file-attribution-\(suffix)",
            sessionID: sessionID,
            threadID: threadID,
            turnID: turnID,
            provider: "codex",
            operationID: "file-operation-\(suffix)",
            changeSetID: nil,
            fileChangeIDs: [],
            paths: paths,
            summary: "Changed \(paths.joined(separator: ", "))",
            observedAt: time(offset),
            source: .observed,
            confidence: .high
        )
    }

    func appendRepositoryAndWorktree(
        repository: ProvenanceRepositoryRecord,
        worktree: ProvenanceWorktreeRecord,
        eventID: String? = nil,
        into store: ProvenanceSQLiteRepository
    ) async throws {
        try await append(
            eventID: eventID ?? "event-\(worktree.id)",
            eventType: .worktreeObserved,
            timestamp: worktree.updatedAt,
            repositoryID: repository.id,
            worktreeID: worktree.id,
            sessionID: nil,
            payload: ProvenanceEventPayload(repository: repository, worktree: worktree),
            into: store
        )
    }

    func appendSession(
        _ session: ProvenanceSessionRecord,
        into store: ProvenanceSQLiteRepository
    ) async throws {
        try await append(
            eventID: "event-\(session.id)",
            eventType: .sessionObserved,
            timestamp: session.updatedAt,
            repositoryID: nil,
            worktreeID: session.worktreeID,
            sessionID: session.id,
            payload: ProvenanceEventPayload(session: session),
            into: store
        )
    }

    func appendRelationship(
        _ relationship: ProvenanceSessionRelationshipRecord,
        into store: ProvenanceSQLiteRepository
    ) async throws {
        try await append(
            eventID: "event-relationship-\(relationship.sessionID)",
            eventType: .sessionStarted,
            timestamp: relationship.updatedAt,
            repositoryID: nil,
            worktreeID: nil,
            sessionID: relationship.sessionID,
            payload: ProvenanceEventPayload(sessionRelationship: relationship),
            into: store
        )
    }

    func appendThread(
        _ thread: ProvenanceCodingAgentThreadRecord,
        into store: ProvenanceSQLiteRepository
    ) async throws {
        try await append(
            eventID: "event-\(thread.id)",
            eventType: .codingAgentThreadObserved,
            timestamp: thread.updatedAt,
            repositoryID: nil,
            worktreeID: thread.worktreeID,
            sessionID: thread.sessionID,
            payload: ProvenanceEventPayload(codingAgentThread: thread),
            into: store
        )
    }

    func appendTurn(
        _ turn: ProvenanceCodingAgentTurnRecord,
        into store: ProvenanceSQLiteRepository
    ) async throws {
        try await append(
            eventID: "event-\(turn.id)",
            eventType: .codingAgentTurnObserved,
            timestamp: turn.updatedAt,
            repositoryID: nil,
            worktreeID: nil,
            sessionID: turn.sessionID,
            payload: ProvenanceEventPayload(codingAgentTurn: turn),
            into: store
        )
    }

    func appendPrompt(
        _ prompt: ProvenanceCodingAgentPromptRecord,
        into store: ProvenanceSQLiteRepository
    ) async throws {
        try await append(
            eventID: "event-\(prompt.id)",
            eventType: .codingAgentPromptSubmitted,
            timestamp: prompt.submittedAt,
            repositoryID: nil,
            worktreeID: nil,
            sessionID: prompt.sessionID,
            payload: ProvenanceEventPayload(codingAgentPrompt: prompt),
            into: store
        )
    }

    func appendPlan(
        _ plan: ProvenanceCodingAgentPlanUpdateRecord,
        into store: ProvenanceSQLiteRepository
    ) async throws {
        try await append(
            eventID: "event-\(plan.id)",
            eventType: .codingAgentPlanUpdated,
            timestamp: plan.observedAt,
            repositoryID: nil,
            worktreeID: nil,
            sessionID: plan.sessionID,
            payload: ProvenanceEventPayload(codingAgentPlanUpdate: plan),
            into: store
        )
    }

    func appendCommand(
        _ command: ProvenanceCodingAgentCommandRecord,
        into store: ProvenanceSQLiteRepository
    ) async throws {
        try await append(
            eventID: "event-\(command.id)",
            eventType: .codingAgentCommandCompleted,
            timestamp: command.completedAt,
            repositoryID: nil,
            worktreeID: nil,
            sessionID: command.sessionID,
            payload: ProvenanceEventPayload(codingAgentCommand: command),
            into: store
        )
    }

    func appendFileAttribution(
        _ attribution: ProvenanceCodingAgentFileChangeAttributionRecord,
        eventID: String? = nil,
        into store: ProvenanceSQLiteRepository
    ) async throws {
        try await append(
            eventID: eventID ?? "event-\(attribution.id)",
            eventType: .codingAgentFileChangeAttributed,
            timestamp: attribution.observedAt,
            repositoryID: nil,
            worktreeID: nil,
            sessionID: attribution.sessionID,
            payload: ProvenanceEventPayload(codingAgentFileChangeAttribution: attribution),
            into: store
        )
    }

    func append(
        eventID: String,
        eventType: ProvenanceEventType,
        timestamp: Date,
        repositoryID: String?,
        worktreeID: String?,
        sessionID: String?,
        payload: ProvenanceEventPayload,
        into store: ProvenanceSQLiteRepository
    ) async throws {
        try await store.appendEvent(
            ProvenanceEvent(
                id: eventID,
                eventType: eventType,
                timestamp: timestamp,
                repositoryID: repositoryID,
                worktreeID: worktreeID,
                sessionID: sessionID,
                source: .observed,
                evidenceOrigin: .codexSession,
                evidenceScope: ProvenanceEvidenceScope(level: .personal, id: "related-session-fixture"),
                confidence: .high,
                payload: payload
            )
        )
    }
}
