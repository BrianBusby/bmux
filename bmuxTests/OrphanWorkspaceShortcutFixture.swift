import AppKit
#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

/// Owns live and windowless routing contexts without starting window-registration services.
@MainActor
final class OrphanWorkspaceShortcutFixture {
    let app: AppDelegate
    let liveManager: TabManager
    let orphanManager: TabManager
    let window: NSWindow
    let orphanWindowID = UUID()
    private let orphanKey = NSObject()
    private let previousApp: AppDelegate?
    private let previousActiveManager: TabManager?
    private let previousFocusedWindow: NSWindow?

    init() {
        _ = NSApplication.shared
        previousApp = AppDelegate.shared
        previousActiveManager = TerminalController.shared.activeTabManagerForCallerNotification()
        previousFocusedWindow = debugShortcutRoutingFocusedWindowOverrideForTesting.window
        app = AppDelegate()
        liveManager = TabManager(autoWelcomeIfNeeded: false)
        orphanManager = TabManager(autoWelcomeIfNeeded: false)
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 240),
            styleMask: [.titled], backing: .buffered, defer: false
        )
        window.isReleasedWhenClosed = false
        let liveWindowID = UUID()
        window.identifier = NSUserInterfaceItemIdentifier("bmux.main.\(liveWindowID.uuidString)")
        liveManager.window = window
        liveManager.windowId = liveWindowID
        app.mainWindowContexts[ObjectIdentifier(window)] = AppDelegate.MainWindowContext(
            windowId: liveWindowID, tabManager: liveManager, sidebarState: SidebarState(),
            sidebarSelectionState: SidebarSelectionState(), fileExplorerState: nil,
            bmuxConfigStore: nil, window: window
        )
        app.mainWindowContexts[ObjectIdentifier(orphanKey)] = AppDelegate.MainWindowContext(
            windowId: orphanWindowID, tabManager: orphanManager, sidebarState: SidebarState(),
            sidebarSelectionState: SidebarSelectionState(), fileExplorerState: nil,
            bmuxConfigStore: nil, window: nil
        )
        app.tabManager = orphanManager
        // A captured live window takes precedence over the active manager during shortcut sync.
        app.debugSetShortcutRoutingFocusedWindowForTesting(nil)
    }

    /// Synchronous defer cleanup also covers failures before event delivery.
    func close() {
        for manager in [liveManager, orphanManager] {
            for workspace in manager.tabs {
                workspace.teardownRemoteConnection()
                workspace.teardownAllPanels()
            }
            manager.window = nil
        }
        app.mainWindowContexts.removeAll()
        app.tabManager = nil
        window.contentView = nil
        window.close()
        app.debugSetShortcutRoutingFocusedWindowForTesting(previousFocusedWindow)
        TerminalController.shared.setActiveTabManager(previousActiveManager)
        AppDelegate.shared = previousApp
        if let previousApp { GhosttyApp.terminalSurfaceRegistry.attachRouteRetirer(previousApp) }
    }
}
