import Foundation
import Testing
import AppKit
import BmuxControlSocket
import BmuxTerminal

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@MainActor
@Suite(.serialized)
struct TerminalControllerSurfaceActionSocketTests {
    private func makeMainWindow(id: UUID) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 320),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.identifier = NSUserInterfaceItemIdentifier("bmux.main.\(id.uuidString)")
        return window
    }

    @Test func controlSidebarNewSurfaceCreatesTerminalWithoutStealingFocus() throws {
        defer { TerminalController.shared.setActiveTabManager(nil) }
        let manager = TabManager()
        let workspace = try #require(manager.selectedWorkspace)
        let originalPanelId = try #require(workspace.focusedPanelId)
        TerminalController.shared.setActiveTabManager(manager)

        let result = TerminalController.shared.controlSidebarNewSurface(
            isBrowser: false,
            paneArg: nil,
            url: nil
        )

        guard case .created(let panelId) = result else {
            Issue.record("Expected sidebar new surface action to create a terminal panel")
            return
        }
        #expect(panelId != originalPanelId)
        #expect(workspace.panels[panelId] != nil)
        #expect(workspace.focusedPanelId == originalPanelId)
    }

    @Test func controlSidebarPaneSplitCreatesTerminalWithoutStealingFocus() throws {
        defer { TerminalController.shared.setActiveTabManager(nil) }
        let manager = TabManager()
        let workspace = try #require(manager.selectedWorkspace)
        let originalPanelId = try #require(workspace.focusedPanelId)
        let originalPane = try #require(workspace.paneId(forPanelId: originalPanelId))
        TerminalController.shared.setActiveTabManager(manager)

        let result = TerminalController.shared.controlSidebarCreatePaneSplit(
            isBrowser: false,
            orientationIsHorizontal: true,
            insertFirst: false,
            url: nil
        )

        guard case .created(let panelId) = result else {
            Issue.record("Expected sidebar pane split action to create a terminal panel")
            return
        }
        let splitPane = try #require(workspace.paneId(forPanelId: panelId))
        #expect(panelId != originalPanelId)
        #expect(splitPane != originalPane)
        #expect(workspace.focusedPanelId == originalPanelId)
    }

    @Test func controlTabActionNewTerminalRightCreatesTerminalNextToAnchor() throws {
        defer { TerminalController.shared.setActiveTabManager(nil) }
        let manager = TabManager()
        let workspace = try #require(manager.selectedWorkspace)
        let originalPanelId = try #require(workspace.focusedPanelId)
        let pane = try #require(workspace.paneId(forPanelId: originalPanelId))
        let originalSurfaceId = try #require(workspace.surfaceIdFromPanelId(originalPanelId))
        TerminalController.shared.setActiveTabManager(manager)

        let result = TerminalController.shared.controlTabAction(
            routing: ControlRoutingSelectors(
                hasWindowIDParam: false,
                windowID: nil,
                groupID: nil,
                workspaceID: workspace.id,
                surfaceID: nil,
                paneID: nil
            ),
            actionKey: "new_terminal_right",
            title: nil,
            rawURL: nil,
            surfaceID: originalPanelId,
            requestedFocus: false,
            moveParams: [:]
        )

        guard case .completed(let outcome) = result,
              case .created(let panelId) = outcome.extras else {
            Issue.record("Expected tab action to create a terminal panel")
            return
        }
        #expect(panelId != originalPanelId)
        #expect(workspace.panels[panelId] != nil)
        #expect(workspace.paneId(forPanelId: panelId) == pane)
        let paneTabIds = workspace.bonsplitController.tabs(inPane: pane).map(\.id)
        let anchorIndex = try #require(paneTabIds.firstIndex(of: originalSurfaceId))
        #expect(anchorIndex + 1 < paneTabIds.count)
        #expect(workspace.surfaceIdFromPanelId(panelId) == paneTabIds[anchorIndex + 1])
    }

    @Test func controlPaneSwapUsesActionPathForSingleSurfacePlaceholders() throws {
        let previousAppDelegate = AppDelegate.shared
        let app = AppDelegate()
        AppDelegate.shared = app
        defer { AppDelegate.shared = previousAppDelegate }

        let manager = TabManager()
        let windowId = UUID()
        let window = makeMainWindow(id: windowId)
        app.registerMainWindow(
            window,
            windowId: windowId,
            tabManager: manager,
            sidebarState: SidebarState(),
            sidebarSelectionState: SidebarSelectionState(),
            fileExplorerState: FileExplorerState()
        )
        defer {
            TerminalController.shared.setActiveTabManager(nil)
            app.unregisterMainWindowContextForTesting(windowId: windowId)
            window.orderOut(nil)
        }
        let workspace = try #require(manager.selectedWorkspace)
        let sourcePanelId = try #require(workspace.focusedPanelId)
        let sourcePaneId = try #require(workspace.paneId(forPanelId: sourcePanelId))
        let splitOutcome = workspace.createTerminalSplitForAction(
            from: sourcePanelId,
            orientation: .horizontal,
            focus: false
        )
        let targetPanelId = try #require(splitOutcome.panel?.id)
        let targetPaneId = try #require(workspace.paneId(forPanelId: targetPanelId))
        TerminalController.shared.setActiveTabManager(manager)

        let result = TerminalController.shared.controlPaneSwap(
            sourcePaneID: sourcePaneId.id,
            targetPaneID: targetPaneId.id,
            requestedFocus: false
        )

        guard case .swapped(
            windowID: _,
            workspaceID: let swappedWorkspaceId,
            sourcePaneID: let swappedSourcePaneId,
            targetPaneID: let swappedTargetPaneId,
            sourceSurfaceID: let swappedSourceSurfaceId,
            targetSurfaceID: let swappedTargetSurfaceId
        ) = result else {
            Issue.record("Expected pane swap to succeed through the terminal action path, got \(String(describing: result))")
            return
        }
        #expect(swappedWorkspaceId == workspace.id)
        #expect(swappedSourcePaneId == sourcePaneId.id)
        #expect(swappedTargetPaneId == targetPaneId.id)
        #expect(swappedSourceSurfaceId == sourcePanelId)
        #expect(swappedTargetSurfaceId == targetPanelId)
        #expect(workspace.paneId(forPanelId: sourcePanelId) == targetPaneId)
        #expect(workspace.paneId(forPanelId: targetPanelId) == sourcePaneId)
        #expect(workspace.panels.keys.sorted { $0.uuidString < $1.uuidString } == [sourcePanelId, targetPanelId].sorted { $0.uuidString < $1.uuidString })
    }

    @Test func v2TabRenameAndClearUseUserTitlePolicy() throws {
        defer { TerminalController.shared.setActiveTabManager(nil) }
        let manager = TabManager()
        let workspace = try #require(manager.selectedWorkspace)
        let pane = try #require(workspace.bonsplitController.allPaneIds.first)
        let panel = try #require(workspace.newTerminalSurface(inPane: pane, focus: true))
        TerminalController.shared.setActiveTabManager(manager)

        let renameResponse = try handleV2Request(method: "tab.action", params: [
            "workspace_id": workspace.id.uuidString,
            "surface_id": panel.id.uuidString,
            "action": "rename",
            "title": "  Socket Tab  "
        ])
        #expect(renameResponse["ok"] as? Bool == true)
        let renameResult = try #require(renameResponse["result"] as? [String: Any])
        #expect(renameResult["title"] as? String == "Socket Tab")
        #expect(workspace.panelCustomTitles[panel.id] == "Socket Tab")
        #expect(workspace.panelCustomTitleSources[panel.id] == .user)

        let invalidRename = try handleV2Request(method: "tab.action", params: [
            "workspace_id": workspace.id.uuidString,
            "surface_id": panel.id.uuidString,
            "action": "rename",
            "title": "   "
        ])
        #expect(invalidRename["ok"] as? Bool == false)
        let invalidError = try #require(invalidRename["error"] as? [String: Any])
        #expect(invalidError["code"] as? String == "invalid_params")
        #expect(workspace.panelCustomTitles[panel.id] == "Socket Tab")

        let clearResponse = try handleV2Request(method: "tab.action", params: [
            "workspace_id": workspace.id.uuidString,
            "surface_id": panel.id.uuidString,
            "action": "clear_name"
        ])
        #expect(clearResponse["ok"] as? Bool == true)
        #expect(workspace.panelCustomTitles[panel.id] == nil)
        #expect(workspace.panelCustomTitleSources[panel.id] == nil)
    }

    @Test func v2TabPinAndUnpinUseWorkspaceSurfacePinPolicy() throws {
        defer { TerminalController.shared.setActiveTabManager(nil) }
        let manager = TabManager()
        let workspace = try #require(manager.selectedWorkspace)
        let pane = try #require(workspace.bonsplitController.allPaneIds.first)
        let panel = try #require(workspace.newTerminalSurface(inPane: pane, focus: true))
        TerminalController.shared.setActiveTabManager(manager)

        let pinResponse = try handleV2Request(method: "tab.action", params: [
            "workspace_id": workspace.id.uuidString,
            "surface_id": panel.id.uuidString,
            "action": "pin"
        ])
        #expect(pinResponse["ok"] as? Bool == true)
        let pinResult = try #require(pinResponse["result"] as? [String: Any])
        #expect(pinResult["pinned"] as? Bool == true)
        #expect(workspace.isPanelPinned(panel.id))

        let unpinResponse = try handleV2Request(method: "tab.action", params: [
            "workspace_id": workspace.id.uuidString,
            "surface_id": panel.id.uuidString,
            "action": "unpin"
        ])
        #expect(unpinResponse["ok"] as? Bool == true)
        let unpinResult = try #require(unpinResponse["result"] as? [String: Any])
        #expect(unpinResult["pinned"] as? Bool == false)
        #expect(!workspace.isPanelPinned(panel.id))
    }

    @Test func v2TabCloseOthersUsesWorkspaceSurfaceClosePolicy() throws {
        defer { TerminalController.shared.setActiveTabManager(nil) }
        let manager = TabManager()
        let workspace = try #require(manager.selectedWorkspace)
        let anchorPanelId = try #require(workspace.focusedPanelId)
        let pane = try #require(workspace.paneId(forPanelId: anchorPanelId))
        let pinnedPanel = try #require(
            workspace.createTerminalSurfaceForAction(inPane: pane, focus: false).panel
        )
        let closablePanel = try #require(
            workspace.createTerminalSurfaceForAction(inPane: pane, focus: false).panel
        )
        workspace.setSurfacePinnedForAction(surfaceId: pinnedPanel.id, pinned: true)
        TerminalController.shared.setActiveTabManager(manager)

        let response = try handleV2Request(method: "tab.action", params: [
            "workspace_id": workspace.id.uuidString,
            "surface_id": anchorPanelId.uuidString,
            "action": "close_others"
        ])

        #expect(response["ok"] as? Bool == true)
        let result = try #require(response["result"] as? [String: Any])
        #expect(result["closed"] as? Int == 1)
        #expect(result["skipped_pinned"] as? Int == 1)
        #expect(workspace.panels[anchorPanelId] != nil)
        #expect(workspace.panels[pinnedPanel.id] != nil)
        #expect(workspace.panels[closablePanel.id] == nil)
        #expect(workspace.panels.count == 2)
    }

    @Test func v2TabReadAndUnreadUseWorkspaceSurfaceUnreadPolicy() throws {
        defer { TerminalController.shared.setActiveTabManager(nil) }
        let manager = TabManager()
        let workspace = try #require(manager.selectedWorkspace)
        let pane = try #require(workspace.bonsplitController.allPaneIds.first)
        let panel = try #require(workspace.newTerminalSurface(inPane: pane, focus: true))
        TerminalController.shared.setActiveTabManager(manager)

        let unreadResponse = try handleV2Request(method: "tab.action", params: [
            "workspace_id": workspace.id.uuidString,
            "surface_id": panel.id.uuidString,
            "action": "mark_unread"
        ])
        #expect(unreadResponse["ok"] as? Bool == true)
        #expect(workspace.manualUnreadPanelIds.contains(panel.id))

        let readResponse = try handleV2Request(method: "tab.action", params: [
            "workspace_id": workspace.id.uuidString,
            "surface_id": panel.id.uuidString,
            "action": "mark_read"
        ])
        #expect(readResponse["ok"] as? Bool == true)
        #expect(!workspace.manualUnreadPanelIds.contains(panel.id))
    }

    @Test func v2TabFullWidthToggleUsesWorkspaceSurfaceLayoutPolicy() throws {
        defer { TerminalController.shared.setActiveTabManager(nil) }
        let manager = TabManager()
        let workspace = try #require(manager.selectedWorkspace)
        let pane = try #require(workspace.bonsplitController.allPaneIds.first)
        let panel = try #require(workspace.newTerminalSurface(inPane: pane, focus: true))
        TerminalController.shared.setActiveTabManager(manager)

        let enabledResponse = try handleV2Request(method: "tab.action", params: [
            "workspace_id": workspace.id.uuidString,
            "surface_id": panel.id.uuidString,
            "action": "toggle_full_width_tab"
        ])
        #expect(enabledResponse["ok"] as? Bool == true)
        let enabledResult = try #require(enabledResponse["result"] as? [String: Any])
        #expect(enabledResult["full_width_tab_mode"] as? Bool == true)
        #expect(workspace.bonsplitController.isFullWidthTabMode(inPane: pane))

        let disabledResponse = try handleV2Request(method: "tab.action", params: [
            "workspace_id": workspace.id.uuidString,
            "surface_id": panel.id.uuidString,
            "action": "toggle_full_width_tab"
        ])
        #expect(disabledResponse["ok"] as? Bool == true)
        let disabledResult = try #require(disabledResponse["result"] as? [String: Any])
        #expect(disabledResult["full_width_tab_mode"] as? Bool == false)
        #expect(!workspace.bonsplitController.isFullWidthTabMode(inPane: pane))
    }


    @Test func workspaceCloseRejectsLastWorkspace() throws {
        defer { TerminalController.shared.setActiveTabManager(nil) }
        let manager = TabManager()
        let workspace = try #require(manager.selectedWorkspace)
        TerminalController.shared.setActiveTabManager(manager)

        let response = try handleV2Request(
            method: "workspace.close",
            params: ["workspace_id": workspace.id.uuidString]
        )
        #expect(response["ok"] as? Bool == false)
        let error = try #require(response["error"] as? [String: Any])
        #expect(error["code"] as? String == "protected")

        let data = try #require(error["data"] as? [String: Any])
        #expect(data["workspace_id"] as? String == workspace.id.uuidString)
        #expect(data["pinned"] as? Bool == false)
        #expect(manager.tabs.map(\.id) == [workspace.id])
    }

    @Test func surfaceFocusSelectsWorkspaceDockSurfaceThroughSocketPath() throws {
        let previousAppDelegate = AppDelegate.shared
        let previousManager = TerminalController.shared.activeTabManagerForCallerNotification()
        let appDelegate = AppDelegate()
        let manager = TabManager(autoWelcomeIfNeeded: false)
        AppDelegate.shared = appDelegate
        appDelegate.tabManager = manager
        TerminalController.shared.setActiveTabManager(manager)
        let windowId = appDelegate.registerMainWindowContextForTesting(tabManager: manager)
        defer {
            TerminalController.shared.setActiveTabManager(previousManager)
            appDelegate.unregisterMainWindowContextForTesting(windowId: windowId)
            manager.tabs.forEach { $0.teardownAllPanels() }
            AppDelegate.shared = previousAppDelegate
        }

        let workspace = try #require(manager.tabs.first)
        let store = workspace.dockSplit
        let rootPane = try #require(store.bonsplitController.allPaneIds.first)
        let firstPanelId = try #require(store.newSurface(kind: .terminal, inPane: rootPane, focus: true))
        let secondPanelId = try #require(store.newSurface(kind: .terminal, inPane: rootPane, focus: false))
        #expect(store.focusedPanelId == firstPanelId)

        let response = try handleV2Request(
            method: "surface.focus",
            params: ["surface_id": secondPanelId.uuidString]
        )

        #expect(response["ok"] as? Bool == true)
        let result = try #require(response["result"] as? [String: Any])
        #expect(result["window_id"] as? String == windowId.uuidString)
        #expect(result["workspace_id"] as? String == workspace.id.uuidString)
        #expect(result["surface_id"] as? String == secondPanelId.uuidString)
        #expect(store.focusedPanelId == secondPanelId)
    }

    @Test func dockPanelFocusActionValidatesAndSelectsSurface() throws {
        let store = DockSplitStore(
            workspaceId: UUID(),
            baseDirectoryProvider: { nil }
        )
        defer { store.closeAllPanels() }
        let rootPane = try #require(store.bonsplitController.allPaneIds.first)
        let firstPanelId = try #require(store.newSurface(kind: .terminal, inPane: rootPane, focus: true))
        let secondPanelId = try #require(store.newSurface(kind: .terminal, inPane: rootPane, focus: false))
        #expect(store.focusedPanelId == firstPanelId)

        #expect(!store.requestPanelFocusForAction(panelId: UUID(), window: nil))
        #expect(store.focusedPanelId == firstPanelId)

        #expect(store.requestPanelFocusForAction(panelId: secondPanelId, window: nil))
        #expect(store.focusedPanelId == secondPanelId)
    }

    private func handleV2Request(method: String, params: [String: Any]) throws -> [String: Any] {
        let payload: [String: Any] = ["jsonrpc": "2.0", "id": 1, "method": method, "params": params]
        let data = try JSONSerialization.data(withJSONObject: payload)
        let response = TerminalController.shared.handleSocketLine(String(decoding: data, as: UTF8.self))
        let responseData = try #require(response.data(using: .utf8))
        return try #require(try JSONSerialization.jsonObject(with: responseData) as? [String: Any])
    }
}
