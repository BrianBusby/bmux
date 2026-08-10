import Foundation
import Testing
#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@MainActor
@Suite(.serialized)
struct BrowserOpenSplitSocketTests {
    @Test func reportsCanonicalPlacementStrategy() throws {
        let defaults = UserDefaults.standard
        let previousBrowserDisabled = defaults.object(forKey: BrowserAvailabilitySettings.disabledKey)
        BrowserAvailabilitySettings.setDisabled(false)
        defer {
            if let previousBrowserDisabled {
                defaults.set(previousBrowserDisabled, forKey: BrowserAvailabilitySettings.disabledKey)
            } else {
                defaults.removeObject(forKey: BrowserAvailabilitySettings.disabledKey)
            }
            TerminalController.shared.setActiveTabManager(nil)
        }

        let manager = TabManager()
        let workspace = try #require(manager.selectedWorkspace)
        let sourceSurfaceId = try #require(workspace.focusedPanelId)
        TerminalController.shared.setActiveTabManager(manager)

        let firstResult = try result(method: "browser.open_split", params: [
            "workspace_id": workspace.id.uuidString,
            "surface_id": sourceSurfaceId.uuidString,
            "url": "https://example.com",
            "focus": false
        ])
        #expect(firstResult["created_split"] as? Bool == true)
        #expect(firstResult["placement_strategy"] as? String == "split_right")

        let secondResult = try result(method: "browser.open_split", params: [
            "workspace_id": workspace.id.uuidString,
            "surface_id": sourceSurfaceId.uuidString,
            "url": "https://example.test",
            "focus": false
        ])
        #expect(secondResult["created_split"] as? Bool == false)
        #expect(secondResult["placement_strategy"] as? String == "reuse_right_sibling")
    }

