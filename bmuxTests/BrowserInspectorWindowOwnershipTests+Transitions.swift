import AppKit
import SwiftUI
import WebKit
import Bonsplit
import Testing
@testable import bmux_DEV

@MainActor
extension BrowserInspectorWindowOwnershipTests {
    @Test
    func repeatedDevToolsRevealDoesNotForceWebKitAttach() async throws {
        let fixture = BrowserInspectorTestFixture()
        let panel = fixture.panel
        let inspector = fixture.inspector
        defer { fixture.closePanel() }
        let window = fixture.makeWindow(contentRect: NSRect(x: 0, y: 0, width: 360, height: 240))
        defer { fixture.closeWindow(window) }

        let host = NSView(frame: window.contentView?.bounds ?? .zero)
        window.contentView?.addSubview(host)
        panel.webView.frame = NSRect(x: 0, y: 0, width: 180, height: host.bounds.height)
        host.addSubview(panel.webView)
        let inspectorView = WKInspectorProbeView(
            frame: NSRect(x: 180, y: 0, width: 180, height: host.bounds.height)
        )
        host.addSubview(inspectorView)
        let frontendWebView = WKInspectorProbeWebView(
            frame: inspectorView.bounds,
            configuration: WKWebViewConfiguration()
        )
        inspectorView.addSubview(frontendWebView)
        inspector.setFrontendWebView(frontendWebView)
        window.makeKeyAndOrderFront(nil)
        window.displayIfNeeded()

        let observation1 = panel.debugDeveloperToolsLifecycleChanges()
        #expect(panel.showDeveloperTools())
        #expect(panel.isDeveloperToolsVisible())
        try await fixture.waitForTransitions(observation: observation1) {
            panel.isDeveloperToolsVisible() &&
                inspector.showCount == 1
        }
        #expect(inspector.attachCount == 0)
        #expect(!(inspector.isAttached()))

        let observation2 = panel.debugDeveloperToolsLifecycleChanges()
        #expect(panel.hideDeveloperTools())
        try await fixture.waitForTransitions(observation: observation2) {
            !panel.isDeveloperToolsVisible() &&
                inspector.closeCount == 1
        }
        #expect(!(panel.isDeveloperToolsVisible()))
        #expect(inspector.closeCount == 1)

        let observation3 = panel.debugDeveloperToolsLifecycleChanges()
        #expect(panel.showDeveloperTools())
        try await fixture.waitForTransitions(observation: observation3) {
            panel.isDeveloperToolsVisible() &&
                inspector.showCount == 2
        }
        #expect(panel.isDeveloperToolsVisible(), "DevTools must reopen after an explicit close without remounting through WebKit's attached-inspector path")
        #expect(inspector.attachCount == 0, "Repeated DevTools open/close cycles must not call WebKit's private attach selector")
        #expect(inspector.showCount == 2)
    }

