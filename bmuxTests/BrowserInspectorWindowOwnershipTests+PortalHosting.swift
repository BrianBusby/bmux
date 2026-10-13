import AppKit
import SwiftUI
import WebKit
import Bonsplit
import Testing
@testable import bmux_DEV

@MainActor
extension BrowserInspectorWindowOwnershipTests {
    @Test
    func webViewDismantleKeepsPortalHostedWebViewAttachedIndependentOfDeveloperToolsIntent() async throws {
        let fixture = BrowserInspectorTestFixture()
        let panel = fixture.panel
        defer { fixture.closePanel() }
        let paneId = PaneID(id: UUID())
        #expect(panel.showDeveloperTools())

        let window = fixture.makeWindow(contentRect: NSRect(x: 0, y: 0, width: 320, height: 240))
        defer { fixture.closeWindow(window) }
        let anchor = NSView(frame: NSRect(x: 30, y: 30, width: 180, height: 140))
        window.contentView?.addSubview(anchor)
        window.makeKeyAndOrderFront(nil)
        window.displayIfNeeded()
        window.contentView?.layoutSubtreeIfNeeded()

        BrowserWindowPortalRegistry.bind(webView: panel.webView, to: anchor, visibleInUI: true, zPriority: 1)
        BrowserWindowPortalRegistry.synchronizeForAnchor(anchor)
        #expect(panel.webView.superview != nil)

        let representable = WebViewRepresentable(
            panel: panel,
            paneId: paneId,
            shouldAttachWebView: true,
            useLocalInlineHosting: false,
            shouldFocusWebView: false,
            isPanelFocused: true,
            portalZPriority: 0,
            paneDropZone: nil,
            searchOverlay: nil,
            omnibarSuggestions: nil,
            paneTopChromeHeight: 0
        )
        let coordinator = representable.makeCoordinator()
        coordinator.webView = panel.webView
        WebViewRepresentable.dismantleNSView(anchor, coordinator: coordinator)

        #expect(panel.webView.superview != nil)
    }

    @Test
    func webViewDismantleKeepsPortalHostedWebViewAttachedWhenDeveloperToolsIntentIsHidden() async throws {
        let fixture = BrowserInspectorTestFixture()
        let panel = fixture.panel
        defer { fixture.closePanel() }
        let paneId = PaneID(id: UUID())

        let window = fixture.makeWindow(contentRect: NSRect(x: 0, y: 0, width: 320, height: 240))
        defer { fixture.closeWindow(window) }
        let anchor = NSView(frame: NSRect(x: 20, y: 20, width: 200, height: 150))
        window.contentView?.addSubview(anchor)
        window.makeKeyAndOrderFront(nil)
        window.displayIfNeeded()
        window.contentView?.layoutSubtreeIfNeeded()

        BrowserWindowPortalRegistry.bind(webView: panel.webView, to: anchor, visibleInUI: true, zPriority: 1)
        BrowserWindowPortalRegistry.synchronizeForAnchor(anchor)
        #expect(panel.webView.superview != nil)

        let representable = WebViewRepresentable(
            panel: panel,
            paneId: paneId,
            shouldAttachWebView: true,
            useLocalInlineHosting: false,
            shouldFocusWebView: false,
            isPanelFocused: true,
            portalZPriority: 0,
            paneDropZone: nil,
            searchOverlay: nil,
            omnibarSuggestions: nil,
            paneTopChromeHeight: 0
        )
        let coordinator = representable.makeCoordinator()
        coordinator.webView = panel.webView
        WebViewRepresentable.dismantleNSView(anchor, coordinator: coordinator)

        #expect(panel.webView.superview != nil)
    }

