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
        let recoverArchive: WorkspaceExplorerHistoryService.RecoverArchive?
        if let archiveService {
            let recovery = WorkspaceExplorerArchiveRecoveryService(
                archiveService: archiveService,
                savedCandidates: {
                    let saved = WorkspaceArchiveRecoveryCandidate.from(
                        records: await ClosedItemHistoryStore.shared.recordsAfterPersistedLoad(),
                        excluding: [])
                    let journal = try await self.workProvenanceRuntime?.workspaceCloseJournal?.candidates() ?? []
                    return WorkspaceArchiveRecoveryCandidate.latest(saved + journal)
                },
                waitForWrites: { await self.workProvenanceRuntime?.waitForArchiveTasks() },
                liveWorkspaceIDs: { Set(self.workspaceExplorerTabManagers().flatMap(\.tabs).map(\.stableId)) })
            recoverArchive = { try await recovery.recover() }
        } else {
            recoverArchive = nil
        }
        return WorkspaceExplorerHistoryService(
            archiveService: archiveService,
            recoverArchive: recoverArchive,
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
        let clearedAt = Date()
        try await workspaceExplorerHistoryService().clearHistory(at: clearedAt)
        try await workProvenanceRuntime?.workspaceCloseJournal?.clear(through: clearedAt)
    }

    func workspaceExplorerLiveWorkspaces() -> [Workspace] {
        workspaceExplorerHistoryService().liveWorkspaces()
    }
}
