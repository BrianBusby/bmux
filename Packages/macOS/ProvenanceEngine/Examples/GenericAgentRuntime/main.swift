import Foundation
import ProvenanceEngineContracts
import ProvenanceEngineSDK

@main
struct GenericAgentRuntimeExample {
    static func main() async throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("generic-agent-runtime-provenance.sqlite")
        let client = try ProvenanceEngineClientFactory().sqliteClient(databaseURL: databaseURL)
        let producer = GenericAgentRuntime(client: client)

        try await producer.recordSessionStarted()
        try await producer.recordTaskCreated()
        try await producer.recordCommandExecuted()
        try await producer.recordFileModified()
        try await producer.recordCheckpointRecorded()
        try await producer.recordValidationCompleted()
        try await producer.recordArtifactGenerated()
        try await producer.recordSessionCompleted()

        let context = try await client.currentContext(
            ProvenanceCurrentContextRequest(repositoryPath: GenericAgentRuntime.repositoryPath)
        )
        print("Recorded provenance for \(context.repository?.remoteSlug ?? GenericAgentRuntime.repositoryPath)")
    }
}

private struct GenericAgentRuntime {
    static let repositoryPath = "/repos/example-producer"

    let client: any ProvenanceEngineClient
    let timestamp = Date(timeIntervalSince1970: 1_800_000_000)

    private var repository: ProvenanceRepositoryRecord {
        ProvenanceRepositoryRecord(
            id: "repository-example",
            path: Self.repositoryPath,
            remoteSlug: "example/producer",
            createdAt: timestamp,
            updatedAt: timestamp
        )
    }

    private var worktree: ProvenanceWorktreeRecord {
        ProvenanceWorktreeRecord(
            id: "worktree-example",
            repositoryID: repository.id,
            path: repository.path,
            branch: "write-side-validation",
            currentHEAD: "example-head",
            isDirty: true,
            status: "active",
            lastReconciledAt: timestamp,
            updatedAt: timestamp
        )
    }

    private var session: ProvenanceSessionRecord {
        ProvenanceSessionRecord(
            id: "session-example",
            agentKind: "generic-agent-runtime",
            worktreeID: worktree.id,
            cwd: repository.path,
            status: "active",
            startedAt: timestamp.addingTimeInterval(1),
            updatedAt: timestamp.addingTimeInterval(1)
        )
    }

    private var workItem: ProvenanceWorkItemRecord {
        ProvenanceWorkItemRecord(
            id: "work-item-example",
            title: "Demonstrate generic write-side capture",
            status: "active",
            createdAt: timestamp.addingTimeInterval(2),
            updatedAt: timestamp.addingTimeInterval(2)
        )
    }

    private var contribution: ProvenanceContributionRecord {
        ProvenanceContributionRecord(
            id: "contribution-example",
            sessionID: session.id,
            worktreeID: worktree.id,
            workItemID: workItem.id,
            declaredIntent: "Record observable engineering activity",
            expectedScope: ["Sources/Example.swift"],
            status: "active",
            startedAt: timestamp.addingTimeInterval(2),
            assignmentConfidence: .medium,
            updatedAt: timestamp.addingTimeInterval(2)
        )
    }

    private var checkpoint: ProvenanceCheckpointRecord {
        ProvenanceCheckpointRecord(
            id: "checkpoint-example",
            contributionID: contribution.id,
            sequence: 1,
            gitHEAD: "example-head",
            diffFingerprint: "example-diff",
            summary: "Example producer checkpoint",
            status: "completed",
            validationState: "passed",
            semanticConfidence: .medium,
            freshness: "fresh",
            createdAt: timestamp.addingTimeInterval(5)
        )
    }

    func recordSessionStarted() async throws {
        try await append(
            id: "event-session-started",
            type: .sessionObserved,
            time: timestamp.addingTimeInterval(1),
            source: .observed,
            payload: ProvenanceEventPayload(repository: repository, worktree: worktree, session: session)
        )
    }

    func recordTaskCreated() async throws {
        try await append(
            id: "event-task-created",
            type: .workItemProposed,
            time: timestamp.addingTimeInterval(2),
            source: .declared,
            confidence: .medium,
            payload: ProvenanceEventPayload(workItem: workItem, contribution: contribution)
        )
    }

