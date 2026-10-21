import Foundation
import ProvenanceEngineContracts

/// Reconciles persisted close snapshots with PE's durable Explorer archive.
actor WorkspaceExplorerArchiveRecoveryService {
    typealias SavedCandidates = @MainActor @Sendable () async -> [WorkspaceArchiveRecoveryCandidate]
    typealias WaitForWrites = @MainActor @Sendable () async -> Void
    typealias LiveWorkspaceIDs = @MainActor @Sendable () -> Set<UUID>

    private let archiveService: WorkProvenanceWorkspaceArchiveService
    private let savedCandidates: SavedCandidates
    private let waitForWrites: WaitForWrites
    private let liveWorkspaceIDs: LiveWorkspaceIDs

    init(archiveService: WorkProvenanceWorkspaceArchiveService,
         savedCandidates: @escaping SavedCandidates,
         waitForWrites: @escaping WaitForWrites,
         liveWorkspaceIDs: @escaping LiveWorkspaceIDs) {
        self.archiveService = archiveService
        self.savedCandidates = savedCandidates
        self.waitForWrites = waitForWrites
        self.liveWorkspaceIDs = liveWorkspaceIDs
    }

    func recover() async throws -> [ProvenanceArchivedWorkspaceRecord] {
        let candidates = await savedCandidates()
        await waitForWrites()
        let liveIDs = await liveWorkspaceIDs()
        let eligible = candidates.filter { !liveIDs.contains($0.stableID) }
        let existing = try await archiveService.archivedWorkspaces()
        guard try await archiveService.recoverClosures(eligible, existing: existing) else {
            return existing
        }
        return try await archiveService.archivedWorkspaces()
    }
}
