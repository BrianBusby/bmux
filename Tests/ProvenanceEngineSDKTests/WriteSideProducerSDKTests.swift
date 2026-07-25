import Foundation
import ProvenanceEngineContracts
import ProvenanceEngineSDK
import Testing

@Suite
struct WriteSideProducerSDKTests {
    @Test
    func genericProducerRecordsEngineeringActivityThroughPublicSDK() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let client = try ProvenanceEngineClientFactory().sqliteClient(databaseURL: url)
        let fixture = GenericProducerFixture()
        let producer = GenericAgentRuntime(client: client, fixture: fixture)

        try await producer.observeWorktree()
        try await producer.startSession()
        try await producer.createTask()
        try await producer.updateTask()
        let commandResponse = try await producer.executeCommand()
        try await producer.modifyFile()
        try await producer.recordCheckpoint()
        try await producer.completeValidation()
        let artifactResponse = try await producer.generateArtifact()
        try await producer.completeSession()

        #expect(commandResponse.eventType == "command_executed")
        #expect(artifactResponse.eventType == "artifact_generated")

        let currentContext = try await client.currentContext(
            ProvenanceCurrentContextRequest(repositoryPath: fixture.repository.path)
        )
        #expect(currentContext.found)
        #expect(currentContext.repository == fixture.repository)
        #expect(currentContext.worktree == fixture.completedWorktree)
        #expect(currentContext.activeSessions.isEmpty)
        #expect(currentContext.dirtyFiles.map(\.fileChange.path) == [fixture.fileChange.path])
        #expect(currentContext.dirtyFiles.first?.contribution == fixture.completedContribution)
        #expect(currentContext.recentCheckpoints.map(\.checkpoint) == [fixture.passedCheckpoint])
        #expect(currentContext.validationRuns.map(\.validationRun) == [fixture.passedValidationRun])

        let fileExplanation = try await client.fileExplanation(
            ProvenanceFileExplanationRequest(
                worktreeID: fixture.worktree.id,
                path: fixture.fileChange.path
            )
        )
        #expect(fileExplanation.found)
        #expect(fileExplanation.explanation?.fileChange == fixture.fileChange)
        #expect(fileExplanation.explanation?.changeSet == fixture.changeSet)
        #expect(fileExplanation.explanation?.checkpoint == fixture.passedCheckpoint)
        #expect(fileExplanation.explanation?.contribution == fixture.completedContribution)
        #expect(fileExplanation.explanation?.session == fixture.completedSession)
        #expect(fileExplanation.explanation?.workItem == fixture.completedWorkItem)

        let sessionTree = try await client.sessionTree(
            ProvenanceSessionTreeRequest(rootSessionID: fixture.session.id)
        )
        #expect(sessionTree.found)
        #expect(sessionTree.sessions == [fixture.completedSession])
        #expect(sessionTree.relationships.isEmpty)
        #expect(sessionTree.externalIdentities.isEmpty)
    }

    @Test
    func appendEventPreservesForwardCompatibleProducerEventTypes() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let client = try ProvenanceEngineClientFactory().sqliteClient(databaseURL: url)

        let response = try await client.appendEvent(
            ProvenanceAppendEventRequest(
                event: ProvenanceEvent(
                    id: "event-ci-validation-queued",
                    eventType: "ci_validation_queued",
                    timestamp: Date(timeIntervalSince1970: 1_800_000_000),
                    repositoryID: "repository-generic",
                    worktreeID: "worktree-generic",
                    source: .observed,
                    evidenceOrigin: "ci-validation-producer",
                    evidenceScope: ProvenanceEvidenceScope(level: .project, id: "owner/project"),
                    confidence: .high
                )
            )
        )

        #expect(response == ProvenanceAppendEventResponse(
            eventID: "event-ci-validation-queued",
            eventType: "ci_validation_queued"
        ))
        #expect(try await client.health().status == .available)
    }

    private static func temporaryDatabaseURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("provenance-engine-write-side-sdk-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("provenance.sqlite")
    }

    private static func removeTemporaryDatabaseDirectory(for url: URL) {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }
}

private struct GenericAgentRuntime {
    let client: any ProvenanceEngineClient
    let fixture: GenericProducerFixture

    func observeWorktree() async throws {
        try await append(
            eventID: "event-worktree-observed",
            eventType: .worktreeObserved,
            timestamp: fixture.startedAt,
            repositoryID: fixture.repository.id,
            worktreeID: fixture.worktree.id,
            source: .observed,
            payload: ProvenanceEventPayload(repository: fixture.repository, worktree: fixture.worktree)
        )
    }

