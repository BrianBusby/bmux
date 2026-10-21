import Foundation

/// Reconciles persisted close snapshots with PE's durable Explorer archive.
@MainActor
final class WorkspaceExplorerArchiveRecoveryService {
    typealias SavedRecords = @MainActor () async -> [ClosedItemHistoryRecord]
    typealias WaitForWrites = @MainActor () async -> Void
    typealias LiveWorkspaceIDs = @MainActor () -> Set<UUID>

    private let archiveService: WorkProvenanceWorkspaceArchiveService?
    private let savedRecords: SavedRecords
    private let waitForWrites: WaitForWrites
    private let liveWorkspaceIDs: LiveWorkspaceIDs

    init(archiveService: WorkProvenanceWorkspaceArchiveService?,
         savedRecords: @escaping SavedRecords,
         waitForWrites: @escaping WaitForWrites,
         liveWorkspaceIDs: @escaping LiveWorkspaceIDs) {
        self.archiveService = archiveService
        self.savedRecords = savedRecords
        self.waitForWrites = waitForWrites
        self.liveWorkspaceIDs = liveWorkspaceIDs
    }

    func recover() async throws {
        guard let archiveService else { return }
        let records = await savedRecords()
        await waitForWrites()
        let candidates = WorkspaceArchiveRecoveryCandidate.from(
            records: records, excluding: liveWorkspaceIDs())
        try await archiveService.recoverClosures(candidates)
    }
}
