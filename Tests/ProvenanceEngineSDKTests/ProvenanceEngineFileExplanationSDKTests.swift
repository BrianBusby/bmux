import Foundation
import ProvenanceEngineContracts
import ProvenanceEngineSDK
import Testing

@Suite
struct ProvenanceEngineFileExplanationSDKTests {
    @Test
    func sqliteClientReadsAttributedFileExplanationThroughPublicContract() async throws {
        let context = try await Self.seedFileExplanationContext()
        defer { Self.removeTemporaryDatabaseDirectory(for: context.databaseURL) }
        let response = try await context.client.fileExplanation(
            ProvenanceFileExplanationRequest(
                worktreeID: context.primaryWorktree.id,
                path: context.attributedFile.path
            )
        )

        #expect(response.found)
        #expect(response.reason == nil)
        #expect(response.explanation == ProvenanceFileExplanation(
            fileChange: context.attributedFile,
            changeSet: context.attributedChangeSet,
            checkpoint: context.checkpoint,
            contribution: context.contribution,
            session: context.session,
            workItem: context.workItem,
            worktree: context.primaryWorktree,
            repository: context.primaryRepository
        ))
    }

    @Test
    func sqliteClientReturnsNoFileForMissingFileExplanation() async throws {
        let context = try await Self.seedFileExplanationContext()
        defer { Self.removeTemporaryDatabaseDirectory(for: context.databaseURL) }

        let response = try await context.client.fileExplanation(
            ProvenanceFileExplanationRequest(
                worktreeID: context.primaryWorktree.id,
                path: "Sources/Missing.swift"
            )
        )

        #expect(response == ProvenanceFileExplanationResponse(
            found: false,
            reason: "no_file",
            explanation: nil
        ))
    }

    @Test
    func sqliteClientReadsNormalizedRepositoryRelativePath() async throws {
        let context = try await Self.seedFileExplanationContext()
        defer { Self.removeTemporaryDatabaseDirectory(for: context.databaseURL) }
        let consumerNormalizedPath = Self.normalizedRepositoryRelativePath(
            "./Sources/../Sources/Attributed.swift"
        )

        let response = try await context.client.fileExplanation(
            ProvenanceFileExplanationRequest(
                worktreeID: context.primaryWorktree.id,
                path: consumerNormalizedPath
            )
        )

        #expect(consumerNormalizedPath == context.attributedFile.path)
        #expect(response.found)
        #expect(response.explanation?.fileChange == context.attributedFile)
    }

    @Test
    func sqliteClientReturnsNewestMatchingFileEvidence() async throws {
        let context = try await Self.seedFileExplanationContext()
        defer { Self.removeTemporaryDatabaseDirectory(for: context.databaseURL) }

        let response = try await context.client.fileExplanation(
            ProvenanceFileExplanationRequest(
                worktreeID: context.primaryWorktree.id,
                path: context.attributedFile.path
            )
        )

        #expect(response.found)
        #expect(response.explanation?.fileChange == context.attributedFile)
        #expect(response.explanation?.changeSet == context.attributedChangeSet)
        #expect(response.explanation?.fileChange.id != context.olderAttributedFile.id)
    }

    @Test
    func sqliteClientReadsUnattributedFileExplanationWithoutAttributionRecords() async throws {
        let context = try await Self.seedFileExplanationContext()
        defer { Self.removeTemporaryDatabaseDirectory(for: context.databaseURL) }

        let response = try await context.client.fileExplanation(
            ProvenanceFileExplanationRequest(
                worktreeID: context.primaryWorktree.id,
                path: context.unattributedFile.path
            )
        )

        #expect(response.found)
        #expect(response.explanation?.fileChange == context.unattributedFile)
        #expect(response.explanation?.fileChange.attributionSource == .unattributed)
        #expect(response.explanation?.changeSet == context.unattributedChangeSet)
        #expect(response.explanation?.checkpoint == nil)
        #expect(response.explanation?.contribution == nil)
        #expect(response.explanation?.session == nil)
        #expect(response.explanation?.workItem == nil)
        #expect(response.explanation?.worktree == context.primaryWorktree)
        #expect(response.explanation?.repository == context.primaryRepository)
    }

    @Test
    func sqliteClientUsesWorktreeIdentityForSameRepositoryRelativePath() async throws {
        let context = try await Self.seedFileExplanationContext()
        defer { Self.removeTemporaryDatabaseDirectory(for: context.databaseURL) }

        let primaryResponse = try await context.client.fileExplanation(
            ProvenanceFileExplanationRequest(
                worktreeID: context.primaryWorktree.id,
                path: context.attributedFile.path
            )
        )
        let secondaryResponse = try await context.client.fileExplanation(
            ProvenanceFileExplanationRequest(
                worktreeID: context.secondaryWorktree.id,
                path: context.secondaryWorktreeFile.path
            )
        )

        #expect(primaryResponse.explanation?.fileChange == context.attributedFile)
        #expect(primaryResponse.explanation?.worktree == context.primaryWorktree)
        #expect(primaryResponse.explanation?.repository == context.primaryRepository)
        #expect(secondaryResponse.explanation?.fileChange == context.secondaryWorktreeFile)
        #expect(secondaryResponse.explanation?.worktree == context.secondaryWorktree)
        #expect(secondaryResponse.explanation?.repository == context.secondaryRepository)
    }

    @Test
    func sqliteClientReturnsOnlyOneFileExplanationResult() async throws {
        let context = try await Self.seedFileExplanationContext()
        defer { Self.removeTemporaryDatabaseDirectory(for: context.databaseURL) }

        let response = try await context.client.fileExplanation(
            ProvenanceFileExplanationRequest(
                worktreeID: context.primaryWorktree.id,
                path: context.attributedFile.path
            )
        )

        #expect(response.found)
        #expect(response.explanation != nil)
        #expect(response.schemaVersion == 1)
    }

    private static func seedFileExplanationContext() async throws -> FileExplanationContext {
        let url = temporaryDatabaseURL()
        let client = try ProvenanceEngineClientFactory().sqliteClient(databaseURL: url)
        let timestamp = Date(timeIntervalSince1970: 1_800_000_000)
        let primaryRepository = ProvenanceRepositoryRecord(
            id: "repository-primary",
            path: "/repos/project",
            remoteSlug: "owner/project",
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let secondaryRepository = ProvenanceRepositoryRecord(
            id: "repository-secondary",
            path: "/repos/project-secondary",
            remoteSlug: "owner/project-secondary",
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let primaryWorktree = ProvenanceWorktreeRecord(
            id: "worktree-primary",
            repositoryID: primaryRepository.id,
            path: primaryRepository.path,
            branch: "main",
            currentHEAD: "abc123",
            isDirty: true,
            status: "active",
            updatedAt: timestamp
        )
        let secondaryWorktree = ProvenanceWorktreeRecord(
            id: "worktree-secondary",
            repositoryID: secondaryRepository.id,
            path: secondaryRepository.path,
            branch: "feature",
            currentHEAD: "def456",
            isDirty: true,
            status: "active",
            updatedAt: timestamp
        )
        let session = ProvenanceSessionRecord(
            id: "session-1",
            agentKind: "codex",
            workspaceID: "workspace-1",
            surfaceID: "surface-1",
            worktreeID: primaryWorktree.id,
            cwd: primaryWorktree.path,
            status: "active",
            startedAt: timestamp,
            updatedAt: timestamp
        )
        let workItem = ProvenanceWorkItemRecord(
            id: "work-item-1",
            title: "Explain dirty files",
            status: "active",
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let contribution = ProvenanceContributionRecord(
            id: "contribution-1",
            sessionID: session.id,
            worktreeID: primaryWorktree.id,
            workItemID: workItem.id,
            declaredIntent: "Capture work provenance",
            expectedScope: ["Sources/Attributed.swift"],
            status: "active",
            startedAt: timestamp,
            assignmentConfidence: .medium,
            updatedAt: timestamp
        )
        let checkpoint = ProvenanceCheckpointRecord(
            id: "checkpoint-1",
            contributionID: contribution.id,
            sequence: 1,
            gitHEAD: "abc123",
            diffFingerprint: "diff-1",
            summary: "Recorded first batch",
            status: "in_progress",
            validationState: "not_run",
            semanticConfidence: .medium,
            freshness: "fresh",
            createdAt: timestamp
        )
        let olderChangeSet = ProvenanceChangeSetRecord(
            id: "change-set-older",
            checkpointID: checkpoint.id,
            contributionID: contribution.id,
            worktreeID: primaryWorktree.id,
            summary: "Older workspace provenance",
            diffFingerprint: "diff-older",
            createdAt: timestamp
        )
        let attributedChangeSet = ProvenanceChangeSetRecord(
            id: "change-set-attributed",
            checkpointID: checkpoint.id,
            contributionID: contribution.id,
            worktreeID: primaryWorktree.id,
            summary: "Workspace provenance",
            diffFingerprint: "diff-newer",
            createdAt: timestamp.addingTimeInterval(20)
        )
        let unattributedChangeSet = ProvenanceChangeSetRecord(
            id: "change-set-unattributed",
            worktreeID: primaryWorktree.id,
            summary: "Observed unclaimed edit",
            diffFingerprint: "diff-unattributed",
            createdAt: timestamp.addingTimeInterval(30)
        )
        let secondaryChangeSet = ProvenanceChangeSetRecord(
            id: "change-set-secondary",
            worktreeID: secondaryWorktree.id,
            summary: "Secondary worktree edit",
            diffFingerprint: "diff-secondary",
            createdAt: timestamp.addingTimeInterval(40)
        )
        let olderAttributedFile = ProvenanceFileChangeRecord(
            id: "file-attributed-older",
            changeSetID: olderChangeSet.id,
            repositoryID: primaryRepository.id,
            worktreeID: primaryWorktree.id,
            path: "Sources/Attributed.swift",
            status: "modified",
            beforeHash: "before-older",
            afterHash: "after-older",
            attributionSource: .observed,
            attributionConfidence: .medium,
            updatedAt: timestamp.addingTimeInterval(10)
        )
        let attributedFile = ProvenanceFileChangeRecord(
            id: "file-attributed-newer",
            changeSetID: attributedChangeSet.id,
            repositoryID: primaryRepository.id,
            worktreeID: primaryWorktree.id,
            path: "Sources/Attributed.swift",
            status: "modified",
            beforeHash: "before",
            afterHash: "after",
            attributionSource: .declared,
            attributionConfidence: .high,
            updatedAt: timestamp.addingTimeInterval(20)
        )
        let unattributedFile = ProvenanceFileChangeRecord(
            id: "file-unattributed",
            changeSetID: unattributedChangeSet.id,
            repositoryID: primaryRepository.id,
            worktreeID: primaryWorktree.id,
            path: "Sources/Unattributed.swift",
            status: "modified",
            attributionSource: .unattributed,
            attributionConfidence: .unknown,
            updatedAt: timestamp.addingTimeInterval(30)
        )
        let secondaryWorktreeFile = ProvenanceFileChangeRecord(
            id: "file-secondary",
            changeSetID: secondaryChangeSet.id,
            repositoryID: secondaryRepository.id,
            worktreeID: secondaryWorktree.id,
            path: "Sources/Attributed.swift",
            status: "added",
            attributionSource: .observed,
            attributionConfidence: .high,
            updatedAt: timestamp.addingTimeInterval(40)
        )

        try await append(
            client: client,
            eventID: "event-bootstrap-primary",
            timestamp: timestamp,
            repositoryID: primaryRepository.id,
            worktreeID: primaryWorktree.id,
            payload: ProvenanceEventPayload(repository: primaryRepository, worktree: primaryWorktree)
        )
        try await append(
            client: client,
            eventID: "event-bootstrap-secondary",
            timestamp: timestamp,
            repositoryID: secondaryRepository.id,
            worktreeID: secondaryWorktree.id,
            payload: ProvenanceEventPayload(repository: secondaryRepository, worktree: secondaryWorktree)
        )
        try await append(
            client: client,
            eventID: "event-attribution-context",
            timestamp: timestamp,
            repositoryID: primaryRepository.id,
            worktreeID: primaryWorktree.id,
            sessionID: session.id,
            contributionID: contribution.id,
            payload: ProvenanceEventPayload(
                session: session,
                workItem: workItem,
                contribution: contribution,
                checkpoint: checkpoint
            )
        )
        try await append(
            client: client,
            eventID: "event-file-older",
            timestamp: olderAttributedFile.updatedAt,
            repositoryID: primaryRepository.id,
            worktreeID: primaryWorktree.id,
            contributionID: contribution.id,
            payload: ProvenanceEventPayload(changeSet: olderChangeSet, fileChanges: [olderAttributedFile])
        )
        try await append(
            client: client,
            eventID: "event-file-newer",
            timestamp: attributedFile.updatedAt,
            repositoryID: primaryRepository.id,
            worktreeID: primaryWorktree.id,
            contributionID: contribution.id,
            payload: ProvenanceEventPayload(changeSet: attributedChangeSet, fileChanges: [attributedFile])
        )
        try await append(
            client: client,
            eventID: "event-file-unattributed",
            timestamp: unattributedFile.updatedAt,
            repositoryID: primaryRepository.id,
            worktreeID: primaryWorktree.id,
            payload: ProvenanceEventPayload(changeSet: unattributedChangeSet, fileChanges: [unattributedFile])
        )
        try await append(
            client: client,
            eventID: "event-file-secondary",
            timestamp: secondaryWorktreeFile.updatedAt,
            repositoryID: secondaryRepository.id,
            worktreeID: secondaryWorktree.id,
            payload: ProvenanceEventPayload(changeSet: secondaryChangeSet, fileChanges: [secondaryWorktreeFile])
        )

        return FileExplanationContext(
            client: client,
            databaseURL: url,
            primaryRepository: primaryRepository,
            secondaryRepository: secondaryRepository,
            primaryWorktree: primaryWorktree,
            secondaryWorktree: secondaryWorktree,
            session: session,
            workItem: workItem,
            contribution: contribution,
            checkpoint: checkpoint,
            olderAttributedFile: olderAttributedFile,
            attributedChangeSet: attributedChangeSet,
            unattributedChangeSet: unattributedChangeSet,
            attributedFile: attributedFile,
            unattributedFile: unattributedFile,
            secondaryWorktreeFile: secondaryWorktreeFile
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

    private static func normalizedRepositoryRelativePath(_ path: String) -> String {
        var components: [String] = []
        for component in path.split(separator: "/") {
            switch component {
            case ".":
                continue
            case "..":
                _ = components.popLast()
            default:
                components.append(String(component))
            }
        }
        return components.joined(separator: "/")
    }

    private static func temporaryDatabaseURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("provenance-engine-file-explanation-sdk-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("provenance.sqlite")
    }

    private static func removeTemporaryDatabaseDirectory(for url: URL) {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }
}

private struct FileExplanationContext {
    let client: any ProvenanceEngineClient
    let databaseURL: URL
    let primaryRepository: ProvenanceRepositoryRecord
    let secondaryRepository: ProvenanceRepositoryRecord
    let primaryWorktree: ProvenanceWorktreeRecord
    let secondaryWorktree: ProvenanceWorktreeRecord
    let session: ProvenanceSessionRecord
    let workItem: ProvenanceWorkItemRecord
    let contribution: ProvenanceContributionRecord
    let checkpoint: ProvenanceCheckpointRecord
    let olderAttributedFile: ProvenanceFileChangeRecord
    let attributedChangeSet: ProvenanceChangeSetRecord
    let unattributedChangeSet: ProvenanceChangeSetRecord
    let attributedFile: ProvenanceFileChangeRecord
    let unattributedFile: ProvenanceFileChangeRecord
    let secondaryWorktreeFile: ProvenanceFileChangeRecord
}
