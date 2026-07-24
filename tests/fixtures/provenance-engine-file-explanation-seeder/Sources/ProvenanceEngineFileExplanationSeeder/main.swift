import Foundation
import ProvenanceEngineContracts
import ProvenanceEngineSDK

@main
struct ProvenanceEngineFileExplanationSeeder {
    static func main() async throws {
        let arguments = CommandLine.arguments
        guard arguments.count >= 5 else {
            throw SeederError.usage
        }

        let databaseURL = URL(fileURLWithPath: arguments[1])
        let repositoryRoot = arguments[2]
        let repositoryID = arguments[3]
        let worktreeID = arguments[4]
        let includeWorktree = !arguments.contains("--no-worktree")
        let includeFile = !arguments.contains("--no-file")

        try FileManager.default.createDirectory(
            at: databaseURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if FileManager.default.fileExists(atPath: databaseURL.path) {
            try FileManager.default.removeItem(at: databaseURL)
        }

        let client = try ProvenanceEngineClientFactory().sqliteClient(databaseURL: databaseURL)
        guard includeWorktree else { return }

        let createdAt = Date(timeIntervalSince1970: 100)
        let repository = ProvenanceRepositoryRecord(
            id: repositoryID,
            path: repositoryRoot,
            remoteSlug: "manaflow-ai/bmux",
            createdAt: createdAt,
            updatedAt: Date(timeIntervalSince1970: 160)
        )
        let worktree = ProvenanceWorktreeRecord(
            id: worktreeID,
            repositoryID: repositoryID,
            path: repositoryRoot,
            branch: "provenance-extraction-phase2-contracts",
            currentHEAD: "abc123",
            isDirty: true,
            status: "active",
            lastReconciledAt: Date(timeIntervalSince1970: 150),
            updatedAt: Date(timeIntervalSince1970: 160)
        )
        try await append(
            client: client,
            eventID: "seed-explain-worktree",
            timestamp: 160,
            repositoryID: repositoryID,
            worktreeID: worktreeID,
            payload: ProvenanceEventPayload(repository: repository, worktree: worktree)
        )

        guard includeFile else { return }

        let session = ProvenanceSessionRecord(
            id: "session-1",
            agentKind: "codex",
            workspaceID: "workspace-1",
            surfaceID: "surface-1",
            worktreeID: worktreeID,
            cwd: repositoryRoot,
            status: "active",
            startedAt: Date(timeIntervalSince1970: 110),
            updatedAt: Date(timeIntervalSince1970: 155)
        )
        let workItem = ProvenanceWorkItemRecord(
            id: "WI-1",
            title: "Explain dirty files",
            status: "active",
            createdAt: Date(timeIntervalSince1970: 105),
            updatedAt: Date(timeIntervalSince1970: 155)
        )
        let contribution = ProvenanceContributionRecord(
            id: "contribution-1",
            sessionID: session.id,
            worktreeID: worktreeID,
            workItemID: workItem.id,
            declaredIntent: "Capture work provenance",
            expectedScope: ["Sources/WorkspaceManager.swift"],
            status: "active",
            startedAt: Date(timeIntervalSince1970: 110),
            assignmentConfidence: .medium,
            updatedAt: Date(timeIntervalSince1970: 155)
        )
        let checkpoint = ProvenanceCheckpointRecord(
            id: "checkpoint-1",
            contributionID: contribution.id,
            sequence: 1,
            gitHEAD: "head",
            diffFingerprint: "diff-1",
            summary: "Recorded first batch",
            status: "in_progress",
            validationState: "not_run",
            semanticConfidence: .medium,
            freshness: "fresh",
            createdAt: Date(timeIntervalSince1970: 140)
        )

        let olderChangeSet = ProvenanceChangeSetRecord(
            id: "changeset-old",
            checkpointID: checkpoint.id,
            contributionID: contribution.id,
            worktreeID: worktreeID,
            summary: "Older workspace provenance",
            diffFingerprint: "diff-old",
            createdAt: Date(timeIntervalSince1970: 135)
        )
        let olderFile = ProvenanceFileChangeRecord(
            id: "file-old",
            changeSetID: olderChangeSet.id,
            repositoryID: repositoryID,
            worktreeID: worktreeID,
            path: "Sources/WorkspaceManager.swift",
            status: "modified",
            beforeHash: "older-before",
            afterHash: "older-after",
            attributionSource: .observed,
            attributionConfidence: .medium,
            updatedAt: Date(timeIntervalSince1970: 140)
        )
        try await append(
            client: client,
            eventID: "seed-explain-older-file",
            timestamp: 140,
            repositoryID: repositoryID,
            worktreeID: worktreeID,
            sessionID: session.id,
            contributionID: contribution.id,
            payload: ProvenanceEventPayload(
                session: session,
                workItem: workItem,
                contribution: contribution,
                checkpoint: checkpoint,
                changeSet: olderChangeSet,
                fileChanges: [olderFile]
            )
        )

        let newestChangeSet = ProvenanceChangeSetRecord(
            id: "changeset-1",
            checkpointID: checkpoint.id,
            contributionID: contribution.id,
            worktreeID: worktreeID,
            summary: "Workspace provenance",
            diffFingerprint: "diff-1",
            createdAt: Date(timeIntervalSince1970: 145)
        )
        let newestFile = ProvenanceFileChangeRecord(
            id: "file-1",
            changeSetID: newestChangeSet.id,
            repositoryID: repositoryID,
            worktreeID: worktreeID,
            path: "Sources/WorkspaceManager.swift",
            status: "modified",
            beforeHash: "before",
            afterHash: "after",
            attributionSource: .observed,
            attributionConfidence: .high,
            updatedAt: Date(timeIntervalSince1970: 150)
        )
        try await append(
            client: client,
            eventID: "seed-explain-newest-file",
            timestamp: 150,
            repositoryID: repositoryID,
            worktreeID: worktreeID,
            sessionID: session.id,
            contributionID: contribution.id,
            payload: ProvenanceEventPayload(
                changeSet: newestChangeSet,
                fileChanges: [newestFile]
            )
        )

        let unattributedChangeSet = ProvenanceChangeSetRecord(
            id: "changeset-unattributed",
            worktreeID: worktreeID,
            summary: "Observed unclaimed edit",
            diffFingerprint: "diff-unattributed",
            createdAt: Date(timeIntervalSince1970: 165)
        )
        let unattributedFile = ProvenanceFileChangeRecord(
            id: "file-unattributed",
            changeSetID: unattributedChangeSet.id,
            repositoryID: repositoryID,
            worktreeID: worktreeID,
            path: "Sources/Unattributed.swift",
            status: "modified",
            attributionSource: .unattributed,
            attributionConfidence: .low,
            updatedAt: Date(timeIntervalSince1970: 165)
        )
        try await append(
            client: client,
            eventID: "seed-explain-unattributed-file",
            timestamp: 165,
            repositoryID: repositoryID,
            worktreeID: worktreeID,
            payload: ProvenanceEventPayload(
                changeSet: unattributedChangeSet,
                fileChanges: [unattributedFile]
            )
        )
    }

    private static func append(
        client: any ProvenanceEngineClient,
        eventID: String,
        timestamp: TimeInterval,
        repositoryID: String,
        worktreeID: String,
        sessionID: String? = nil,
        contributionID: String? = nil,
        payload: ProvenanceEventPayload
    ) async throws {
        let date = Date(timeIntervalSince1970: timestamp)
        _ = try await client.appendEvent(ProvenanceAppendEventRequest(
            event: ProvenanceEvent(
                id: eventID,
                eventType: .progressCheckpoint,
                timestamp: date,
                repositoryID: repositoryID,
                worktreeID: worktreeID,
                sessionID: sessionID,
                contributionID: contributionID,
                source: .observed,
                confidence: .high,
                payload: payload
            )
        ))
    }
}

enum SeederError: Error, CustomStringConvertible {
    case usage

    var description: String {
        switch self {
        case .usage:
            return "Usage: ProvenanceEngineFileExplanationSeeder <database-path> <repository-root> <repository-id> <worktree-id> [--no-worktree] [--no-file]"
        }
    }
}
