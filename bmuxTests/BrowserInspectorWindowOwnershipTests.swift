import AppKit
import WebKit

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif
import Testing

@MainActor
@Suite(.serialized)
struct BrowserInspectorWindowOwnershipTests {
    @Test
    func directAttachedOpenAdoptsAttachedPresentation() {
        let fixture = BrowserInspectorTestFixture()
        let panel = fixture.panel
        defer { fixture.closePanel() }
        let window = fixture.makeWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 300))
        defer { fixture.closeWindow(window) }
        guard let contentView = window.contentView else {
            Issue.record("Expected window content view")
            return
        }
        let attachedHost = NSView(frame: contentView.bounds)
        contentView.addSubview(attachedHost)
        panel.webView.frame = NSRect(x: 0, y: 0, width: 260, height: attachedHost.bounds.height)
        attachedHost.addSubview(panel.webView)
        let attachedInspectorView = WKInspectorProbeView(
            frame: NSRect(x: 260, y: 0, width: 260, height: attachedHost.bounds.height)
        )
        attachedHost.addSubview(attachedInspectorView)
        window.makeKeyAndOrderFront(nil)
        window.displayIfNeeded()
        #expect(panel.debugDeveloperToolsStateSummary().contains("presentation=detached"))
        // WebKit can open DevTools directly in its saved attached/bottom dock
        // configuration: no detached inspector window ever exists, so the
        // detached-window close resolver never runs. The UI sync must adopt
        // the attached classification or attached manual-close detection
        // stays disabled and preserved visible intent can resurrect an
        // inspector the user explicitly closed.
        #expect(panel.showDeveloperTools())
        #expect(panel.debugDeveloperToolsStateSummary().contains("presentation=attached"), "Direct attached open must adopt the attached presentation classification")
    }
    @Test
    func nilTargetControllerCloseActionDoesNotCloseDetachedInspector() {
        AppDelegate.installWindowResponderSwizzlesForTesting()
        guard let appDelegate = AppDelegate.shared else {
            Issue.record("Expected AppDelegate.shared")
            return
        }

        let windowId = appDelegate.createMainWindow()
        guard let mainWindow = NSApp.windows.first(where: { $0.identifier?.rawValue == "bmux.main.\(windowId.uuidString)" }) else {
            Issue.record("Expected main window with browser panel")
            return
        }
        appDelegate.suppressClosedWindowHistoryForTesting(windowId: windowId)
        defer {
            mainWindow.contentView = nil
            mainWindow.orderOut(nil)
            mainWindow.close()
        }
        guard let manager = appDelegate.tabManagerFor(windowId: windowId) else {
            Issue.record("Expected main window with browser panel")
            return
        }
        defer { BrowserInspectorTestFixture.tearDownPanels(manager: manager) }
        guard let workspace = manager.selectedWorkspace,
              let browserPanelId = manager.openBrowser(inWorkspace: workspace.id, preferSplitRight: true),
              let browserPanel = workspace.browserPanel(for: browserPanelId) else {
            Issue.record("Expected main window with browser panel")
            return
        }

        let fixture = BrowserInspectorTestFixture(panel: browserPanel)
        let inspector = fixture.inspector
        if browserPanel.webView.superview == nil {
            browserPanel.webView.frame = mainWindow.contentView?.bounds ?? .zero
            mainWindow.contentView?.addSubview(browserPanel.webView)
        }

        let inspectorWindow = fixture.makeWindow(contentRect: NSRect(x: 0, y: 0, width: 360, height: 240))
        inspectorWindow.title = "Web Inspector — example.com"
        let frontendWebView = WKInspectorProbeWebView(
            frame: inspectorWindow.contentView?.bounds ?? .zero,
            configuration: WKWebViewConfiguration()
        )
        inspectorWindow.contentView?.addSubview(frontendWebView)
        inspector.setFrontendWebView(frontendWebView)
        defer { fixture.closeWindow(inspectorWindow) }

        inspectorWindow.makeKeyAndOrderFront(nil)
        inspectorWindow.makeKey()
        #expect(browserPanel.showDeveloperTools())
        #expect(inspector.closeCount == 0)

        _ = NSApp.sendAction(NSSelectorFromString("close:"), to: nil, from: nil)

        #expect(inspector.closeCount == 0, "Nil-target controller close: actions must not be treated as detached inspector window closes")
        #expect(browserPanel.isDeveloperToolsVisible())
    }
    @Test
    func portalBindDoesNotMoveInspectorFrontendOutOfDetachedWindowOwner() {
        let fixture = BrowserInspectorTestFixture()
        let panel = fixture.panel
        defer { fixture.closePanel() }
        let window = fixture.makeWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 320))
        defer {
            fixture.closeWindow(window)
        }
        guard let contentView = window.contentView else {
            Issue.record("Expected content view")
            return
        }

        let sourceSlot = WindowBrowserSlotView(frame: NSRect(x: 20, y: 20, width: 220, height: 180))
        contentView.addSubview(sourceSlot)
        let anchor = NSView(frame: NSRect(x: 280, y: 20, width: 220, height: 180))
        contentView.addSubview(anchor)

        panel.webView.frame = sourceSlot.bounds
        sourceSlot.addSubview(panel.webView)
        let inspectorView = WKInspectorProbeView(
            frame: NSRect(x: 0, y: 0, width: sourceSlot.bounds.width, height: 72)
        )
        sourceSlot.addSubview(inspectorView)

        window.makeKeyAndOrderFront(nil)
        window.displayIfNeeded()
        contentView.layoutSubtreeIfNeeded()

        BrowserWindowPortalRegistry.bind(webView: panel.webView, to: anchor, visibleInUI: true, zPriority: 1)
        BrowserWindowPortalRegistry.synchronizeForAnchor(anchor)

        #expect(panel.webView.superview !== sourceSlot, "The page web view should move to the portal host for this regression setup")
        #expect(inspectorView.superview === sourceSlot, "The portal must not reparent WKInspector frontend views; WebKit owns their window/controller lifecycle")
    }
    @Test
    func windowCloseClosesContainedBrowserInspectorBeforeWindowWillClose() {
        guard let appDelegate = AppDelegate.shared else {
            Issue.record("Expected AppDelegate.shared")
            return
        }

        let windowId = appDelegate.createMainWindow()
        guard let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "bmux.main.\(windowId.uuidString)" }) else {
            Issue.record("Expected main window with browser panel")
            return
        }
        appDelegate.suppressClosedWindowHistoryForTesting(windowId: windowId)
        defer {
            window.contentView = nil
            window.orderOut(nil)
            window.close()
        }
        guard let manager = appDelegate.tabManagerFor(windowId: windowId) else {
            Issue.record("Expected main window with browser panel")
            return
        }
        defer { BrowserInspectorTestFixture.tearDownPanels(manager: manager) }
        guard let workspace = manager.selectedWorkspace,
              let browserPanelId = manager.openBrowser(inWorkspace: workspace.id, preferSplitRight: true),
              let browserPanel = workspace.browserPanel(for: browserPanelId) else {
            Issue.record("Expected main window with browser panel")
            return
        }

        let fixture = BrowserInspectorTestFixture(panel: browserPanel)
        let inspector = fixture.inspector
        if browserPanel.webView.superview == nil {
            browserPanel.webView.frame = window.contentView?.bounds ?? .zero
            window.contentView?.addSubview(browserPanel.webView)
        }

        #expect(browserPanel.showDeveloperTools())
        #expect(browserPanel.isDeveloperToolsVisible())

        var closeCountObservedAtWillClose: Int?
        let observer = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: nil
        ) { _ in
            // queue:nil delivers this window's willClose synchronously inside MainActor performClose.
            MainActor.assumeIsolated {
                closeCountObservedAtWillClose = inspector.closeCount
            }
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        window.performClose(nil)

        #expect(closeCountObservedAtWillClose == 1)
        #expect(inspector.closeCount == 1)
        #expect(!browserPanel.isDeveloperToolsVisible())
    }
}
