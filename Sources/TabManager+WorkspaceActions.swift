import AppKit
import BmuxPanes
import BmuxNotifications
import BmuxSettings
import BmuxWorkspaces
import Bonsplit
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

enum WorkspaceCloseActionResult: Equatable {
    case accepted
    case notFound
    case protected
}

enum WorkspaceReorderActionTarget: Equatable {
    case index(Int)
    case before(UUID)
    case after(UUID)
    case end
}

enum WorkspaceReorderActionResult: Equatable {
    case resolved(WorkspaceReorderPlanItem)
    case notFound
}

extension Workspace {
    @discardableResult
    func requestPanelFocusForAction(
        panelId: UUID,
        in window: NSWindow?
    ) -> WorkspaceSurfaceFocusActionResult {
        guard let manager = owningTabManager ?? AppDelegate.shared?.tabManagerFor(tabId: id) else {
            return panels[panelId] == nil ? .surfaceNotFound : .workspaceNotFound
        }
        let result = manager.focusWorkspaceSurfaceForAction(workspaceId: id, surfaceId: panelId)
        if case .focused = result {
            AppDelegate.shared?.noteMainPanelKeyboardFocusIntent(
                workspaceId: id,
                panelId: panelId,
                in: window
            )
        }
        return result
    }
}

extension TabManager {
    @discardableResult
    func createTerminalSplitForAction(direction: SplitDirection) -> TerminalPanelCreationOutcome {
        guard let selectedTabId,
              let tab = tabs.first(where: { $0.id == selectedTabId }),
              let focusedPanelId = tab.focusedPanelId else { return .failed }
        return createTerminalSplitForAction(tabId: selectedTabId, surfaceId: focusedPanelId, direction: direction)
    }

    @discardableResult
    func createTerminalSplitForAction(
        tabId: UUID,
        surfaceId: UUID,
        direction: SplitDirection,
        focus: Bool = true,
        workingDirectory: String? = nil,
        initialCommand: String? = nil,
        tmuxStartCommand: String? = nil,
        startupEnvironment: [String: String] = [:],
        initialDividerPosition: CGFloat? = nil,
        remotePTYSessionID: String? = nil,
        allowTextBoxFocusDefault: Bool = true
    ) -> TerminalPanelCreationOutcome {
        guard let tab = tabs.first(where: { $0.id == tabId }),
              tab.panels[surfaceId] != nil else { return .failed }
        tab.clearSplitZoom()
        sentryBreadcrumb("split.create", data: ["direction": String(describing: direction)])
        return tab.createTerminalSplitForAction(
            from: surfaceId,
            orientation: direction.orientation,
            insertFirst: direction.insertFirst,
            focus: focus,
            workingDirectory: workingDirectory,
            initialCommand: initialCommand,
            tmuxStartCommand: tmuxStartCommand,
            startupEnvironment: startupEnvironment,
            initialDividerPosition: initialDividerPosition,
            remotePTYSessionID: remotePTYSessionID,
            allowTextBoxFocusDefault: allowTextBoxFocusDefault
        )
    }

    @discardableResult
    func createWorkspaceForAction(
        title: String? = nil,
        workingDirectory: String? = nil,
        initialSurface: NewWorkspaceInitialSurface = .terminal,
        initialTerminalCommand: String? = nil,
        initialTerminalInput: String? = nil,
        initialTerminalEnvironment: [String: String] = [:],
        initialBrowserURL: URL? = nil,
        initialBrowserOmnibarVisible: Bool = true,
        initialBrowserTransparentBackground: Bool = false,
        workspaceEnvironment: [String: String] = [:],
        inheritWorkingDirectory: Bool = true,
        select: Bool = true,
        eagerLoadTerminal: Bool = false,
        placementOverride: WorkspacePlacement? = nil,
        autoWelcomeIfNeeded: Bool = true,
        autoRefreshMetadata: Bool = true,
        normalizeWorkspaceGroupsAfterInsert: Bool = true,
        allowTextBoxFocusDefault: Bool = true
    ) -> Workspace {
        addWorkspace(
            title: title,
            workingDirectory: workingDirectory,
            initialSurface: initialSurface,
            initialTerminalCommand: initialTerminalCommand,
            initialTerminalInput: initialTerminalInput,
            initialTerminalEnvironment: initialTerminalEnvironment,
            initialBrowserURL: initialBrowserURL,
            initialBrowserOmnibarVisible: initialBrowserOmnibarVisible,
            initialBrowserTransparentBackground: initialBrowserTransparentBackground,
            workspaceEnvironment: workspaceEnvironment,
            inheritWorkingDirectory: inheritWorkingDirectory,
            select: select,
            eagerLoadTerminal: eagerLoadTerminal,
            placementOverride: placementOverride,
            autoWelcomeIfNeeded: autoWelcomeIfNeeded,
            autoRefreshMetadata: autoRefreshMetadata,
            normalizeWorkspaceGroupsAfterInsert: normalizeWorkspaceGroupsAfterInsert,
            allowTextBoxFocusDefault: allowTextBoxFocusDefault
        )
    }

    func reorderWorkspaceForAction(
        tabId: UUID,
        target: WorkspaceReorderActionTarget,
        dryRun: Bool = false
    ) -> WorkspaceReorderActionResult {
        let plan: WorkspaceReorderPlanItem?
        switch target {
        case .index(let index):
            plan = workspaceReorderPlan(tabId: tabId, toIndex: index)
        case .before(let beforeId):
            plan = workspaceReorderPlan(tabId: tabId, before: beforeId, after: nil)
        case .after(let afterId):
            plan = workspaceReorderPlan(tabId: tabId, before: nil, after: afterId)
        case .end:
            plan = workspaceReorderPlan(tabId: tabId, toIndex: tabs.endIndex)
        }
        guard let plan else {
            return .notFound
        }
        if !dryRun {
            _ = reorderWorkspace(tabId: tabId, toIndex: plan.toIndex)
        }
        return .resolved(plan)
    }