    @Test func browserTabSwitchUsesCanonicalWorkspaceSurfaceFocusPath() throws {
        let defaults = UserDefaults.standard
        let previousBrowserDisabled = defaults.object(forKey: BrowserAvailabilitySettings.disabledKey)
        BrowserAvailabilitySettings.setDisabled(false)
        defer {
            if let previousBrowserDisabled {
                defaults.set(previousBrowserDisabled, forKey: BrowserAvailabilitySettings.disabledKey)
            } else {
                defaults.removeObject(forKey: BrowserAvailabilitySettings.disabledKey)
            }
            TerminalController.shared.setActiveTabManager(nil)
        }

        let manager = TabManager()
        let originalWorkspace = try #require(manager.selectedWorkspace)
        let targetWorkspace = manager.addWorkspace(select: false, placementOverride: .end)
        let paneId = try #require(targetWorkspace.bonsplitController.focusedPaneId)
        let firstBrowser = try #require(targetWorkspace.newBrowserSurface(
            inPane: paneId,
            url: URL(string: "https://example.com"),
            focus: false
        ))
        let secondBrowser = try #require(targetWorkspace.newBrowserSurface(
            inPane: paneId,
            url: URL(string: "https://example.test"),
            focus: false
        ))
        targetWorkspace.focusPanel(firstBrowser.id)
        #expect(manager.selectedTabId == originalWorkspace.id)
        TerminalController.shared.setActiveTabManager(manager)

        let switchResult = try result(method: "browser.tab.switch", params: [
            "workspace_id": targetWorkspace.id.uuidString,
            "target_surface_id": secondBrowser.id.uuidString
        ])

        #expect(switchResult["workspace_id"] as? String == targetWorkspace.id.uuidString)
        #expect(switchResult["surface_id"] as? String == secondBrowser.id.uuidString)
        #expect(manager.selectedTabId == targetWorkspace.id)
        #expect(targetWorkspace.focusedPanelId == secondBrowser.id)
    }

    @Test func browserTabNewCreatesBrowserSurfaceInRequestedWorkspace() throws {
        let defaults = UserDefaults.standard
        let previousBrowserDisabled = defaults.object(forKey: BrowserAvailabilitySettings.disabledKey)
        BrowserAvailabilitySettings.setDisabled(false)
        defer {
            if let previousBrowserDisabled {
                defaults.set(previousBrowserDisabled, forKey: BrowserAvailabilitySettings.disabledKey)
            } else {
                defaults.removeObject(forKey: BrowserAvailabilitySettings.disabledKey)
            }
            TerminalController.shared.setActiveTabManager(nil)
        }

        let manager = TabManager()
        let workspace = try #require(manager.selectedWorkspace)
        let paneId = try #require(workspace.bonsplitController.focusedPaneId)
        TerminalController.shared.setActiveTabManager(manager)

        let newResult = try result(method: "browser.tab.new", params: [
            "workspace_id": workspace.id.uuidString,
            "pane_id": paneId.id.uuidString,
            "url": "https://example.com"
        ])

        let surfaceIdString = try #require(newResult["surface_id"] as? String)
        let surfaceId = try #require(UUID(uuidString: surfaceIdString))
        #expect(newResult["workspace_id"] as? String == workspace.id.uuidString)
        #expect(newResult["pane_id"] as? String == paneId.id.uuidString)
        #expect(workspace.browserPanel(for: surfaceId) != nil)
        #expect(workspace.paneId(forPanelId: surfaceId) == paneId)
        #expect(workspace.focusedPanelId == surfaceId)
    }

    @Test func canvasSelectTabUsesCanonicalWorkspaceSurfaceFocusPath() throws {
        defer {
            TerminalController.shared.setActiveTabManager(nil)
        }

        let manager = TabManager()
        let originalWorkspace = try #require(manager.selectedWorkspace)
        let targetWorkspace = manager.addWorkspace(select: false, placementOverride: .end)
        targetWorkspace.setLayoutMode(.canvas)
        let targetSurfaceId = try #require(targetWorkspace.openNewCanvasPane(type: .terminal, focus: true))
        #expect(manager.selectedTabId == originalWorkspace.id)
        TerminalController.shared.setActiveTabManager(manager)

        let selectResult = try result(method: "canvas.select_tab", params: [
            "workspace_id": targetWorkspace.id.uuidString,
            "surface_id": targetSurfaceId.uuidString
        ])

        #expect(selectResult["mode"] as? String == "canvas")
        #expect(manager.selectedTabId == targetWorkspace.id)
        #expect(targetWorkspace.focusedPanelId == targetSurfaceId)
    }

    @Test func appDelegateBrowserAddressBarFocusUsesCanonicalWorkspaceSurfaceFocusPath() throws {
        let defaults = UserDefaults.standard
        let previousBrowserDisabled = defaults.object(forKey: BrowserAvailabilitySettings.disabledKey)
        BrowserAvailabilitySettings.setDisabled(false)
        defer {
            if let previousBrowserDisabled {
                defaults.set(previousBrowserDisabled, forKey: BrowserAvailabilitySettings.disabledKey)
            } else {
                defaults.removeObject(forKey: BrowserAvailabilitySettings.disabledKey)
            }
            TerminalController.shared.setActiveTabManager(nil)
        }

        let app = AppDelegate()
        let manager = TabManager()
        let windowId = app.registerMainWindowContextForTesting(tabManager: manager)
        defer {
            app.unregisterMainWindowContextForTesting(windowId: windowId)
        }

        let originalWorkspace = try #require(manager.selectedWorkspace)
        let targetWorkspace = manager.addWorkspace(select: false, placementOverride: .end)
        let paneId = try #require(targetWorkspace.bonsplitController.focusedPaneId)
        let browser = try #require(targetWorkspace.createBrowserSurfaceForAction(
            inPane: paneId,
            url: URL(string: "https://example.com"),
            focus: false
        ))

        #expect(manager.selectedTabId == originalWorkspace.id)

        #expect(app.focusBrowserAddressBar(panelId: browser.id))
        #expect(manager.selectedTabId == targetWorkspace.id)
        #expect(targetWorkspace.focusedPanelId == browser.id)
    }

    private func result(method: String, params: [String: Any]) throws -> [String: Any] {
        let envelope = try response(method: method, params: params)
        #expect(envelope["ok"] as? Bool == true, "Unexpected JSON-RPC response: \(envelope)")
        return try #require(envelope["result"] as? [String: Any])
    }

    private func response(method: String, params: [String: Any]) throws -> [String: Any] {
        let request = ["jsonrpc": "2.0", "id": 1, "method": method, "params": params] as [String: Any]
        let data = try JSONSerialization.data(withJSONObject: request, options: [.sortedKeys])
        let line = try #require(String(data: data, encoding: .utf8))
        let raw = TerminalController.shared.handleSocketLine(line)
        let rawData = try #require(raw.data(using: .utf8))
        return try #require(try JSONSerialization.jsonObject(with: rawData) as? [String: Any])
    }
}
