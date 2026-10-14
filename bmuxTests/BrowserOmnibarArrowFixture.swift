import AppKit
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

/// Owns the real window/workspace/panel graph needed by omnibar shortcut routing.
@MainActor
final class BrowserOmnibarArrowFixture {
    let app: AppDelegate
    let manager: TabManager
    let field: OmnibarNativeTextField
    var window: NSWindow { probeWindow }
    var editor: NSTextView { probeWindow.editor }
    var recordedKeyCodes: [UInt16] { probeWindow.editor.keyCodes }
    private let probeWindow: ProbeWindow
    private let previousApp: AppDelegate?
    private let previousActiveManager: TabManager?
    private var panel: BrowserPanel?

    init() {
        _ = NSApplication.shared
        previousApp = AppDelegate.shared
        previousActiveManager = TerminalController.shared.activeTabManagerForCallerNotification()
        app = AppDelegate()
        manager = TabManager(autoWelcomeIfNeeded: false)
        probeWindow = ProbeWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 420),
            styleMask: [.titled, .closable], backing: .buffered, defer: false
        )
        probeWindow.isReleasedWhenClosed = false
        field = OmnibarNativeTextField(frame: NSRect(x: 12, y: 380, width: 360, height: 24))
        field.stringValue = "abcdef"
    }

    func prepare() throws -> BrowserPanel {
        let workspace = try #require(manager.selectedWorkspace)
        let panelID = try #require(manager.openBrowser(inWorkspace: workspace.id, preferSplitRight: true))
        let panel = try #require(workspace.browserPanel(for: panelID))
        self.panel = panel
        let webView = try #require(panel.webView as? BmuxWebView)
        let content = try #require(window.contentView)
        field.panelId = panelID
        content.addSubview(field)
        webView.allowsFirstResponderAcquisition = true
        webView.frame = NSRect(x: 0, y: 0, width: 640, height: 360)
        content.addSubview(webView)

        let windowID = UUID()
        window.identifier = NSUserInterfaceItemIdentifier("bmux.main.\(windowID.uuidString)")
        manager.window = window
        manager.windowId = windowID
        app.tabManager = manager
        // Same real context as registration, without listener/startup/session-save side effects.
        app.mainWindowContexts[ObjectIdentifier(window)] = AppDelegate.MainWindowContext(
            windowId: windowID, tabManager: manager, sidebarState: SidebarState(),
            sidebarSelectionState: SidebarSelectionState(), fileExplorerState: nil,
            bmuxConfigStore: nil, window: window
        )
        AppDelegate.installWindowResponderSwizzlesForTesting()
        return panel
    }

    func resetEditor(marked: Bool) {
        probeWindow.editor.keyCodes.removeAll()
        probeWindow.editor.marked = marked
    }

    /// Called synchronously by the test's defer, including failed preparation paths.
    func close() {
        if let panel { app.clearBrowserAddressBarFocus(panelId: panel.id, reason: "arrow-fixture.cleanup") }
        field.removeFromSuperview()
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

    // These tiny native probes have no independent lifecycle beyond their owning window.
    private final class ProbeWindow: NSWindow {
        let editor = ProbeEditor(frame: NSRect(x: 0, y: 0, width: 240, height: 24))

        override func fieldEditor(_ createFlag: Bool, for object: Any?) -> NSText? { editor }
    }

    private final class ProbeEditor: NSTextView {
        var keyCodes: [UInt16] = []
        var marked = false

        override var isFieldEditor: Bool {
            get { true }
            set {}
        }
        override func keyDown(with event: NSEvent) { keyCodes.append(event.keyCode) }
        override func hasMarkedText() -> Bool { marked }
    }
}
