import AppKit
import WebKit
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

/// Owns the native graph and menu used to distinguish app Find from the menu fallback.
@MainActor
final class BrowserFindShortcutFixture {
    let app: AppDelegate
    let manager: TabManager
    var window: NSWindow { probeWindow }
    let inspectorView: NSView = WKInspectorResponderView(frame: NSRect(x: 0, y: 0, width: 32, height: 20))
    var menuInvocationCount: Int { menuTarget.count }
    private let probeWindow: ProbeWindow
    private let menuTarget = MenuTarget()
    private let previousApp: AppDelegate?
    private let previousActiveManager: TabManager?
    private let previousMenu: NSMenu?
    private var panel: BrowserPanel?

    init() {
        _ = NSApplication.shared
        previousApp = AppDelegate.shared
        previousActiveManager = TerminalController.shared.activeTabManagerForCallerNotification()
        previousMenu = NSApp.mainMenu
        app = AppDelegate()
        manager = TabManager(autoWelcomeIfNeeded: false)
        probeWindow = ProbeWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 420),
            styleMask: [.titled, .closable], backing: .buffered, defer: false
        )
        probeWindow.isReleasedWhenClosed = false
    }

    func prepare(registeredContext: Bool) throws -> BrowserPanel {
        let workspace = try #require(manager.selectedWorkspace)
        let panelID = try #require(manager.openBrowser(inWorkspace: workspace.id, preferSplitRight: true))
        let panel = try #require(workspace.browserPanel(for: panelID))
        self.panel = panel
        let webView = try #require(panel.webView as? BmuxWebView)
        let content = try #require(window.contentView)
        webView.frame = content.bounds
        webView.allowsFirstResponderAcquisition = true
        content.addSubview(webView)
        webView.addSubview(inspectorView)

        let windowID = UUID()
        window.identifier = NSUserInterfaceItemIdentifier("bmux.main.\(windowID.uuidString)")
        if registeredContext {
            manager.windowId = windowID
            manager.window = window
            app.tabManager = manager
            // Compose the real route without registration's listener and session-save side effects.
            app.mainWindowContexts[ObjectIdentifier(window)] = AppDelegate.MainWindowContext(
                windowId: windowID, tabManager: manager, sidebarState: SidebarState(),
                sidebarSelectionState: SidebarSelectionState(), fileExplorerState: nil,
                bmuxConfigStore: nil, window: window
            )
        }
        let menu = NSMenu()
        let root = NSMenuItem(title: "File", action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: "File")
        let item = NSMenuItem(title: "Find", action: #selector(MenuTarget.invoke(_:)), keyEquivalent: "f")
        item.keyEquivalentModifierMask = [.command]
        item.target = menuTarget
        submenu.addItem(item)
        menu.addItem(root)
        menu.setSubmenu(submenu, for: root)
        NSApp.mainMenu = menu
        return panel
    }

    /// Restores process-wide collaborators synchronously, including failed preparation paths.
    func close() {
        NSApp.mainMenu = previousMenu
        inspectorView.removeFromSuperview()
        panel?.webView.removeFromSuperview()
        for workspace in manager.tabs {
            workspace.teardownRemoteConnection()
            workspace.teardownAllPanels()
        }
        app.mainWindowContexts.removeAll()
        app.tabManager = nil
        manager.window = nil
        window.contentView = nil
        window.close()
        TerminalController.shared.setActiveTabManager(previousActiveManager)
        AppDelegate.shared = previousApp
        if let previousApp { GhosttyApp.terminalSurfaceRegistry.attachRouteRetirer(previousApp) }
    }

    // Native routing probes remain offscreen; they have no separate resource lifecycle.
    private final class ProbeWindow: NSWindow {
        override var isKeyWindow: Bool { true }
    }

    private final class WKInspectorResponderView: NSView {
        override var acceptsFirstResponder: Bool { true }
    }

    private final class MenuTarget: NSObject {
        var count = 0
        @objc func invoke(_ sender: Any?) { count += 1 }
    }
}