    func startSession() async throws {
        try await append(
            eventID: "event-session-started",
            eventType: .sessionObserved,
            timestamp: fixture.startedAt.addingTimeInterval(1),
            repositoryID: fixture.repository.id,
            worktreeID: fixture.worktree.id,
            sessionID: fixture.session.id,
            source: .observed,
            payload: ProvenanceEventPayload(session: fixture.session)
        )
    }

    func createTask() async throws {
        try await append(
            eventID: "event-task-created",
            eventType: .workItemProposed,
            timestamp: fixture.startedAt.addingTimeInterval(2),
            repositoryID: fixture.repository.id,
            worktreeID: fixture.worktree.id,
            sessionID: fixture.session.id,
            contributionID: fixture.contribution.id,
            source: .declared,
            confidence: .medium,
            payload: ProvenanceEventPayload(workItem: fixture.workItem, contribution: fixture.contribution)
        )
    }

    func updateTask() async throws {
        try await append(
            eventID: "event-task-updated",
            eventType: .workItemConfirmed,
            timestamp: fixture.startedAt.addingTimeInterval(3),
            repositoryID: fixture.repository.id,
            worktreeID: fixture.worktree.id,
            sessionID: fixture.session.id,
            contributionID: fixture.contribution.id,
            source: .declared,
            payload: ProvenanceEventPayload(workItem: fixture.workItem, contribution: fixture.contribution)
        )
    }

    func executeCommand() async throws -> ProvenanceAppendEventResponse {
        try await appendReturningResponse(
            eventID: "event-command-executed",
            eventType: "command_executed",
            timestamp: fixture.runningValidationRun.startedAt ?? fixture.startedAt,
            repositoryID: fixture.repository.id,
            worktreeID: fixture.worktree.id,
            sessionID: fixture.session.id,
            contributionID: fixture.contribution.id,
            source: .observed,
            payload: ProvenanceEventPayload(validationRun: fixture.runningValidationRun)
        )
    }

    func modifyFile() async throws {
        try await append(
            eventID: "event-file-modified",
            eventType: "file_modified",
            timestamp: fixture.fileChange.updatedAt,
            repositoryID: fixture.repository.id,
            worktreeID: fixture.worktree.id,
            sessionID: fixture.session.id,
            contributionID: fixture.contribution.id,
            source: .observed,
            payload: ProvenanceEventPayload(changeSet: fixture.changeSet, fileChanges: [fixture.fileChange])
        )
    }

    func recordCheckpoint() async throws {
        try await append(
            eventID: "event-checkpoint-recorded",
            eventType: .progressCheckpoint,
            timestamp: fixture.checkpoint.createdAt,
            repositoryID: fixture.repository.id,
            worktreeID: fixture.worktree.id,
            sessionID: fixture.session.id,
            contributionID: fixture.contribution.id,
            source: .declared,
            payload: ProvenanceEventPayload(checkpoint: fixture.checkpoint)
        )
    }

    func completeValidation() async throws {
        try await append(
            eventID: "event-validation-completed",
            eventType: "validation_completed",
            timestamp: fixture.passedValidationRun.endedAt ?? fixture.startedAt,
            repositoryID: fixture.repository.id,
            worktreeID: fixture.worktree.id,
            sessionID: fixture.session.id,
            contributionID: fixture.contribution.id,
            source: .observed,
            payload: ProvenanceEventPayload(
                checkpoint: fixture.passedCheckpoint,
                validationRun: fixture.passedValidationRun
            )
        )
    }

    func generateArtifact() async throws -> ProvenanceAppendEventResponse {
        try await appendReturningResponse(
            eventID: "event-artifact-generated",
            eventType: "artifact_generated",
            timestamp: fixture.startedAt.addingTimeInterval(8),
            repositoryID: fixture.repository.id,
            worktreeID: fixture.worktree.id,
            sessionID: fixture.session.id,
            contributionID: fixture.contribution.id,
            source: .observed
        )
    }

    func completeSession() async throws {
        try await append(
            eventID: "event-session-completed",
            eventType: .contributionCompleted,
            timestamp: fixture.completedSession.updatedAt,
            repositoryID: fixture.repository.id,
            worktreeID: fixture.worktree.id,
            sessionID: fixture.session.id,
            contributionID: fixture.contribution.id,
            source: .declared,
            payload: ProvenanceEventPayload(
                worktree: fixture.completedWorktree,
                session: fixture.completedSession,
                workItem: fixture.completedWorkItem,
                contribution: fixture.completedContribution
            )
        )
    }

