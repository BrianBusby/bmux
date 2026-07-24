import Foundation
import ProvenanceEngineContracts

/// Observe-only service that records Git worktree state into the provenance store.
actor WorkProvenanceObservationService {
    private let store: WorkProvenanceStore
    private let gitInspector: any WorkProvenanceGitInspecting
    private let stableIDFactory: WorkProvenanceStableIDFactory
    private let dateProvider: @Sendable () -> Date
    private var latestFingerprintByWorkspaceID: [UUID: String] = [:]

    /// Last persistence or Git-observation error, retained for diagnostics.
    private(set) var lastErrorDescription: String?

    /// Creates an observe-only provenance service.
    init(
        store: WorkProvenanceStore,
        gitInspector: any WorkProvenanceGitInspecting,
        stableIDFactory: WorkProvenanceStableIDFactory = WorkProvenanceStableIDFactory(),
        dateProvider: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.store = store
        self.gitInspector = gitInspector
        self.stableIDFactory = stableIDFactory
        self.dateProvider = dateProvider
    }

    /// Observes each workspace snapshot and appends events when Git state changed.
    func observeWorkspaceSnapshots(_ snapshots: [WorkProvenanceWorkspaceSnapshot]) async {
        for snapshot in snapshots {
            await observeWorkspaceSnapshot(snapshot)
        }
    }

    /// Runs a retention pass for stale observed history.
    func pruneExpiredObservedHistory(now: Date = Date()) async {
        do {
            _ = try await store.pruneExpiredObservedHistory(now: now)
            lastErrorDescription = nil
        } catch {
            lastErrorDescription = String(describing: error)
        }
    }

    /// Observes one workspace snapshot and appends an event when Git state changed.
    func observeWorkspaceSnapshot(_ snapshot: WorkProvenanceWorkspaceSnapshot) async {
        do {
            try await appendObservationIfChanged(for: snapshot)
            lastErrorDescription = nil
        } catch {
            lastErrorDescription = String(describing: error)
        }
    }

    private func appendObservationIfChanged(for workspace: WorkProvenanceWorkspaceSnapshot) async throws {
        let directory = workspace.currentDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !directory.isEmpty,
              let gitSnapshot = await gitInspector.snapshot(for: directory) else {
            return
        }

        let fingerprint = stableIDFactory.fingerprint(for: gitSnapshot)
        guard latestFingerprintByWorkspaceID[workspace.workspaceID] != fingerprint else {
            return
        }
        latestFingerprintByWorkspaceID[workspace.workspaceID] = fingerprint

        let now = dateProvider()
        let repositoryID = stableIDFactory.repositoryID(repositoryRoot: gitSnapshot.repositoryRoot)
        let worktreeID = stableIDFactory.worktreeID(repositoryRoot: gitSnapshot.repositoryRoot)
        let changeSetID = stableIDFactory.changeSetID(worktreeID: worktreeID, fingerprint: fingerprint)

        let repository = ProvenanceRepositoryRecord(
            id: repositoryID,
            path: gitSnapshot.repositoryRoot,
            commonDirectory: gitSnapshot.commonDirectory,
            remoteSlug: gitSnapshot.remoteSlug,
            createdAt: now,
            updatedAt: now
        )
        let worktree = ProvenanceWorktreeRecord(
            id: worktreeID,
            repositoryID: repositoryID,
            path: gitSnapshot.repositoryRoot,
            branch: gitSnapshot.branch,
            currentHEAD: gitSnapshot.headCommit,
            isDirty: gitSnapshot.isDirty,
            status: "active",
            lastReconciledAt: now,
            updatedAt: now
        )
        let changeSet = WorkProvenanceChangeSetRecord(
            id: changeSetID,
            worktreeID: worktreeID,
            summary: Self.summary(fileCount: gitSnapshot.statusEntries.count, isDirty: gitSnapshot.isDirty),
            diffFingerprint: fingerprint,
            createdAt: now
        )
        let fileChanges = gitSnapshot.statusEntries.map { entry in
            WorkProvenanceFileChangeRecord(
                id: stableIDFactory.fileChangeID(worktreeID: worktreeID, path: entry.path),
                changeSetID: changeSetID,
                repositoryID: repositoryID,
                worktreeID: worktreeID,
                path: entry.path,
                status: entry.status,
                attributionSource: .unattributed,
                attributionConfidence: .low,
                updatedAt: now
            )
        }
        let event = WorkProvenanceEvent(
            eventType: .worktreeObserved,
            timestamp: now,
            repositoryID: repositoryID,
            worktreeID: worktreeID,
            source: .observed,
            confidence: gitSnapshot.statusEntries.isEmpty ? .high : .medium,
            payload: WorkProvenanceEventPayload(
                repository: repository,
                worktree: worktree,
                changeSet: changeSet,
                fileChanges: fileChanges
            )
        )

        try await store.append(event)
    }

    private static func summary(fileCount: Int, isDirty: Bool) -> String {
        guard isDirty else { return "Observed clean worktree" }
        if fileCount == 1 { return "Observed 1 dirty file" }
        return "Observed \(fileCount) dirty files"
    }
}
