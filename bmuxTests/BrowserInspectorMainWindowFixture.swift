import AppKit
import CoreFoundation
import Testing
@testable import bmux_DEV

/// Owns the app-created browser window used by native inspector action-routing cases.
@MainActor
struct BrowserInspectorMainWindowFixture {
    let window: NSWindow
    let manager: TabManager
    let workspace: Workspace
    let panelID: UUID
    let inspectorFixture: BrowserInspectorTestFixture

    init() throws {
        AppDelegate.installWindowResponderSwizzlesForTesting()
        let appDelegate = try #require(AppDelegate.shared)
        let windowID = appDelegate.createMainWindow()
        let window = try #require(NSApp.windows.first {
            $0.identifier?.rawValue == "bmux.main.\(windowID.uuidString)"
        })
        appDelegate.suppressClosedWindowHistoryForTesting(windowId: windowID)
        var completed = false
        defer {
            if !completed {
                window.contentView = nil
                window.orderOut(nil)
                window.close()
            }
        }
        let manager = try #require(appDelegate.tabManagerFor(windowId: windowID))
        defer { if !completed { BrowserInspectorTestFixture.tearDownPanels(manager: manager) } }
        let workspace = try #require(manager.selectedWorkspace)
        let panelID = try #require(manager.openBrowser(inWorkspace: workspace.id, preferSplitRight: true))
        let panel = try #require(workspace.browserPanel(for: panelID))
        self.window = window
        self.manager = manager
        self.workspace = workspace
        self.panelID = panelID
        inspectorFixture = BrowserInspectorTestFixture(panel: panel)
        if panel.webView.superview == nil {
            panel.webView.frame = window.contentView?.bounds ?? .zero
            window.contentView?.addSubview(panel.webView)
        }
        completed = true
    }

    func close() {
        BrowserInspectorTestFixture.tearDownPanels(manager: manager)
        inspectorFixture.closeWindow(window)
    }

    /// Existing routing capture is scoped to synchronous event delivery, never an await.
    func withRoutingWindow(_ window: NSWindow, _ body: () throws -> Void) rethrows {
        guard let appDelegate = AppDelegate.shared else {
            Issue.record("Expected AppDelegate.shared")
            return
        }
        let previousWindow = debugShortcutRoutingFocusedWindowOverrideForTesting.window
        let previousResponder = debugShortcutRoutingFocusedWindowOverrideForTesting.keyRepairFirstResponder
        appDelegate.debugBeginShortcutRoutingFocusedWindowCaptureForTesting()
        defer {
            appDelegate.debugEndShortcutRoutingFocusedWindowCaptureForTesting()
            appDelegate.debugSetShortcutRoutingFocusedWindowForTesting(previousWindow)
            appDelegate.debugSetShortcutRoutingKeyRepairFirstResponderForTesting(previousResponder)
        }
        appDelegate.debugSetShortcutRoutingFocusedWindowForTesting(window)
        window.makeKeyAndOrderFront(nil)
        window.makeKey()
        #expect(window.isKeyWindow || appDelegate.shortcutRoutingKeyWindow === window)
        try body()
    }

    func withTemporaryShortcut(_ shortcut: BrowserConfigStoredShortcut, _ body: () throws -> Void) throws {
        let action = KeyboardShortcutSettings.Action.closeTab
        let defaults = UserDefaults.standard
        let previousValue = CFPreferencesCopyValue(
            action.defaultsKey as CFString, kCFPreferencesCurrentApplication,
            kCFPreferencesCurrentUser, kCFPreferencesAnyHost
        )
        try #require(!KeyboardShortcutSettings.isManagedBySettingsFile(action))
        defer {
            if let previousValue { defaults.set(previousValue, forKey: action.defaultsKey) }
            else { defaults.removeObject(forKey: action.defaultsKey) }
            KeyboardShortcutSettings.notifySettingsFileDidChange()
            AppDelegate.shared?.debugResetShortcutRoutingStateForTesting(clearFocusedWindowOverride: false)
        }
        KeyboardShortcutSettings.setShortcut(shortcut, for: action)
        AppDelegate.shared?.debugResetShortcutRoutingStateForTesting(clearFocusedWindowOverride: false)
        try body()
    }
}
