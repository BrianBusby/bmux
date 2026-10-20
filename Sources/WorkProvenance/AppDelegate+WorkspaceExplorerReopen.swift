import Foundation

@MainActor
extension AppDelegate {
    func workspaceExplorerReopenEligibility(stableID: UUID) -> WorkspaceExplorerReopenEligibility {
        workspaceExplorerReopenEligibility(
            stableID: stableID,
            liveIDs: Set(workspaceExplorerLiveWorkspaces().map(\.stableId)),
            candidate: ClosedItemHistoryStore.shared.workspaceRestoreRecord(stableId: stableID)
        )
    }

    func workspaceExplorerReopenEligibility(
        stableID: UUID,
        liveIDs: Set<UUID>,
        candidate: ClosedItemHistoryRecord?
    ) -> WorkspaceExplorerReopenEligibility {
        if liveIDs.contains(stableID) {
            return .unavailable(.alreadyOpen)
        }
        let store = ClosedItemHistoryStore.shared
        if candidate == nil && !store.hasLoadedPersistedRecords {
            return .unavailable(.historyLoading)
        }
        guard let record = candidate,
              case .workspace(let entry) = record.entry else {
            return .unavailable(.noRestoreSnapshot)
        }
        guard entry.snapshot.hasRestorablePanels else { return .unavailable(.noRestorablePanels) }
        guard entry.snapshot.remote == nil else { return .unavailable(.unsupportedRemoteRestore) }
        guard !entry.snapshot.currentDirectory.isEmpty else {
            return .unavailable(.noDirectoryRecorded)
        }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: entry.snapshot.currentDirectory, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return .unavailable(.directoryRemoved)
        }
        return .eligible(recordID: record.id)
    }

    @discardableResult
    func reopenWorkspaceExplorerHistory(stableID: UUID, preferredTabManager: TabManager? = nil) -> Bool {
        guard case .eligible(let recordID) = workspaceExplorerReopenEligibility(stableID: stableID) else {
            return false
        }
        return reopenClosedHistoryItem(
            id: recordID,
            preferredTabManager: preferredTabManager,
            allowsAgentResume: false
        )
    }

}

extension ClosedWorkspaceHistoryEntry {
    /// Explorer reopens the workspace shell and layout without launching a
    /// persisted agent command, surface resume binding, or tmux command.
    var withoutAgentResume: ClosedWorkspaceHistoryEntry {
        var safeSnapshot = snapshot
        for index in safeSnapshot.panels.indices {
            guard var terminal = safeSnapshot.panels[index].terminal else { continue }
            terminal.agent = nil
            terminal.hibernation = nil
            terminal.resumeBinding = nil
            terminal.tmuxStartCommand = nil
            terminal.remotePTYSessionID = nil
            terminal.wasAgentRunning = false
            safeSnapshot.panels[index].terminal = terminal
        }
        return ClosedWorkspaceHistoryEntry(
            workspaceId: workspaceId,
            windowId: windowId,
            workspaceIndex: workspaceIndex,
            snapshot: safeSnapshot
        )
    }
}