    func moveWorkspaceForAction(tabId: UUID, by delta: Int) -> Int? {
        guard let currentIndex = tabs.firstIndex(where: { $0.id == tabId }) else {
            return nil
        }
        let targetIndex = min(max(currentIndex + delta, 0), tabs.count - 1)
        switch reorderWorkspaceForAction(tabId: tabId, target: .index(targetIndex)) {
        case .resolved(let plan):
            return plan.toIndex
        case .notFound:
            return nil
        }
    }

    func moveWorkspaceToTopForAction(tabId: UUID) -> Int? {
        guard !moveWorkspacesToTopForAction(workspaceIds: [tabId]).isEmpty else {
            return nil
        }
        return tabs.firstIndex(where: { $0.id == tabId })
    }

    @discardableResult
    func moveWorkspacesToTopForAction(workspaceIds: [UUID]) -> [UUID] {
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
        moveTabsToTop(Set(targetWorkspaceIds))
        return targetWorkspaceIds
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
        guard let color = WorkspaceTabColorSettings.resolvedColorHex(colorInput) else {
            return nil
        }
        guard !setWorkspacesColorForAction(workspaceIds: [tabId], color: color).isEmpty else {
            return nil
        }
        return color
    }

    @discardableResult
    func clearWorkspaceColorForAction(tabId: UUID) -> Bool {
        !setWorkspacesColorForAction(workspaceIds: [tabId], color: nil).isEmpty
    }

    @discardableResult
    func setWorkspacesColorForAction(workspaceIds: [UUID], color: String?) -> [UUID] {
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
        applyWorkspaceColor(color, toWorkspaceIds: targetWorkspaceIds)
        return targetWorkspaceIds
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

    @discardableResult
    func setWorkspaceUnreadForAction(
        tabId: UUID,
        unread: Bool,
        notificationStore: TerminalNotificationStore?
    ) -> Bool {
        !setWorkspacesUnreadForAction(
            workspaceIds: [tabId],
            unread: unread,
            notificationStore: notificationStore
        ).isEmpty
    }

    @discardableResult
    func setWorkspacesUnreadForAction(
        workspaceIds: [UUID],
        unread: Bool,
        notificationStore: TerminalNotificationStore?
    ) -> [UUID] {
        guard let notificationStore else { return [] }
        let liveWorkspaceIds = Set(tabs.map(\.id))
        var seen = Set<UUID>()
        let targetWorkspaceIds = workspaceIds.filter { workspaceId in
            guard liveWorkspaceIds.contains(workspaceId), !seen.contains(workspaceId) else {
                return false
            }
            seen.insert(workspaceId)
            return unread
                ? notificationStore.canMarkWorkspaceUnread(forTabIds: [workspaceId])
                : notificationStore.canMarkWorkspaceRead(forTabIds: [workspaceId])
        }

        for workspaceId in targetWorkspaceIds {
            if unread {
                notificationStore.markUnread(forTabId: workspaceId)
            } else {
                notificationStore.markRead(forTabId: workspaceId)
            }
        }
        return targetWorkspaceIds
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
            guard closeWorkspaceForAction(tabId: workspace.id) == .accepted else { continue }
            if !tabs.contains(where: { $0.id == workspace.id }) {
                closed += 1
            }
        }
        return closed
    }

    @discardableResult
    func closeWorkspaceForAction(
        tabId: UUID,
        allowPinned: Bool = false,
        recordHistory: Bool = true
    ) -> WorkspaceCloseActionResult {
        guard let workspace = tabs.first(where: { $0.id == tabId }) else {
            return .notFound
        }
        guard tabs.count > 1 else {
            return .protected
        }
        guard canCloseWorkspace(workspace, allowPinned: allowPinned) else {
            return .protected
        }
        closeWorkspace(workspace, recordHistory: recordHistory)
        return .accepted
    }

    @discardableResult
    func closeWorkspaceAllowingPinnedForAction(tabId: UUID, recordHistory: Bool = true) -> WorkspaceCloseActionResult {
        closeWorkspaceForAction(tabId: tabId, allowPinned: true, recordHistory: recordHistory)
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
    func selectWorkspaceIndexForAction(
        _ index: Int,
        notificationDismissalContext: NotificationDismissalContext? = .explicitWorkspaceResume
    ) -> Bool {
        guard index >= 0 && index < tabs.count else {
            return false
        }
        let workspaceId = tabs[index].id
#if DEBUG
        debugPrimeWorkspaceSwitchTrigger("select_index", to: workspaceId)
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
        focusHistoryNavigation.recordFocusInHistory(
            workspaceId: workspace.id,
            panelId: surfaceId,
            preservingForwardBranch: false
        )
        return .focused(workspaceId: workspace.id, surfaceId: surfaceId)
    }

    @discardableResult
    func createBrowserSplitForAction(
        tabId: UUID,
        fromPanelId: UUID,
        orientation: SplitOrientation,
        insertFirst: Bool = false,
        url: URL? = nil,
        preferredProfileID: UUID? = nil,
        focus: Bool = true,
        initialDividerPosition: CGFloat? = nil
    ) -> UUID? {
        guard BrowserAvailabilitySettings.isEnabled() else { return nil }
        guard let workspace = tabs.first(where: { $0.id == tabId }) else { return nil }
        return workspace.createBrowserSplitForAction(
            from: fromPanelId,
            orientation: orientation,
            insertFirst: insertFirst,
            url: url,
            preferredProfileID: preferredProfileID,
            focus: focus,
            initialDividerPosition: initialDividerPosition
        )?.id
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
