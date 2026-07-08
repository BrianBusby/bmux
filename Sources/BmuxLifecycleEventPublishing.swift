import Foundation
import AppKit
import Bonsplit

@MainActor
private enum BmuxSelectionEventState {
    static var selectedSurfaceByWorkspacePane: [String: UUID] = [:]
    static var focusedPaneByWorkspace: [UUID: UUID] = [:]
    static var focusedSurfaceByWorkspace: [UUID: UUID] = [:]

    static func paneKey(workspaceId: UUID, paneId: UUID) -> String {
        "\(workspaceId.uuidString):\(paneId.uuidString)"
    }

    static func clearWorkspace(_ workspaceId: UUID) {
        selectedSurfaceByWorkspacePane = selectedSurfaceByWorkspacePane.filter {
            !$0.key.hasPrefix("\(workspaceId.uuidString):")
        }
        focusedPaneByWorkspace.removeValue(forKey: workspaceId)
        focusedSurfaceByWorkspace.removeValue(forKey: workspaceId)
    }

    static func clearPane(workspaceId: UUID, paneId: UUID) {
        selectedSurfaceByWorkspacePane.removeValue(forKey: paneKey(workspaceId: workspaceId, paneId: paneId))
        if focusedPaneByWorkspace[workspaceId] == paneId {
            focusedPaneByWorkspace.removeValue(forKey: workspaceId)
        }
    }

    static func clearSurface(workspaceId: UUID, surfaceId: UUID) {
        selectedSurfaceByWorkspacePane = selectedSurfaceByWorkspacePane.filter { $0.value != surfaceId }
        if focusedSurfaceByWorkspace[workspaceId] == surfaceId {
            focusedSurfaceByWorkspace.removeValue(forKey: workspaceId)
        }
    }
}

extension TabManager {
    func publishBmuxWorkspaceCreated(_ workspace: Workspace, selected: Bool) {
        BmuxEventBus.shared.publishWorkspaceCreated(
            workspaceId: workspace.id,
            title: workspace.bmuxEventWorkspaceTitle,
            customTitle: workspace.customTitle,
            currentDirectory: workspace.currentDirectory,
            selected: selected,
            index: tabs.firstIndex(where: { $0.id == workspace.id }),
            tabCount: tabs.count
        )
    }

    func publishBmuxInitialSurfaceCreated(_ workspace: Workspace, selected: Bool) {
        guard let panelId = workspace.focusedSurfaceId,
              let panel = workspace.panels[panelId] else { return }
        workspace.publishBmuxSurfaceCreated(
            panelId,
            paneId: workspace.paneId(forPanelId: panelId),
            kind: Workspace.bmuxEventSurfaceKind(panel),
            origin: "workspace_initial",
            focused: selected
        )
    }

    func publishBmuxWorkspaceClosed(_ workspace: Workspace) {
        BmuxEventBus.shared.publishWorkspaceClosed(
            workspaceId: workspace.id,
            title: workspace.bmuxEventWorkspaceTitle,
            customTitle: workspace.customTitle,
            currentDirectory: workspace.currentDirectory,
            remainingTabCount: tabs.count
        )
        BmuxSelectionEventState.clearWorkspace(workspace.id)
    }

    func publishBmuxWorkspaceSelected(_ workspace: Workspace) {
        BmuxEventBus.shared.publishWorkspaceSelected(
            workspaceId: workspace.id,
            title: workspace.bmuxEventWorkspaceTitle,
            customTitle: workspace.customTitle,
            currentDirectory: workspace.currentDirectory,
            previousWorkspaceId: nil,
            index: tabs.firstIndex(where: { $0.id == workspace.id }),
            tabCount: tabs.count
        )
    }

    func publishBmuxWorkspaceSelectedChange(from previousWorkspaceId: UUID?) {
        guard let selectedTabId,
              let workspace = tabs.first(where: { $0.id == selectedTabId }) else { return }
        BmuxEventBus.shared.publishWorkspaceSelected(
            workspaceId: workspace.id,
            title: workspace.bmuxEventWorkspaceTitle,
            customTitle: workspace.customTitle,
            currentDirectory: workspace.currentDirectory,
            previousWorkspaceId: previousWorkspaceId,
            index: tabs.firstIndex(where: { $0.id == workspace.id }),
            tabCount: tabs.count
        )
    }
}

extension Workspace {
    var bmuxEventWorkspaceTitle: String {
        customTitle ?? title
    }

    func publishBmuxSplitCreated(
        _ paneId: PaneID,
        sourcePaneId: PaneID?,
        orientation: SplitOrientation,
        surfaceId: UUID?,
        kind: String,
        origin: String,
        focused: Bool
    ) {
        BmuxEventBus.shared.publishPaneCreated(
            workspaceId: id,
            paneId: paneId.id,
            sourcePaneId: sourcePaneId?.id,
            orientation: orientation.rawValue,
            surfaceId: surfaceId,
            origin: origin
        )
        if let surfaceId {
            publishBmuxSurfaceCreated(surfaceId, paneId: paneId, kind: kind, origin: origin, focused: focused)
        }
    }

    func publishBmuxSurfaceCreated(
        _ surfaceId: UUID,
        paneId: PaneID?,
        kind: String,
        origin: String,
        focused: Bool
    ) {
        BmuxEventBus.shared.publishSurfaceCreated(
            workspaceId: id,
            surfaceId: surfaceId,
            paneId: paneId?.id,
            kind: kind,
            origin: origin,
            focused: focused
        )
    }

