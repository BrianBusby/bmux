import Combine
import Foundation

/// Resolves live workspaces across retained windows for display updates and retries.
extension WorkProvenanceRuntime {
    static func workspace(matching workspaceID: UUID, in tabManagers: [TabManager]) -> Workspace? {
        workspaceMatch(matching: workspaceID, in: tabManagers)?.workspace
    }

    static func workspaceMatch(
        matching workspaceID: UUID,
        in tabManagers: [TabManager]
    ) -> (tabManager: TabManager, workspace: Workspace)? {
        var seenManagers: Set<ObjectIdentifier> = []
        for tabManager in tabManagers where seenManagers.insert(ObjectIdentifier(tabManager)).inserted {
            if let workspace = tabManager.tabs.first(where: { workspace in
                workspace.id == workspaceID || workspace.stableId == workspaceID
            }) {
                return (tabManager, workspace)
            }
        }
        return nil
    }

    static func stableWorkspaceIDs(in tabManagers: [TabManager]) -> [UUID] {
        var seenWorkspaceIDs: Set<UUID> = []
        var ids: [UUID] = []
        for tabManager in tabManagers {
            for workspace in tabManager.tabs where seenWorkspaceIDs.insert(workspace.stableId).inserted {
                ids.append(workspace.stableId)
            }
        }
        return ids
    }

    static func workspacesNeedingEnrichmentRetry(in tabManagers: [TabManager], failedIDs: Set<UUID>) -> [Workspace] {
        failedIDs.compactMap { workspace(matching: $0, in: tabManagers) }
    }

    @discardableResult
    static func notifyWorkspaceDisplayCurrentStateDidChange(
        stableWorkspaceID: UUID,
        in tabManagers: [TabManager]
    ) -> Bool {
        guard let match = workspaceMatch(matching: stableWorkspaceID, in: tabManagers) else {
            return false
        }
        match.tabManager.objectWillChange.send()
        match.workspace.sidebarImmediateObservationChangeSubject.send(())
        NotificationCenter.default.post(name: workspaceDisplayCurrentStateDidChangeNotification,
            object: stableWorkspaceID)
        return true
    }

    static let workspaceDisplayCurrentStateDidChangeNotification =
        Notification.Name("bmux.workspaceDisplayCurrentStateDidChange")
}