    private func append(
        eventID: String,
        eventType: ProvenanceEventType,
        timestamp: Date,
        repositoryID: String?,
        worktreeID: String?,
        sessionID: String? = nil,
        contributionID: String? = nil,
        source: ProvenanceSource,
        confidence: ProvenanceConfidence = .high,
        payload: ProvenanceEventPayload = ProvenanceEventPayload()
    ) async throws {
        _ = try await appendReturningResponse(
            eventID: eventID,
            eventType: eventType,
            timestamp: timestamp,
            repositoryID: repositoryID,
            worktreeID: worktreeID,
            sessionID: sessionID,
            contributionID: contributionID,
            source: source,
            confidence: confidence,
            payload: payload
        )
    }

    private func appendReturningResponse(
        eventID: String,
        eventType: ProvenanceEventType,
        timestamp: Date,
        repositoryID: String?,
        worktreeID: String?,
        sessionID: String? = nil,
        contributionID: String? = nil,
        source: ProvenanceSource,
        confidence: ProvenanceConfidence = .high,
        payload: ProvenanceEventPayload = ProvenanceEventPayload()
    ) async throws -> ProvenanceAppendEventResponse {
        try await client.appendEvent(
            ProvenanceAppendEventRequest(
                event: ProvenanceEvent(
                    id: eventID,
                    eventType: eventType,
                    timestamp: timestamp,
                    repositoryID: repositoryID,
                    worktreeID: worktreeID,
                    sessionID: sessionID,
                    contributionID: contributionID,
                    source: source,
                    evidenceOrigin: "generic-agent-runtime",
                    evidenceScope: ProvenanceEvidenceScope(level: .personal, id: "local-developer"),
                    confidence: confidence,
                    payload: payload
                )
            )
        )
    }
}

private struct GenericProducerFixture {
    let startedAt = Date(timeIntervalSince1970: 1_800_000_000)
    let repository: ProvenanceRepositoryRecord
    let worktree: ProvenanceWorktreeRecord
    let completedWorktree: ProvenanceWorktreeRecord
    let session: ProvenanceSessionRecord
    let completedSession: ProvenanceSessionRecord
    let workItem: ProvenanceWorkItemRecord
    let completedWorkItem: ProvenanceWorkItemRecord
    let contribution: ProvenanceContributionRecord
    let completedContribution: ProvenanceContributionRecord
    let checkpoint: ProvenanceCheckpointRecord
    let passedCheckpoint: ProvenanceCheckpointRecord
    let changeSet: ProvenanceChangeSetRecord
    let fileChange: ProvenanceFileChangeRecord
    let runningValidationRun: ProvenanceValidationRunRecord
    let passedValidationRun: ProvenanceValidationRunRecord

