import AppKit
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

/// Owns a real window route without registration's listener and session-save side effects.
@MainActor
final class LiveSurfaceRecoveryWindowFixture {
    let app: AppDelegate
    let manager: TabManager
    let window: NSWindow
    let windowId = UUID()
    private let previousApp: AppDelegate?
    private let previousActiveManager: TabManager?

    init() {
        _ = NSApplication.shared
        previousApp = AppDelegate.shared
        previousActiveManager = TerminalController.shared.activeTabManagerForCallerNotification()
        app = AppDelegate()
        manager = TabManager()
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 320),
            styleMask: [.titled, .closable], backing: .buffered, defer: false
        )
        window.isReleasedWhenClosed = false
        window.identifier = NSUserInterfaceItemIdentifier("bmux.main.\(windowId.uuidString)")
    }

    func prepare() {
        manager.windowId = windowId
        manager.window = window
        app.tabManager = manager
        app.mainWindowContexts[ObjectIdentifier(window)] = AppDelegate.MainWindowContext(
            windowId: windowId, tabManager: manager, sidebarState: SidebarState(),
            sidebarSelectionState: SidebarSelectionState(), fileExplorerState: FileExplorerState(),
            bmuxConfigStore: nil, window: window
        )
        TerminalController.shared.setActiveTabManager(manager)
    }

    func v2Result(method: String, params: [String: Any] = [:]) throws -> [String: Any] {
        let request: [String: Any] = ["id": method, "method": method, "params": params]
        let requestData = try JSONSerialization.data(withJSONObject: request)
        let requestLine = try #require(String(data: requestData, encoding: .utf8))
        let raw = TerminalController.shared.handleSocketLine(requestLine)
        let data = try #require(raw.data(using: .utf8))
        let envelope = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(envelope["ok"] as? Bool == true, "\(raw)")
        return try #require(envelope["result"] as? [String: Any], "\(raw)")
    }

    /// Restores shared collaborators in the same synchronous actor job as the API calls.
    func close() {
        TerminalController.shared.setActiveTabManager(nil)
        app.unregisterMainWindowContextForTesting(windowId: windowId)
        for workspace in manager.tabs {
            workspace.teardownRemoteConnection()
            workspace.teardownAllPanels()
        }
        app.forgetRecoverableMainWindowRoute(windowId: windowId)
        app.tabManager = nil
        manager.window = nil
        window.orderOut(nil)
        window.close()
        AppDelegate.shared = previousApp
        TerminalController.shared.setActiveTabManager(previousActiveManager)
        if let previousApp { GhosttyApp.terminalSurfaceRegistry.attachRouteRetirer(previousApp) }
    }
}
