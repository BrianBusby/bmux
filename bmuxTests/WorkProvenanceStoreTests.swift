import Foundation
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@Suite
struct WorkProvenanceStoreTests {
    @Test
    func appendReplayAndExplainFileChanges() async throws {
        let fixture = try StoreFixture()
        defer { fixture.remove() }
        let store = try WorkProvenanceStore(databaseURL: fixture.databaseURL)

        try await store.append(Self.attributedEvent())
        try await store.append(Self.unattributedEvent())
        try await store.rebuildProjections()

        let events = try await store.events()
        let attributed = try await store.fileExplanation(
            worktreeID: "worktree-1",
            path: "Sources/WorkspaceManager.swift"
        )
        let unattributed = try await store.fileExplanation(
            worktreeID: "worktree-1",
            path: "Sources/Unknown.swift"
        )

        #expect(events.map(\.id) == ["event-1", "event-unattributed"])
        #expect(attributed?.workItem?.title == "Explain dirty files")
        #expect(attributed?.contribution?.declaredIntent == "Capture work provenance")
        #expect(attributed?.session?.agentKind == "codex")
        #expect(attributed?.checkpoint?.diffFingerprint == "diff-1")
        #expect(attributed?.fileChange.attributionSource == .observed)
        #expect(unattributed?.fileChange.attributionSource == .unattributed)
        #expect(unattributed?.fileChange.attributionConfidence == .low)
        #expect(unattributed?.contribution == nil)
    }

    @Test
    func pruningExpiresObservedEventsButPreservesSemanticEventsAndLatestExplanation() async throws {
        let fixture = try StoreFixture()
        defer { fixture.remove() }
        let policy = WorkProvenanceRetentionPolicy(
            observedEventMaximumAge: 10,
            minimumObservedEventsPerWorktree: 2,
            pruneAfterAppendedEvents: 1000
        )
        let store = try WorkProvenanceStore(databaseURL: fixture.databaseURL, retentionPolicy: policy)

        try await store.append(Self.semanticEvent(id: "semantic-old", timestamp: 100))
        try await store.append(Self.observedEvent(id: "observed-1", timestamp: 100, fingerprint: "diff-1"))
        try await store.append(Self.observedEvent(id: "observed-2", timestamp: 110, fingerprint: "diff-2"))
        try await store.append(Self.observedEvent(id: "observed-3", timestamp: 120, fingerprint: "diff-3"))
        try await store.append(Self.observedEvent(id: "observed-4", timestamp: 130, fingerprint: "diff-4"))
        try await store.append(Self.observedEvent(id: "observed-5", timestamp: 140, fingerprint: "diff-5"))

        let result = try await store.pruneExpiredObservedHistory(now: Date(timeIntervalSince1970: 200))
        try await store.rebuildProjections()

        let events = try await store.events()
        let explanation = try await store.fileExplanation(
            worktreeID: "worktree-1",
            path: "Sources/WorkspaceManager.swift"
        )

        #expect(result.eventsDeleted == 3)
        #expect(result.fileChangesDeleted == 0)
        #expect(result.changeSetsDeleted == 4)
        #expect(events.map(\.id) == ["semantic-old", "observed-4", "observed-5"])
        #expect(explanation?.changeSet?.diffFingerprint == "diff-5")
        #expect(explanation?.fileChange.attributionSource == .unattributed)
        #expect(explanation?.fileChange.attributionConfidence == .low)
    }

    @Test
    func appendAutomaticallyPrunesAfterConfiguredEventCount() async throws {
        let fixture = try StoreFixture()
        defer { fixture.remove() }
        let policy = WorkProvenanceRetentionPolicy(
            observedEventMaximumAge: 5,
            minimumObservedEventsPerWorktree: 1,
            pruneAfterAppendedEvents: 2
        )
        let store = try WorkProvenanceStore(databaseURL: fixture.databaseURL, retentionPolicy: policy)

        try await store.append(Self.observedEvent(id: "observed-1", timestamp: 100, fingerprint: "diff-1"))
        try await store.append(Self.observedEvent(id: "observed-2", timestamp: 110, fingerprint: "diff-2"))

        let events = try await store.events()

        #expect(events.map(\.id) == ["observed-2"])
    }

    private static func attributedEvent() -> WorkProvenanceEvent {
        let now = Date(timeIntervalSince1970: 100)
        let repository = WorkProvenanceRepositoryRecord(
            id: "repo-1", path: "/repo", commonDirectory: "/repo/.git",
            remoteSlug: "manaflow-ai/bmux", createdAt: now, updatedAt: now
        )
        let worktree = WorkProvenanceWorktreeRecord(
            id: "worktree-1", repositoryID: "repo-1", path: "/repo",
            branch: "feature/provenance", baseCommit: "base", currentHEAD: "head",
            isDirty: true, status: "active", lastReconciledAt: now, updatedAt: now
        )
        let session = WorkProvenanceSessionRecord(
            id: "session-1", agentKind: "codex", workspaceID: "workspace-1",
            surfaceID: "surface-1", worktreeID: "worktree-1", cwd: "/repo",
            status: "active", startedAt: now, updatedAt: now
        )
        let workItem = WorkProvenanceWorkItemRecord(
            id: "WI-1", title: "Explain dirty files", status: "active",
            createdAt: now, updatedAt: now
        )
        let contribution = WorkProvenanceContributionRecord(
            id: "contribution-1", sessionID: "session-1", worktreeID: "worktree-1",
            workItemID: "WI-1", declaredIntent: "Capture work provenance",
            expectedScope: ["Sources/WorkspaceManager.swift"], status: "active",
            startedAt: now, assignmentConfidence: .high, updatedAt: now
        )
        return Self.attributedEvent(
            now: now,
            repository: repository,
            worktree: worktree,
            session: session,
            workItem: workItem,
            contribution: contribution
        )
    }