    init() {
        let startedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let repository = ProvenanceRepositoryRecord(
            id: "repository-generic",
            path: "/repos/generic-producer",
            commonDirectory: "/repos/generic-producer/.git",
            remoteSlug: "owner/generic-producer",
            createdAt: startedAt,
            updatedAt: startedAt
        )
        let worktree = ProvenanceWorktreeRecord(
            id: "worktree-generic",
            repositoryID: repository.id,
            path: repository.path,
            branch: "write-side-validation",
            baseCommit: "base-head",
            currentHEAD: "working-head",
            isDirty: true,
            status: "active",
            lastReconciledAt: startedAt,
            updatedAt: startedAt
        )
        let completedWorktree = ProvenanceWorktreeRecord(
            id: worktree.id,
            repositoryID: repository.id,
            path: repository.path,
            branch: worktree.branch,
            baseCommit: worktree.baseCommit,
            currentHEAD: "completed-head",
            isDirty: false,
            status: "active",
            lastReconciledAt: startedAt.addingTimeInterval(9),
            updatedAt: startedAt.addingTimeInterval(9)
        )
        let session = ProvenanceSessionRecord(
            id: "session-generic",
            agentKind: "generic-agent",
            workspaceID: "workspace-generic",
            surfaceID: "terminal",
            worktreeID: worktree.id,
            cwd: repository.path,
            status: "active",
            startedAt: startedAt.addingTimeInterval(1),
            updatedAt: startedAt.addingTimeInterval(1)
        )
        let completedSession = ProvenanceSessionRecord(
            id: session.id,
            agentKind: session.agentKind,
            workspaceID: session.workspaceID,
            surfaceID: session.surfaceID,
            worktreeID: session.worktreeID,
            cwd: session.cwd,
            status: "completed",
            startedAt: session.startedAt,
            updatedAt: startedAt.addingTimeInterval(10)
        )
        let workItem = ProvenanceWorkItemRecord(
            id: "work-item-generic",
            title: "Validate write-side capture",
            status: "active",
            createdAt: startedAt.addingTimeInterval(2),
            updatedAt: startedAt.addingTimeInterval(3)
        )
        let completedWorkItem = ProvenanceWorkItemRecord(
            id: workItem.id,
            title: workItem.title,
            status: "completed",
            createdAt: workItem.createdAt,
            updatedAt: startedAt.addingTimeInterval(10)
        )
        let contribution = ProvenanceContributionRecord(
            id: "contribution-generic",
            sessionID: session.id,
            worktreeID: worktree.id,
            workItemID: workItem.id,
            declaredIntent: "Record producer evidence through the public SDK",
            expectedScope: ["Sources/Producer.swift", "Tests/ProducerTests.swift"],
            status: "active",
            startedAt: startedAt.addingTimeInterval(2),
            assignmentConfidence: .medium,
            updatedAt: startedAt.addingTimeInterval(3)
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
            endedAt: startedAt.addingTimeInterval(10),
            assignmentConfidence: .high,
            updatedAt: startedAt.addingTimeInterval(10)
        )
        let checkpoint = ProvenanceCheckpointRecord(
            id: "checkpoint-generic",
            contributionID: contribution.id,
            sequence: 1,
            gitHEAD: "working-head",
            diffFingerprint: "diff-generic",
            summary: "Producer wrote validation evidence",
            status: "in_progress",
            validationState: "running",
            semanticConfidence: .medium,
            freshness: "fresh",
            createdAt: startedAt.addingTimeInterval(6)
        )
        let passedCheckpoint = ProvenanceCheckpointRecord(
            id: checkpoint.id,
            contributionID: checkpoint.contributionID,
            sequence: checkpoint.sequence,
            gitHEAD: checkpoint.gitHEAD,
            diffFingerprint: checkpoint.diffFingerprint,
            summary: checkpoint.summary,
            status: "completed",
            validationState: "passed",
            semanticConfidence: .medium,
            freshness: "fresh",
            createdAt: checkpoint.createdAt
        )
        let changeSet = ProvenanceChangeSetRecord(
            id: "change-set-generic",
            checkpointID: checkpoint.id,
            contributionID: contribution.id,
            worktreeID: worktree.id,
            summary: "Generic producer touched source",
            diffFingerprint: "diff-generic",
            createdAt: startedAt.addingTimeInterval(5)
        )
        let fileChange = ProvenanceFileChangeRecord(
            id: "file-change-generic",
            changeSetID: changeSet.id,
            repositoryID: repository.id,
            worktreeID: worktree.id,
            path: "Sources/Producer.swift",
            status: "modified",
            beforeHash: "before-generic",
            afterHash: "after-generic",
            attributionSource: .observed,
            attributionConfidence: .high,
            updatedAt: startedAt.addingTimeInterval(5)
        )
        let runningValidationRun = ProvenanceValidationRunRecord(
            id: "validation-generic",
            checkpointID: checkpoint.id,
            contributionID: contribution.id,
            command: "swift test --filter WriteSideProducerSDKTests",
            status: "running",
            summary: "Targeted validation running",
            startedAt: startedAt.addingTimeInterval(4)
        )
        let passedValidationRun = ProvenanceValidationRunRecord(
            id: runningValidationRun.id,
            checkpointID: checkpoint.id,
            contributionID: contribution.id,
            command: runningValidationRun.command,
            status: "passed",
            summary: "Targeted validation passed",
            startedAt: runningValidationRun.startedAt,
            endedAt: startedAt.addingTimeInterval(7)
        )

        self.repository = repository
        self.worktree = worktree
        self.completedWorktree = completedWorktree
        self.session = session
        self.completedSession = completedSession
        self.workItem = workItem
        self.completedWorkItem = completedWorkItem
        self.contribution = contribution
        self.completedContribution = completedContribution
        self.checkpoint = checkpoint
        self.passedCheckpoint = passedCheckpoint
        self.changeSet = changeSet
        self.fileChange = fileChange
        self.runningValidationRun = runningValidationRun
        self.passedValidationRun = passedValidationRun
    }
}