    func recordCommandExecuted() async throws {
        let validationRun = ProvenanceValidationRunRecord(
            id: "validation-example",
            checkpointID: checkpoint.id,
            contributionID: contribution.id,
            command: "swift test",
            status: "running",
            summary: "Validation started",
            startedAt: timestamp.addingTimeInterval(3)
        )
        try await append(
            id: "event-command-executed",
            type: "command_executed",
            time: timestamp.addingTimeInterval(3),
            source: .observed,
            payload: ProvenanceEventPayload(validationRun: validationRun)
        )
    }

    func recordFileModified() async throws {
        let changeSet = ProvenanceChangeSetRecord(
            id: "change-set-example",
            checkpointID: checkpoint.id,
            contributionID: contribution.id,
            worktreeID: worktree.id,
            summary: "Example source edit",
            diffFingerprint: "example-diff",
            createdAt: timestamp.addingTimeInterval(4)
        )
        let fileChange = ProvenanceFileChangeRecord(
            id: "file-change-example",
            changeSetID: changeSet.id,
            repositoryID: repository.id,
            worktreeID: worktree.id,
            path: "Sources/Example.swift",
            status: "modified",
            attributionSource: .observed,
            attributionConfidence: .high,
            updatedAt: timestamp.addingTimeInterval(4)
        )
        try await append(
            id: "event-file-modified",
            type: "file_modified",
            time: timestamp.addingTimeInterval(4),
            source: .observed,
            payload: ProvenanceEventPayload(changeSet: changeSet, fileChanges: [fileChange])
        )
    }

    func recordCheckpointRecorded() async throws {
        try await append(
            id: "event-checkpoint-recorded",
            type: .progressCheckpoint,
            time: checkpoint.createdAt,
            source: .declared,
            payload: ProvenanceEventPayload(checkpoint: checkpoint)
        )
    }

    func recordValidationCompleted() async throws {
        let validationRun = ProvenanceValidationRunRecord(
            id: "validation-example",
            checkpointID: checkpoint.id,
            contributionID: contribution.id,
            command: "swift test",
            status: "passed",
            summary: "Validation passed",
            startedAt: timestamp.addingTimeInterval(3),
            endedAt: timestamp.addingTimeInterval(6)
        )
        try await append(
            id: "event-validation-completed",
            type: "validation_completed",
            time: timestamp.addingTimeInterval(6),
            source: .observed,
            payload: ProvenanceEventPayload(validationRun: validationRun)
        )
    }

    func recordArtifactGenerated() async throws {
        try await append(
            id: "event-artifact-generated",
            type: "artifact_generated",
            time: timestamp.addingTimeInterval(7),
            source: .observed
        )
    }

    func recordSessionCompleted() async throws {
        let completedSession = ProvenanceSessionRecord(
            id: session.id,
            agentKind: session.agentKind,
            worktreeID: session.worktreeID,
            cwd: session.cwd,
            status: "completed",
            startedAt: session.startedAt,
            updatedAt: timestamp.addingTimeInterval(8)
        )
        let completedContribution = ProvenanceContributionRecord(
            id: contribution.id,
            sessionID: contribution.sessionID,
            worktreeID: contribution.worktreeID,
            workItemID: contribution.workItemID,
            declaredIntent: contribution.declaredIntent,
            expectedScope: contribution.expectedScope,
            status: "completed",
            startedAt: contribution.startedAt,
            endedAt: timestamp.addingTimeInterval(8),
            assignmentConfidence: .high,
            updatedAt: timestamp.addingTimeInterval(8)
        )
        try await append(
            id: "event-session-completed",
            type: .contributionCompleted,
            time: timestamp.addingTimeInterval(8),
            source: .declared,
            payload: ProvenanceEventPayload(session: completedSession, contribution: completedContribution)
        )
    }

    private func append(
        id: String,
        type: ProvenanceEventType,
        time: Date,
        source: ProvenanceSource,
        confidence: ProvenanceConfidence = .high,
        payload: ProvenanceEventPayload = ProvenanceEventPayload()
    ) async throws {
        _ = try await client.appendEvent(
            ProvenanceAppendEventRequest(
                event: ProvenanceEvent(
                    id: id,
                    eventType: type,
                    timestamp: time,
                    repositoryID: repository.id,
                    worktreeID: worktree.id,
                    sessionID: session.id,
                    contributionID: contribution.id,
                    source: source,
                    evidenceOrigin: "generic-agent-runtime",
                    evidenceScope: ProvenanceEvidenceScope(level: .personal, id: "local-example"),
                    confidence: confidence,
                    payload: payload
                )
            )
        )
    }
}