    private static func attributedEvent(
        now: Date,
        repository: WorkProvenanceRepositoryRecord,
        worktree: WorkProvenanceWorktreeRecord,
        session: WorkProvenanceSessionRecord,
        workItem: WorkProvenanceWorkItemRecord,
        contribution: WorkProvenanceContributionRecord
    ) -> WorkProvenanceEvent {
        let checkpoint = WorkProvenanceCheckpointRecord(
            id: "checkpoint-1", contributionID: "contribution-1", sequence: 1,
            gitHEAD: "head", diffFingerprint: "diff-1", summary: "Recorded first batch",
            status: "in_progress", validationState: "not_run",
            semanticConfidence: .medium, freshness: "fresh", createdAt: now
        )
        let changeSet = WorkProvenanceChangeSetRecord(
            id: "changeset-1", checkpointID: "checkpoint-1",
            contributionID: "contribution-1", worktreeID: "worktree-1",
            summary: "Workspace provenance", diffFingerprint: "diff-1", createdAt: now
        )
        let fileChange = WorkProvenanceFileChangeRecord(
            id: "file-1", changeSetID: "changeset-1", repositoryID: "repo-1",
            worktreeID: "worktree-1", path: "Sources/WorkspaceManager.swift",
            status: "modified", beforeHash: "before", afterHash: "after",
            attributionSource: .observed, attributionConfidence: .high, updatedAt: now
        )
        return WorkProvenanceEvent(
            id: "event-1", eventType: .progressCheckpoint, timestamp: now,
            repositoryID: "repo-1", worktreeID: "worktree-1", sessionID: "session-1",
            contributionID: "contribution-1", source: .observed, confidence: .high,
            payload: WorkProvenanceEventPayload(
                repository: repository, worktree: worktree, session: session,
                workItem: workItem, contribution: contribution, checkpoint: checkpoint,
                changeSet: changeSet, fileChanges: [fileChange]
            )
        )
    }

    private static func unattributedEvent() -> WorkProvenanceEvent {
        let now = Date(timeIntervalSince1970: 200)
        let repository = WorkProvenanceRepositoryRecord(
            id: "repo-1", path: "/repo", createdAt: now, updatedAt: now
        )
        let worktree = WorkProvenanceWorktreeRecord(
            id: "worktree-1", repositoryID: "repo-1", path: "/repo",
            isDirty: true, status: "active", updatedAt: now
        )
        let changeSet = WorkProvenanceChangeSetRecord(
            id: "changeset-unattributed", worktreeID: "worktree-1",
            summary: "Unattributed file write",
            diffFingerprint: "diff-unattributed", createdAt: now
        )
        let fileChange = WorkProvenanceFileChangeRecord(
            id: "file-unattributed", changeSetID: "changeset-unattributed",
            repositoryID: "repo-1", worktreeID: "worktree-1",
            path: "Sources/Unknown.swift", status: "modified",
            attributionSource: .unattributed, attributionConfidence: .low,
            updatedAt: now
        )
        return WorkProvenanceEvent(
            id: "event-unattributed", eventType: .worktreeObserved,
            timestamp: now, repositoryID: "repo-1", worktreeID: "worktree-1",
            source: .observed, confidence: .low,
            payload: WorkProvenanceEventPayload(
                repository: repository, worktree: worktree,
                changeSet: changeSet, fileChanges: [fileChange]
            )
        )
    }

    private static func semanticEvent(id: String, timestamp: TimeInterval) -> WorkProvenanceEvent {
        WorkProvenanceEvent(
            id: id,
            eventType: .progressCheckpoint,
            timestamp: Date(timeIntervalSince1970: timestamp),
            repositoryID: "repo-1",
            worktreeID: "worktree-1",
            source: .declared,
            confidence: .medium
        )
    }

    private static func observedEvent(
        id: String,
        timestamp: TimeInterval,
        fingerprint: String
    ) -> WorkProvenanceEvent {
        let now = Date(timeIntervalSince1970: timestamp)
        let repository = WorkProvenanceRepositoryRecord(
            id: "repo-1", path: "/repo", createdAt: now, updatedAt: now
        )
        let worktree = WorkProvenanceWorktreeRecord(
            id: "worktree-1", repositoryID: "repo-1", path: "/repo",
            isDirty: true, status: "active", updatedAt: now
        )
        let changeSet = WorkProvenanceChangeSetRecord(
            id: "changeset-\(fingerprint)", worktreeID: "worktree-1",
            summary: "Observed dirty worktree",
            diffFingerprint: fingerprint,
            createdAt: now
        )
        let fileChange = WorkProvenanceFileChangeRecord(
            id: "file-workspace-manager", changeSetID: changeSet.id,
            repositoryID: "repo-1", worktreeID: "worktree-1",
            path: "Sources/WorkspaceManager.swift", status: "modified",
            attributionSource: .unattributed, attributionConfidence: .low,
            updatedAt: now
        )
        return WorkProvenanceEvent(
            id: id,
            eventType: .worktreeObserved,
            timestamp: now,
            repositoryID: "repo-1",
            worktreeID: "worktree-1",
            source: .observed,
            confidence: .medium,
            payload: WorkProvenanceEventPayload(
                repository: repository,
                worktree: worktree,
                changeSet: changeSet,
                fileChanges: [fileChange]
            )
        )
    }

    private struct StoreFixture {
        let directoryURL: URL
        let databaseURL: URL

        init() throws {
            directoryURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("bmux-work-provenance-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true
            )
            databaseURL = directoryURL.appendingPathComponent("provenance.sqlite")
        }

        func remove() {
            try? FileManager.default.removeItem(at: directoryURL)
        }
    }
}