    func publishBmuxSurfaceClosed(_ surfaceId: UUID, paneId: PaneID?, panel: (any Panel)?, origin: String) {
        BmuxEventBus.shared.publishSurfaceClosed(
            workspaceId: id,
            surfaceId: surfaceId,
            paneId: paneId?.id,
            kind: panel.map(Self.bmuxEventSurfaceKind),
            origin: origin
        )
        BmuxSelectionEventState.clearSurface(workspaceId: id, surfaceId: surfaceId)
    }

    func publishBmuxPaneClosed(_ paneId: PaneID, closedPanelIds: [UUID], origin: String) {
        BmuxEventBus.shared.publishPaneClosed(
            workspaceId: id,
            paneId: paneId.id,
            closedSurfaceIds: closedPanelIds,
            origin: origin
        )
        BmuxSelectionEventState.clearPane(workspaceId: id, paneId: paneId.id)
    }

    func publishBmuxFocusedSelection(paneId: PaneID, surfaceId: UUID, origin: String) {
        let paneKey = BmuxSelectionEventState.paneKey(workspaceId: id, paneId: paneId.id)
        let previousSelectedSurfaceId = BmuxSelectionEventState.selectedSurfaceByWorkspacePane[paneKey]
        let kind = panels[surfaceId].map(Self.bmuxEventSurfaceKind)

        if previousSelectedSurfaceId != surfaceId {
            BmuxSelectionEventState.selectedSurfaceByWorkspacePane[paneKey] = surfaceId
            BmuxEventBus.shared.publishSurfaceSelected(
                workspaceId: id,
                surfaceId: surfaceId,
                paneId: paneId.id,
                kind: kind,
                previousSurfaceId: previousSelectedSurfaceId,
                focused: true,
                origin: origin
            )
        }

        if BmuxSelectionEventState.focusedPaneByWorkspace[id] != paneId.id {
            BmuxSelectionEventState.focusedPaneByWorkspace[id] = paneId.id
            BmuxEventBus.shared.publishPaneFocused(
                workspaceId: id,
                paneId: paneId.id,
                selectedSurfaceId: surfaceId,
                origin: origin
            )
        }

        if BmuxSelectionEventState.focusedSurfaceByWorkspace[id] != surfaceId {
            BmuxSelectionEventState.focusedSurfaceByWorkspace[id] = surfaceId
            BmuxEventBus.shared.publishSurfaceFocused(
                workspaceId: id,
                surfaceId: surfaceId,
                paneId: paneId.id,
                kind: kind,
                origin: origin
            )
        }
    }

    static func bmuxEventSurfaceKind(_ panel: any Panel) -> String {
        switch panel.panelType {
        case .terminal:
            return "terminal"
        case .browser:
            return "browser"
        case .markdown:
            return "markdown"
        case .filePreview:
            return "file_preview"
        case .rightSidebarTool:
            return "right_sidebar_tool"
        case .customSidebar:
            return "custom_sidebar"
        case .agentSession:
            return "agent_session"
        case .project:
            return "project"
        case .extensionBrowser:
            return "extension_browser"
        case .cloudVMLoading:
            return "cloud_vm_loading"
        }
    }
}

@MainActor
private enum MainWindowKeyRegainRefresh {
    static func refresh(window: NSWindow, context: AppDelegate.MainWindowContext) {
        // Window focus regain owns the redraw invariant. Cursor tracking and
        // focused subviews can update themselves only after this invalidation.
        invalidateContentDisplayTree(window: window)
        _ = context.keyboardFocusCoordinator.restoreTargetAfterWindowBecameKey()
    }

    private static func invalidateContentDisplayTree(window: NSWindow) {
        guard let contentView = window.contentView else { return }
        invalidateDisplayTree(rootedAt: contentView)
        window.invalidateCursorRects(for: contentView)
    }

    private static func invalidateDisplayTree(rootedAt view: NSView) {
        guard !view.isHidden else { return }
        view.needsDisplay = true
        view.layer?.setNeedsDisplay()
        for subview in view.subviews {
            invalidateDisplayTree(rootedAt: subview)
        }
    }
}

extension AppDelegate {
    func handleBmuxWindowBecameKey(_ note: Notification) {
        guard let window = note.object as? NSWindow else { return }
        MainActor.assumeIsolated {
            let context = contextForMainTerminalWindow(window)
            setActiveMainWindow(window)
            if let windowId = mainWindowId(from: window) {
                publishBmuxWindowLifecycle(name: "window.keyed", windowId: windowId, origin: "appkit_key")
            }
            if let context {
                MainWindowKeyRegainRefresh.refresh(window: window, context: context)
            }
        }
    }

    func handleBmuxWindowResignedKey(_ note: Notification) {
        guard let window = note.object as? NSWindow else { return }
        MainActor.assumeIsolated {
            if let windowId = mainWindowId(from: window) {
                publishBmuxWindowLifecycle(name: "window.unkeyed", windowId: windowId, origin: "appkit_key")
            }
        }
    }

    func publishBmuxWindowLifecycle(name: String, windowId: UUID, origin: String) {
        let manager = tabManagerFor(windowId: windowId)
        let workspaceId = manager?.selectedTabId
        let selectedWorkspaceIndex = workspaceId.flatMap { selectedId in
            manager?.tabs.firstIndex(where: { $0.id == selectedId })
        }
        let window = mainWindow(for: windowId)
        BmuxEventBus.shared.publishWindowLifecycle(
            name: name,
            windowId: windowId,
            workspaceId: workspaceId,
            workspaceCount: manager?.tabs.count,
            selectedWorkspaceIndex: selectedWorkspaceIndex,
            isKeyWindow: window?.isKeyWindow,
            isMainWindow: window?.isMainWindow,
            origin: origin
        )
    }
}
