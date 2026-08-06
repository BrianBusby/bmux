import BmuxPanes
import BmuxNotifications
import BmuxSettings
import BmuxWorkspaces
import Foundation

enum WorkspaceRelativeCloseScope: Equatable {
    case others(keeping: Set<UUID>)
    case above(anchor: UUID)
    case below(anchor: UUID)
}

enum WorkspaceSurfaceFocusActionResult: Equatable {
    case focused(workspaceId: UUID, surfaceId: UUID)
    case workspaceNotFound
    case surfaceNotFound
}

extension TabManager {
    func moveWorkspaceForAction(tabId: UUID, by delta: Int) -> Int? {
        guard let currentIndex = tabs.firstIndex(where: { $0.id == tabId }) else {
            return nil
        }
        let targetIndex = min(max(currentIndex + delta, 0), tabs.count - 1)
        _ = reorderWorkspace(tabId: tabId, toIndex: targetIndex)
        return tabs.firstIndex(where: { $0.id == tabId })
    }

    func moveWorkspaceToTopForAction(tabId: UUID) -> Int? {
        guard tabs.contains(where: { $0.id == tabId }) else {
            return nil
        }
        moveTabToTop(tabId)
        return tabs.firstIndex(where: { $0.id == tabId })
    }

    @discardableResult
    func setWorkspaceDescriptionForAction(tabId: UUID, description: String) -> String? {
        guard let index = tabs.firstIndex(where: { $0.id == tabId }) else {
            return nil
        }
        tabs[index].setCustomDescription(description)
        return tabs[index].customDescription
    }

    @discardableResult
    func clearWorkspaceDescriptionForAction(tabId: UUID) -> Bool {
        guard tabs.contains(where: { $0.id == tabId }) else {
            return false
        }
        clearCustomDescription(tabId: tabId)
        return true
    }

    func workspaceActionColorNames() -> [String] {
        WorkspaceTabColorSettings.palette().map(\.name)
    }

    @discardableResult
    func setWorkspaceColorForAction(tabId: UUID, colorInput: String) -> String? {
        guard tabs.contains(where: { $0.id == tabId }) else {
            return nil
        }
        guard let color = WorkspaceTabColorSettings.resolvedColorHex(colorInput) else {
            return nil
        }
        setTabColor(tabId: tabId, color: color)
        return color
    }

    @discardableResult
    func clearWorkspaceColorForAction(tabId: UUID) -> Bool {
        guard tabs.contains(where: { $0.id == tabId }) else {
            return false
        }
        setTabColor(tabId: tabId, color: nil)
        return true
    }

    @discardableResult
    func setWorkspacePinnedForAction(tabId: UUID, pinned: Bool) -> Bool {
        guard tabs.contains(where: { $0.id == tabId }) else {
            return false
        }
        _ = setWorkspacesPinnedForAction(workspaceIds: [tabId], pinned: pinned)
        return true
    }

    @discardableResult
    func setWorkspacesPinnedForAction(workspaceIds: [UUID], pinned: Bool) -> [UUID] {
        let liveWorkspaceIds = Set(tabs.map(\.id))
        var seen = Set<UUID>()
        let targetWorkspaceIds = workspaceIds.filter { workspaceId in
            guard liveWorkspaceIds.contains(workspaceId), !seen.contains(workspaceId) else {
                return false
            }
            seen.insert(workspaceId)
            return true
        }

        guard !targetWorkspaceIds.isEmpty else { return [] }
        return workspaceReordering.setPinned(workspaceIds: targetWorkspaceIds, pinned: pinned)
    }

    func workspaceIdsForRelativeClose(
        _ scope: WorkspaceRelativeCloseScope,
        allowPinned: Bool
    ) -> [UUID] {
        workspacesForRelativeClose(scope, allowPinned: allowPinned).map(\.id)
    }

    func closeWorkspacesWithConfirmation(
        _ scope: WorkspaceRelativeCloseScope,
        allowPinned: Bool
    ) {
        closeWorkspacesWithConfirmation(
            workspaceIdsForRelativeClose(scope, allowPinned: allowPinned),
            allowPinned: allowPinned
        )
    }

    @discardableResult
    func closeWorkspacesForAction(_ scope: WorkspaceRelativeCloseScope) -> Int {
        var closed = 0
        for workspace in workspacesForRelativeClose(scope, allowPinned: false) {
            guard tabs.contains(where: { $0.id == workspace.id }) else { continue }
            closeWorkspace(workspace)
            if !tabs.contains(where: { $0.id == workspace.id }) {
                closed += 1
            }
        }
        return closed
    }

    @discardableResult
    func selectWorkspaceIdForAction(
        _ workspaceId: UUID,
        notificationDismissalContext: NotificationDismissalContext? = .explicitWorkspaceResume
    ) -> Bool {
        guard tabs.contains(where: { $0.id == workspaceId }) else {
            return false
        }
#if DEBUG
        debugPrimeWorkspaceSwitchTrigger("select", to: workspaceId)
#endif
        selectWorkspaceId(workspaceId, notificationDismissalContext: notificationDismissalContext)
        return true
    }

    @discardableResult
    func focusWorkspaceSurfaceForAction(
        workspaceId: UUID,
        surfaceId: UUID,
        focusIntent: PanelFocusIntent? = nil
    ) -> WorkspaceSurfaceFocusActionResult {
        guard let workspace = tabs.first(where: { $0.id == workspaceId }) else {
            return .workspaceNotFound
        }
        guard workspace.panels[surfaceId] != nil else {
            return .surfaceNotFound
        }
        if selectedTabId != workspace.id {
            selectWorkspaceIdForAction(workspace.id)
        }
        workspace.focusPanel(surfaceId, focusIntent: focusIntent)
        return .focused(workspaceId: workspace.id, surfaceId: surfaceId)
    }

    private func workspacesForRelativeClose(
        _ scope: WorkspaceRelativeCloseScope,
        allowPinned: Bool
    ) -> [Workspace] {
        let workspaceIds: [UUID]
        switch scope {
        case .others(let keeping):
            workspaceIds = tabs.compactMap { keeping.contains($0.id) ? nil : $0.id }
        case .above(let anchor):
            guard let anchorIndex = tabs.firstIndex(where: { $0.id == anchor }) else {
                return []
            }
            workspaceIds = tabs.prefix(upTo: anchorIndex).map(\.id)
        case .below(let anchor):
            guard let anchorIndex = tabs.firstIndex(where: { $0.id == anchor }),
                  anchorIndex + 1 < tabs.count else {
                return []
            }
            workspaceIds = tabs.suffix(from: anchorIndex + 1).map(\.id)
        }
        return orderedClosableWorkspaces(workspaceIds, allowPinned: allowPinned)
    }
}
