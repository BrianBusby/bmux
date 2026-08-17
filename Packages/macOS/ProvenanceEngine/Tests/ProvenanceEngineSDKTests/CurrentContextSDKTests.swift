import Foundation
import ProvenanceEngineContracts
import ProvenanceEngineSDK
import Testing

@Suite
struct CurrentContextSDKTests {
    @Test
    func sqliteClientReadsCurrentContextThroughPublicContract() async throws {
        let context = try await Self.seedCurrentContext()
        defer { Self.removeTemporaryDatabaseDirectory(for: context.databaseURL) }

        let response = try await context.client.currentContext(
            ProvenanceCurrentContextRequest(repositoryPath: context.repository.path)
        )

        #expect(response.found)
        #expect(response.reason == nil)
        #expect(response.repositoryPath == context.repository.path)
        #expect(response.worktree == context.worktree)
        #expect(response.repository == context.repository)
        #expect(response.activeSessions.map(\.session.id) == [
            context.newerSession.id,
            context.olderSession.id,
        ])
        #expect(response.activeSessions.first?.contribution == context.newerContribution)
        #expect(response.activeSessions.first?.workItem == context.newerWorkItem)
        #expect(response.dirtyFiles.map(\.fileChange.id) == [
            context.unattributedFile.id,
            context.conflictFileB.id,
            context.attributedFile.id,
        ])
        #expect(response.unattributedChanges.map(\.fileChange.id) == [context.unattributedFile.id])
        #expect(response.recentCheckpoints.map(\.checkpoint.id) == [
            context.newerCheckpoint.id,
            context.olderCheckpoint.id,
        ])
        #expect(response.validationRuns.map(\.validationRun.id) == [
            context.endedValidationRun.id,
            context.runningValidationRun.id,
        ])
        #expect(response.conflicts == [
            ProvenanceCurrentContextConflict(
                path: context.conflictPath,
                activeContributionCount: 2,
                contributionIDs: "\(context.olderContribution.id),\(context.newerContribution.id)",
                updatedAt: context.conflictFileB.updatedAt
            ),
        ])
    }

    @Test
    func sqliteClientReturnsNoWorktreeForUnknownRepositoryPath() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let client = try ProvenanceEngineClientFactory().sqliteClient(databaseURL: url)

        let response = try await client.currentContext(
            ProvenanceCurrentContextRequest(repositoryPath: "/repos/missing")
        )

        #expect(response == ProvenanceCurrentContextResponse(
            found: false,
            reason: "no_worktree",
            repositoryPath: "/repos/missing",
            worktree: nil,
            repository: nil,
            activeSessions: [],
            dirtyFiles: [],
            unattributedChanges: [],
            recentCheckpoints: [],
            validationRuns: [],
            conflicts: []
        ))
    }

    @Test
    func sqliteClientReturnsFoundEmptyContextForKnownWorktreeWithoutActivity() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let client = try ProvenanceEngineClientFactory().sqliteClient(databaseURL: url)
        let timestamp = Date(timeIntervalSince1970: 1_800_000_000)
        let repository = ProvenanceRepositoryRecord(
            id: "repository-empty",
            path: "/repos/empty",
            remoteSlug: "owner/empty",
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let worktree = ProvenanceWorktreeRecord(
            id: "worktree-empty",
            repositoryID: repository.id,
            path: repository.path,
            branch: "main",
            currentHEAD: "empty-head",
            isDirty: false,
            status: "active",
            updatedAt: timestamp
        )
        try await Self.append(
            client: client,
            eventID: "event-empty-worktree",
            timestamp: timestamp,
            repositoryID: repository.id,
            worktreeID: worktree.id,
            payload: ProvenanceEventPayload(repository: repository, worktree: worktree)
        )

        let response = try await client.currentContext(
            ProvenanceCurrentContextRequest(repositoryPath: repository.path)
        )

        #expect(response == ProvenanceCurrentContextResponse(
            found: true,
            repositoryPath: repository.path,
            worktree: worktree,
            repository: repository,
            activeSessions: [],
            dirtyFiles: [],
            unattributedChanges: [],
            recentCheckpoints: [],
            validationRuns: [],
            conflicts: []
        ))
    }

    @Test
    func sqliteClientAppliesIndependentSectionLimits() async throws {
        let context = try await Self.seedCurrentContext()
        defer { Self.removeTemporaryDatabaseDirectory(for: context.databaseURL) }

        let response = try await context.client.currentContext(
            ProvenanceCurrentContextRequest(
                repositoryPath: context.repository.path,
                activeSessionLimit: 1,
                dirtyFileLimit: 2,
                unattributedChangeLimit: 0,
                recentCheckpointLimit: 1,
                validationRunLimit: 1,
                conflictLimit: 0
            )
        )

        #expect(response.activeSessions.map(\.session.id) == [context.newerSession.id])
        #expect(response.dirtyFiles.map(\.fileChange.id) == [
            context.unattributedFile.id,
            context.conflictFileB.id,
        ])
        #expect(response.unattributedChanges.isEmpty)
        #expect(response.recentCheckpoints.map(\.checkpoint.id) == [context.newerCheckpoint.id])
        #expect(response.validationRuns.map(\.validationRun.id) == [context.endedValidationRun.id])
        #expect(response.conflicts.isEmpty)
    }

    @Test
    func sqliteClientFiltersInactiveSessionsAndContributionsFromActiveSections() async throws {
        let context = try await Self.seedCurrentContext()
        defer { Self.removeTemporaryDatabaseDirectory(for: context.databaseURL) }

        let response = try await context.client.currentContext(
            ProvenanceCurrentContextRequest(repositoryPath: context.repository.path)
        )

        #expect(!response.activeSessions.map(\.session.id).contains(context.completedSession.id))
        #expect(!response.conflicts.contains { $0.contributionIDs?.contains(context.completedContribution.id) == true })
        #expect(response.dirtyFiles.contains { $0.contribution == context.completedContribution })
    }

    private static func seedCurrentContext() async throws -> CurrentContextFixture {
        let url = temporaryDatabaseURL()
        let client = try ProvenanceEngineClientFactory().sqliteClient(databaseURL: url)
        let timestamp = Date(timeIntervalSince1970: 1_800_000_000)
        let repository = ProvenanceRepositoryRecord(
            id: "repository-current",
            path: "/repos/current",
            remoteSlug: "owner/current",
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let worktree = ProvenanceWorktreeRecord(
            id: "worktree-current",
            repositoryID: repository.id,
            path: repository.path,
            branch: "main",
            currentHEAD: "current-head",
            isDirty: true,
            status: "active",
            lastReconciledAt: timestamp.addingTimeInterval(5),
            updatedAt: timestamp.addingTimeInterval(5)
        )
        let olderSession = session(
            id: "session-older",
            worktreeID: worktree.id,
            status: "active",
            timestamp: timestamp.addingTimeInterval(10)
        )
        let newerSession = session(
            id: "session-newer",
            worktreeID: worktree.id,
            status: "active",
            timestamp: timestamp.addingTimeInterval(20)
        )
        let completedSession = session(
            id: "session-completed",
            worktreeID: worktree.id,
            status: "completed",
            timestamp: timestamp.addingTimeInterval(30)
        )
        let olderWorkItem = workItem(id: "work-item-older", title: "Older context", timestamp: timestamp)
        let newerWorkItem = workItem(id: "work-item-newer", title: "Newer context", timestamp: timestamp)
        let completedWorkItem = workItem(id: "work-item-completed", title: "Completed context", timestamp: timestamp)
        let olderContribution = contribution(
            id: "contribution-older",
            sessionID: olderSession.id,
            worktreeID: worktree.id,
            workItemID: olderWorkItem.id,
            status: "active",
            timestamp: timestamp.addingTimeInterval(10)
        )
        let newerContribution = contribution(
            id: "contribution-newer",
            sessionID: newerSession.id,
            worktreeID: worktree.id,
            workItemID: newerWorkItem.id,
            status: "active",
            timestamp: timestamp.addingTimeInterval(20)
        )
        let completedContribution = contribution(
            id: "contribution-completed",
            sessionID: completedSession.id,
            worktreeID: worktree.id,
            workItemID: completedWorkItem.id,
            status: "completed",
            timestamp: timestamp.addingTimeInterval(30)
        )
        let olderCheckpoint = checkpoint(
            id: "checkpoint-older",
            contributionID: olderContribution.id,
            sequence: 1,
            timestamp: timestamp.addingTimeInterval(40)
        )
        let newerCheckpoint = checkpoint(
            id: "checkpoint-newer",
            contributionID: newerContribution.id,
            sequence: 2,
            timestamp: timestamp.addingTimeInterval(50)
        )
        let runningValidationRun = ProvenanceValidationRunRecord(
            id: "validation-running",
            checkpointID: olderCheckpoint.id,
            command: "swift test",
            status: "running",
            summary: "Still running",
            startedAt: timestamp.addingTimeInterval(55)
        )
        let endedValidationRun = ProvenanceValidationRunRecord(
            id: "validation-ended",
            checkpointID: newerCheckpoint.id,
            command: "swift build",
            status: "passed",
            summary: "Build passed",
            startedAt: timestamp.addingTimeInterval(60),
            endedAt: timestamp.addingTimeInterval(70)
        )
        let attributedChangeSet = changeSet(
            id: "change-set-attributed",
            contributionID: completedContribution.id,
            worktreeID: worktree.id,
            timestamp: timestamp.addingTimeInterval(80)
        )
        let conflictChangeSetA = changeSet(
            id: "change-set-conflict-a",
            contributionID: olderContribution.id,
            worktreeID: worktree.id,
            timestamp: timestamp.addingTimeInterval(90)
        )
        let conflictChangeSetB = changeSet(
            id: "change-set-conflict-b",
            contributionID: newerContribution.id,
            worktreeID: worktree.id,
            timestamp: timestamp.addingTimeInterval(100)
        )
        let unattributedChangeSet = changeSet(
            id: "change-set-unattributed",
            contributionID: nil,
            worktreeID: worktree.id,
            timestamp: timestamp.addingTimeInterval(110)
        )
        let attributedFile = fileChange(
            id: "file-attributed",
            changeSetID: attributedChangeSet.id,
            repositoryID: repository.id,
            worktreeID: worktree.id,
            path: "Sources/Completed.swift",
            attributionSource: .declared,
            attributionConfidence: .high,
            timestamp: timestamp.addingTimeInterval(80)
        )
        let conflictPath = "Sources/Shared.swift"
        let conflictFileA = fileChange(
            id: "file-conflict-a",
            changeSetID: conflictChangeSetA.id,
            repositoryID: repository.id,
            worktreeID: worktree.id,
            path: conflictPath,
            attributionSource: .observed,
            attributionConfidence: .medium,
            timestamp: timestamp.addingTimeInterval(90)
        )
        let conflictFileB = fileChange(
            id: "file-conflict-b",
            changeSetID: conflictChangeSetB.id,
            repositoryID: repository.id,
            worktreeID: worktree.id,
            path: conflictPath,
            attributionSource: .observed,
            attributionConfidence: .medium,
            timestamp: timestamp.addingTimeInterval(100)
        )
        let unattributedFile = fileChange(
            id: "file-unattributed",
            changeSetID: unattributedChangeSet.id,
            repositoryID: repository.id,
            worktreeID: worktree.id,
            path: "Sources/Unattributed.swift",
            attributionSource: .unattributed,
            attributionConfidence: .unknown,
            timestamp: timestamp.addingTimeInterval(110)
        )

        try await append(
            client: client,
            eventID: "event-worktree",
            timestamp: timestamp,
            repositoryID: repository.id,
            worktreeID: worktree.id,
            payload: ProvenanceEventPayload(repository: repository, worktree: worktree)
        )
        try await append(
            client: client,
            eventID: "event-older-context",
            timestamp: olderSession.updatedAt,
            repositoryID: repository.id,
            worktreeID: worktree.id,
            sessionID: olderSession.id,
            contributionID: olderContribution.id,
            payload: ProvenanceEventPayload(
                session: olderSession,
                workItem: olderWorkItem,
                contribution: olderContribution,
                checkpoint: olderCheckpoint
            )
        )
        try await append(
            client: client,
            eventID: "event-newer-context",
            timestamp: newerSession.updatedAt,
            repositoryID: repository.id,
            worktreeID: worktree.id,
            sessionID: newerSession.id,
            contributionID: newerContribution.id,
            payload: ProvenanceEventPayload(
                session: newerSession,
                workItem: newerWorkItem,
                contribution: newerContribution,
                checkpoint: newerCheckpoint
            )
        )
        try await append(
            client: client,
            eventID: "event-completed-context",
            timestamp: completedSession.updatedAt,
            repositoryID: repository.id,
            worktreeID: worktree.id,
            sessionID: completedSession.id,
            contributionID: completedContribution.id,
            payload: ProvenanceEventPayload(
                session: completedSession,
                workItem: completedWorkItem,
                contribution: completedContribution
            )
        )
        try await append(
            client: client,
            eventID: "event-running-validation",
            timestamp: timestamp.addingTimeInterval(55),
            repositoryID: repository.id,
            worktreeID: worktree.id,
            contributionID: olderContribution.id,
            payload: ProvenanceEventPayload(validationRun: runningValidationRun)
        )
        try await append(
            client: client,
            eventID: "event-ended-validation",
            timestamp: timestamp.addingTimeInterval(70),
            repositoryID: repository.id,
            worktreeID: worktree.id,
            contributionID: newerContribution.id,
            payload: ProvenanceEventPayload(validationRun: endedValidationRun)
        )
        try await appendFileChange(
            client: client,
            eventID: "event-attributed-file",
            repositoryID: repository.id,
            worktreeID: worktree.id,
            contributionID: completedContribution.id,
            changeSet: attributedChangeSet,
            fileChange: attributedFile
        )
        try await appendFileChange(
            client: client,
            eventID: "event-conflict-file-a",
            repositoryID: repository.id,
            worktreeID: worktree.id,
            contributionID: olderContribution.id,
            changeSet: conflictChangeSetA,
            fileChange: conflictFileA
        )
        try await appendFileChange(
            client: client,
            eventID: "event-conflict-file-b",
            repositoryID: repository.id,
            worktreeID: worktree.id,
            contributionID: newerContribution.id,
            changeSet: conflictChangeSetB,
            fileChange: conflictFileB
        )
        try await appendFileChange(
            client: client,
            eventID: "event-unattributed-file",
            repositoryID: repository.id,
            worktreeID: worktree.id,
            contributionID: nil,
            changeSet: unattributedChangeSet,
            fileChange: unattributedFile
        )

        return CurrentContextFixture(
            client: client,
            databaseURL: url,
            repository: repository,
            worktree: worktree,
            olderSession: olderSession,
            newerSession: newerSession,
            completedSession: completedSession,
            olderWorkItem: olderWorkItem,
            newerWorkItem: newerWorkItem,
            completedWorkItem: completedWorkItem,
            olderContribution: olderContribution,
            newerContribution: newerContribution,
            completedContribution: completedContribution,
            olderCheckpoint: olderCheckpoint,
            newerCheckpoint: newerCheckpoint,
            runningValidationRun: runningValidationRun,
            endedValidationRun: endedValidationRun,
            attributedFile: attributedFile,
            conflictPath: conflictPath,
            conflictFileA: conflictFileA,
            conflictFileB: conflictFileB,
            unattributedFile: unattributedFile
        )
    }

    private static func session(
        id: String,
        worktreeID: String,
        status: String,
        timestamp: Date
    ) -> ProvenanceSessionRecord {
        ProvenanceSessionRecord(
            id: id,
            agentKind: "codex",
            workspaceID: "workspace-\(id)",
            surfaceID: "surface-\(id)",
            worktreeID: worktreeID,
            cwd: "/repos/current",
            status: status,
            startedAt: timestamp,
            updatedAt: timestamp
        )
    }

    private static func workItem(id: String, title: String, timestamp: Date) -> ProvenanceWorkItemRecord {
        ProvenanceWorkItemRecord(
            id: id,
            title: title,
            status: "active",
            createdAt: timestamp,
            updatedAt: timestamp
        )
    }

    private static func contribution(
        id: String,
        sessionID: String,
        worktreeID: String,
        workItemID: String,
        status: String,
        timestamp: Date
    ) -> ProvenanceContributionRecord {
        ProvenanceContributionRecord(
            id: id,
            sessionID: sessionID,
            worktreeID: worktreeID,
            workItemID: workItemID,
            declaredIntent: "Maintain current context",
            expectedScope: ["Sources"],
            status: status,
            startedAt: timestamp,
            endedAt: status == "completed" ? timestamp.addingTimeInterval(5) : nil,
            assignmentConfidence: .high,
            updatedAt: timestamp
        )
    }

    private static func checkpoint(
        id: String,
        contributionID: String,
        sequence: Int,
        timestamp: Date
    ) -> ProvenanceCheckpointRecord {
        ProvenanceCheckpointRecord(
            id: id,
            contributionID: contributionID,
            sequence: sequence,
            gitHEAD: "head-\(sequence)",
            diffFingerprint: "diff-\(sequence)",
            summary: "Checkpoint \(sequence)",
            status: "in_progress",
            validationState: "not_run",
            semanticConfidence: .medium,
            freshness: "fresh",
            createdAt: timestamp
        )
    }

    private static func changeSet(
        id: String,
        contributionID: String?,
        worktreeID: String,
        timestamp: Date
    ) -> ProvenanceChangeSetRecord {
        ProvenanceChangeSetRecord(
            id: id,
            contributionID: contributionID,
            worktreeID: worktreeID,
            summary: id,
            diffFingerprint: "\(id)-diff",
            createdAt: timestamp
        )
    }

    private static func fileChange(
        id: String,
        changeSetID: String,
        repositoryID: String,
        worktreeID: String,
        path: String,
        attributionSource: ProvenanceSource,
        attributionConfidence: ProvenanceConfidence,
        timestamp: Date
    ) -> ProvenanceFileChangeRecord {
        ProvenanceFileChangeRecord(
            id: id,
            changeSetID: changeSetID,
            repositoryID: repositoryID,
            worktreeID: worktreeID,
            path: path,
            status: "modified",
            attributionSource: attributionSource,
            attributionConfidence: attributionConfidence,
            updatedAt: timestamp
        )
    }

    private static func appendFileChange(
        client: any ProvenanceEngineClient,
        eventID: String,
        repositoryID: String,
        worktreeID: String,
        contributionID: String?,
        changeSet: ProvenanceChangeSetRecord,
        fileChange: ProvenanceFileChangeRecord
    ) async throws {
        try await append(
            client: client,
            eventID: eventID,
            timestamp: fileChange.updatedAt,
            repositoryID: repositoryID,
            worktreeID: worktreeID,
            contributionID: contributionID,
            payload: ProvenanceEventPayload(changeSet: changeSet, fileChanges: [fileChange])
        )
    }

    private static func append(
        client: any ProvenanceEngineClient,
        eventID: String,
        timestamp: Date,
        repositoryID: String?,
        worktreeID: String?,
        sessionID: String? = nil,
        contributionID: String? = nil,
        payload: ProvenanceEventPayload
    ) async throws {
        _ = try await client.appendEvent(
            ProvenanceAppendEventRequest(
                event: ProvenanceEvent(
                    id: eventID,
                    eventType: .worktreeObserved,
                    timestamp: timestamp,
                    repositoryID: repositoryID,
                    worktreeID: worktreeID,
                    sessionID: sessionID,
                    contributionID: contributionID,
                    source: .observed,
                    confidence: .high,
                    payload: payload
                )
            )
        )
    }

    private static func temporaryDatabaseURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("provenance-engine-current-context-sdk-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("provenance.sqlite")
    }

    private static func removeTemporaryDatabaseDirectory(for url: URL) {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }
}

private struct CurrentContextFixture {
    let client: any ProvenanceEngineClient
    let databaseURL: URL
    let repository: ProvenanceRepositoryRecord
    let worktree: ProvenanceWorktreeRecord
    let olderSession: ProvenanceSessionRecord
    let newerSession: ProvenanceSessionRecord
    let completedSession: ProvenanceSessionRecord
    let olderWorkItem: ProvenanceWorkItemRecord
    let newerWorkItem: ProvenanceWorkItemRecord
    let completedWorkItem: ProvenanceWorkItemRecord
    let olderContribution: ProvenanceContributionRecord
    let newerContribution: ProvenanceContributionRecord
    let completedContribution: ProvenanceContributionRecord
    let olderCheckpoint: ProvenanceCheckpointRecord
    let newerCheckpoint: ProvenanceCheckpointRecord
    let runningValidationRun: ProvenanceValidationRunRecord
    let endedValidationRun: ProvenanceValidationRunRecord
    let attributedFile: ProvenanceFileChangeRecord
    let conflictPath: String
    let conflictFileA: ProvenanceFileChangeRecord
    let conflictFileB: ProvenanceFileChangeRecord
    let unattributedFile: ProvenanceFileChangeRecord
}
