import Foundation
import ProvenanceEngineContracts

@MainActor
extension AppDelegate {
    func workspaceExplorerTabManagers() -> [TabManager] {
        mainWindowContexts.values.map(\.tabManager)
            + recoverableMainWindowRoutes().compactMap(\.tabManager)
            + [tabManager].compactMap { $0 }
    }

    private func workspaceExplorerHistoryService() -> WorkspaceExplorerHistoryService {
        let archiveService = workProvenanceRuntime?.workspaceArchiveService
        let recovery = WorkspaceExplorerArchiveRecoveryService(
            archiveService: archiveService,
            savedRecords: { await ClosedItemHistoryStore.shared.recordsAfterPersistedLoad() },
            waitForWrites: { await self.workProvenanceRuntime?.waitForArchiveTasks() },
            liveWorkspaceIDs: { Set(self.workspaceExplorerTabManagers().flatMap(\.tabs).map(\.stableId)) })
        return WorkspaceExplorerHistoryService(
            archiveService: archiveService,
            recoverArchive: { try await recovery.recover() },
            tabManagers: { self.workspaceExplorerTabManagers() },
            activeWorkspaceID: { self.tabManager?.selectedWorkspace?.stableId.uuidString },
            restoreRecords: { ClosedItemHistoryStore.shared.workspaceRestoreRecordsByStableID() },
            reopenEligibility: { stableID, liveIDs, candidate in
                self.workspaceExplorerReopenEligibility(
                    stableID: stableID, liveIDs: liveIDs, candidate: candidate)
            }
        )
    }

    func loadWorkspaceExplorerHistory() async throws -> WorkspaceExplorerHistoryLoadResult {
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
