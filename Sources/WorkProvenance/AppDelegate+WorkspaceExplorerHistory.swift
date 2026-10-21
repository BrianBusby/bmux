import Foundation
import ProvenanceEngineContracts

@MainActor
extension AppDelegate {
    private func workspaceExplorerHistoryService() -> WorkspaceExplorerHistoryService {
        WorkspaceExplorerHistoryService(
            archiveService: workProvenanceRuntime?.workspaceArchiveService,
            tabManagers: {
                self.mainWindowContexts.values.map(\.tabManager)
                    + self.recoverableMainWindowRoutes().compactMap(\.tabManager)
                    + [self.tabManager].compactMap { $0 }
            },
            activeWorkspaceID: { self.tabManager?.selectedWorkspace?.stableId.uuidString },
            restoreRecords: { ClosedItemHistoryStore.shared.workspaceRestoreRecordsByStableID() },
            reopenEligibility: { stableID, liveIDs, candidate in
                self.workspaceExplorerReopenEligibility(
                    stableID: stableID, liveIDs: liveIDs, candidate: candidate)
            }
        )
    }

    func loadWorkspaceExplorerHistory() async throws -> WorkspaceExplorerHistoryLoadResult {
        if let archiveService = workProvenanceRuntime?.workspaceArchiveService {
            let savedRecords = await ClosedItemHistoryStore.shared.recordsAfterPersistedLoad()
            await workProvenanceRuntime?.waitForArchiveTasks()
            let liveIDs = Set(workspaceExplorerLiveWorkspaces().map(\.stableId))
            let candidates = WorkspaceArchiveRecoveryCandidate.from(
                records: savedRecords, excluding: liveIDs)
            try await archiveService.recoverClosures(candidates)
        }
        return try await workspaceExplorerHistoryService().load()
    }

    func workspaceExplorerPresence() -> WorkspaceExplorerHistoryLoadResult {
        workspaceExplorerHistoryService().presenceSnapshot()
    }

    func workspaceExplorerSessions(stableID: UUID, limit: Int = 50, cursor: String? = nil) async throws
        -> ProvenanceWorkspaceSessionPageResponse {
        try await workspaceExplorerHistoryService().sessions(stableID: stableID, limit: limit, cursor: cursor)
    }

    func workspaceExplorerSessionEvidence(sessionID: String) async throws -> (
        ProvenanceFactualSessionProjectionResponse, ProvenanceSessionOutcomeResponse
    ) {
        try await workspaceExplorerHistoryService().evidence(sessionID: sessionID)
    }

    func clearWorkspaceExplorerHistory() async throws {
        try await workspaceExplorerHistoryService().clearHistory()
    }

    func workspaceExplorerLiveWorkspaces() -> [Workspace] {
        workspaceExplorerHistoryService().liveWorkspaces()
    }
}