    @Test
    func portalBindDoesNotMoveTransferRootContainingInspectorFrontend() async throws {
        let fixture = BrowserInspectorTestFixture()
        let panel = fixture.panel
        defer { fixture.closePanel() }
        let window = fixture.makeWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 320))
        defer { fixture.closeWindow(window) }
        guard let contentView = window.contentView else {
            Issue.record("Expected content view")
            return
        }

        let sourceSlot = WindowBrowserSlotView(frame: NSRect(x: 20, y: 20, width: 220, height: 180))
        contentView.addSubview(sourceSlot)
        let anchor = NSView(frame: NSRect(x: 280, y: 20, width: 220, height: 180))
        contentView.addSubview(anchor)

        let webKitWrapper = WKTransferWrapperView(frame: sourceSlot.bounds)
        sourceSlot.addSubview(webKitWrapper)
        panel.webView.frame = webKitWrapper.bounds
        webKitWrapper.addSubview(panel.webView)
        let inspectorView = WKInspectorProbeView(
            frame: NSRect(x: 0, y: 0, width: webKitWrapper.bounds.width, height: 72)
        )
        webKitWrapper.addSubview(inspectorView)

        window.makeKeyAndOrderFront(nil)
        window.displayIfNeeded()
        contentView.layoutSubtreeIfNeeded()

        BrowserWindowPortalRegistry.bind(webView: panel.webView, to: anchor, visibleInUI: true, zPriority: 1)
        BrowserWindowPortalRegistry.synchronizeForAnchor(anchor)

        #expect(!(panel.webView.superview === webKitWrapper), "The page web view should still move to the portal host")
        #expect(inspectorView.superview === webKitWrapper, "The portal must not move a direct transfer root that also contains WebKit's inspector frontend")
    }

    @Test
    func portalRepairsBottomDockedInspectorLayoutWithDirectInspectorChild() async throws {
        let fixture = BrowserInspectorTestFixture()
        let panel = fixture.panel
        defer { fixture.closePanel() }
        let window = fixture.makeWindow(contentRect: NSRect(x: 0, y: 0, width: 360, height: 240))
        defer { fixture.closeWindow(window) }
        guard let contentView = window.contentView else {
            Issue.record("Expected content view")
            return
        }

        let anchor = NSView(frame: contentView.bounds)
        anchor.autoresizingMask = [.width, .height]
        contentView.addSubview(anchor)
        window.makeKeyAndOrderFront(nil)
        window.displayIfNeeded()
        contentView.layoutSubtreeIfNeeded()

        BrowserWindowPortalRegistry.bind(webView: panel.webView, to: anchor, visibleInUI: true, zPriority: 1)
        BrowserWindowPortalRegistry.synchronizeForAnchor(anchor)
        guard let slot = panel.webView.superview as? WindowBrowserSlotView else {
            Issue.record("Expected portal slot")
            return
        }

        let inspectorHeight: CGFloat = 168
        let pageHeight = slot.bounds.height - inspectorHeight
        let inspectorView = WKInspectorProbeView(
            frame: NSRect(x: 0, y: 0, width: slot.bounds.width, height: inspectorHeight)
        )
        inspectorView.autoresizingMask = [.width]
        slot.addSubview(inspectorView, positioned: .below, relativeTo: panel.webView)
        panel.webView.frame = NSRect(
            x: 0,
            y: slot.bounds.maxY,
            width: slot.bounds.width,
            height: pageHeight
        )

        BrowserWindowPortalRegistry.refresh(webView: panel.webView, reason: "test.bottomDockDirectInspector")

        #expect(inspectorView.superview === slot)
        #expect(abs((panel.webView.frame.minX) - (0)) <= 0.5)
        #expect(abs((panel.webView.frame.minY) - (inspectorHeight)) <= 0.5)
        #expect(abs((panel.webView.frame.width) - (slot.bounds.width)) <= 0.5)
        #expect(abs((panel.webView.frame.height) - (pageHeight)) <= 0.5)
    }

    @Test
    func visibleReplacementLocalHostNormalizesBottomDockedInspectorFrames() async throws {
        let fixture = BrowserInspectorTestFixture()
        let panel = fixture.panel
        defer { fixture.closePanel() }
        #expect(panel.showDeveloperTools())

        let paneId = PaneID(id: UUID())
        let representable = WebViewRepresentable(
            panel: panel,
            paneId: paneId,
            shouldAttachWebView: false,
            useLocalInlineHosting: true,
            shouldFocusWebView: false,
            isPanelFocused: true,
            portalZPriority: 0,
            paneDropZone: nil,
            searchOverlay: nil,
            omnibarSuggestions: nil,
            paneTopChromeHeight: 0
        )

        let window = fixture.makeWindow(contentRect: NSRect(x: 0, y: 0, width: 360, height: 240))
        defer { fixture.closeWindow(window) }
        guard let contentView = window.contentView else {
            Issue.record("Expected content view")
            return
        }

        let narrowHosting = NSHostingView(rootView: representable)
        narrowHosting.frame = NSRect(x: 180, y: 0, width: 180, height: 240)
        contentView.addSubview(narrowHosting)

        window.makeKeyAndOrderFront(nil)
        window.displayIfNeeded()
        contentView.layoutSubtreeIfNeeded()
        narrowHosting.layoutSubtreeIfNeeded()

        guard let initialSlot = panel.webView.superview as? WindowBrowserSlotView else {
            Issue.record("Expected initial local inline slot")
            return
        }

        let inspectorView = WKInspectorProbeView(
            frame: NSRect(x: 0, y: 0, width: initialSlot.bounds.width, height: 72)
        )
        inspectorView.autoresizingMask = [.width]
        initialSlot.addSubview(inspectorView)
        panel.webView.frame = NSRect(
            x: 0,
            y: inspectorView.frame.maxY,
            width: initialSlot.bounds.width,
            height: initialSlot.bounds.height - inspectorView.frame.height
        )
        initialSlot.layoutSubtreeIfNeeded()

        let replacementHosting = NSHostingView<WebViewRepresentable>(rootView: representable)
        replacementHosting.frame = contentView.bounds
        replacementHosting.autoresizingMask = [.width, .height]
        contentView.addSubview(replacementHosting, positioned: .above, relativeTo: narrowHosting)
        contentView.layoutSubtreeIfNeeded()
        replacementHosting.layoutSubtreeIfNeeded()

        replacementHosting.rootView = representable
        contentView.layoutSubtreeIfNeeded()
        replacementHosting.layoutSubtreeIfNeeded()

        narrowHosting.removeFromSuperview()
        contentView.layoutSubtreeIfNeeded()
        replacementHosting.layoutSubtreeIfNeeded()

        guard let replacementHost = fixture.findView(WebViewRepresentable.HostContainerView.self, in: replacementHosting),
              let replacementSlot = fixture.findView(WindowBrowserSlotView.self, in: replacementHost) else {
            Issue.record("Expected replacement local inline host")
            return
        }

        guard panel.webView.superview === replacementSlot &&
                inspectorView.superview === replacementSlot else {
            Issue.record("A visible replacement local host should take over the page and DevTools companion views")
            return
        }
        #expect(abs((inspectorView.frame.minX) - (0)) <= 0.5)
        #expect(abs((inspectorView.frame.minY) - (0)) <= 0.5)
        #expect(abs((inspectorView.frame.width) - (replacementSlot.bounds.width)) <= 0.5)
        #expect(abs((inspectorView.frame.height) - (72)) <= 0.5)
        #expect(abs((panel.webView.frame.minX) - (0)) <= 0.5)
        #expect(abs((panel.webView.frame.minY) - (72)) <= 0.5)
        #expect(abs((panel.webView.frame.width) - (replacementSlot.bounds.width)) <= 0.5)
        #expect(abs((panel.webView.frame.height) - (replacementSlot.bounds.height - 72)) <= 0.5)
    }
}