    @Test
    func detachedInspectorWillCloseDuringDockBackAdoptsAttachedInspector() async throws {
        let fixture = BrowserInspectorTestFixture()
        let panel = fixture.panel
        let inspector = fixture.inspector
        defer { fixture.closePanel() }
        let mainWindow = fixture.makeWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 320))
        let inspectorWindow = fixture.makeWindow(contentRect: NSRect(x: 0, y: 0, width: 360, height: 240))
        inspectorWindow.isReleasedWhenClosed = false
        defer {
            fixture.closeWindow(inspectorWindow)
            fixture.closeWindow(mainWindow)
        }
        guard let mainContentView = mainWindow.contentView,
              let inspectorContentView = inspectorWindow.contentView else {
            Issue.record("Expected test windows to have content views")
            return
        }
        let attachedHost = NSView(frame: mainContentView.bounds)
        mainContentView.addSubview(attachedHost)
        panel.webView.frame = NSRect(x: 0, y: 0, width: 260, height: attachedHost.bounds.height)
        attachedHost.addSubview(panel.webView)
        let attachedInspectorView = WKInspectorProbeView(
            frame: NSRect(x: 260, y: 0, width: 260, height: attachedHost.bounds.height)
        )
        attachedHost.addSubview(attachedInspectorView)
        inspectorWindow.title = "Web Inspector — example.com"
        let frontendWebView = WKInspectorProbeWebView(
            frame: inspectorContentView.bounds,
            configuration: WKWebViewConfiguration()
        )
        inspectorContentView.addSubview(frontendWebView)
        inspector.setFrontendWebView(frontendWebView)
        mainWindow.makeKeyAndOrderFront(nil)
        inspectorWindow.makeKeyAndOrderFront(nil)
        mainWindow.displayIfNeeded()
        inspectorWindow.displayIfNeeded()
        #expect(!(panel.ownsDetachedDeveloperToolsWindow(mainWindow)), "A bmux/browser host window with an attached inspector frontend must not be treated as a detached inspector close target")
        let observation = panel.debugDeveloperToolsLifecycleChanges()
        #expect(panel.showDeveloperTools())
        #expect(panel.isDeveloperToolsVisible())
        #expect(inspector.closeCount == 0)
        inspectorWindow.close()
        frontendWebView.removeFromSuperview()
        frontendWebView.frame = attachedInspectorView.bounds
        attachedInspectorView.addSubview(frontendWebView)
        #expect(inspector.closeCount == 0, "Detached inspector willClose during redock must wait for WebKit's final layout before deciding whether to close _inspector")
        #expect(panel.isDeveloperToolsVisible())
        try await fixture.waitForTransitions(observation: observation) {
            panel.isDeveloperToolsVisible() &&
                panel.preferredDeveloperToolsVisible &&
                inspector.closeCount == 0
        }
        #expect(inspector.closeCount == 0, "Docking Web Inspector back into the page should adopt WebKit's attached layout instead of closing _inspector")
        #expect(panel.isDeveloperToolsVisible())
        #expect(panel.preferredDeveloperToolsVisible)
        #expect(frontendWebView.evaluatedJavaScript.joined(separator: "\n").contains("const detachedFromHostWindow = false;"), "Adopting a WebKit-initiated redock must re-run dock-control normalization in attached mode")
    }
    @Test
    func detachedInspectorWindowWillCloseWaitsForManualCloseState() async throws {
        let fixture = BrowserInspectorTestFixture()
        let panel = fixture.panel
        let inspector = fixture.inspector
        defer { fixture.closePanel() }
        let window = fixture.makeWindow(contentRect: NSRect(x: 0, y: 0, width: 360, height: 240))
        window.title = "Web Inspector — example.com"
        let frontendWebView = WKWebView(frame: window.contentView?.bounds ?? .zero)
        window.contentView?.addSubview(frontendWebView)
        window.contentView?.addSubview(WKInspectorProbeView(frame: window.contentView?.bounds ?? .zero))
        inspector.setFrontendWebView(frontendWebView)
        defer { fixture.closeWindow(window) }
        let observation = panel.debugDeveloperToolsLifecycleChanges()
        defer { panel.debugRemoveDeveloperToolsLifecycleObserver(observation.id) }

        window.makeKeyAndOrderFront(nil)
        #expect(panel.showDeveloperTools())
        #expect(panel.isDeveloperToolsVisible())
        #expect(inspector.closeCount == 0)

        window.close()

        #expect(inspector.closeCount == 0,
                "A raw detached Web Inspector willClose can be WebKit's redock path, so bmux must not synchronously close _inspector before WebKit reports the final state")
        #expect(panel.isDeveloperToolsVisible())
        #expect(!window.isVisible)
        #expect(NSApp.windows.contains { $0 === window })

        inspector.close()
        try await fixture.waitForTransitions(observation: observation) {
            inspector.closeCount == 1 &&
                !panel.isDeveloperToolsVisible() &&
                !panel.preferredDeveloperToolsVisible
        }

        #expect(inspector.closeCount == 1)
        #expect(!panel.isDeveloperToolsVisible())
        #expect(!panel.preferredDeveloperToolsVisible)
    }

}
