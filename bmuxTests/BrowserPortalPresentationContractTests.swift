import AppKit
import Testing
import WebKit

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@MainActor
struct BrowserPortalPresentationContractTests {
    @Test func externalSplitResizeRepaintsWithoutRenderingStateReattach() async throws {
        let window = makeWindow(width: 640, height: 360)
        let portal = WindowBrowserPortal(window: window)
        let webView = makeWebView()
        defer { tearDown(portal: portal, webView: webView, window: window) }
        let contentView = try #require(window.contentView)
        let splitView = NSSplitView(frame: contentView.bounds)
        splitView.autoresizingMask = [.width, .height]
        splitView.isVertical = true
        let leadingPane = NSView(frame: NSRect(x: 0, y: 0, width: 220, height: contentView.bounds.height))
        leadingPane.autoresizingMask = [.height]
        let trailingPane = NSView(frame: NSRect(
            x: 221, y: 0, width: contentView.bounds.width - 221, height: contentView.bounds.height
        ))
        trailingPane.autoresizingMask = [.width, .height]
        splitView.addSubview(leadingPane)
        splitView.addSubview(trailingPane)
        contentView.addSubview(splitView)
        splitView.adjustSubviews()
        let anchor = NSView(frame: trailingPane.bounds.insetBy(dx: 12, dy: 12))
        anchor.autoresizingMask = [.width, .height]
        trailingPane.addSubview(anchor)
        portal.bind(webView: webView, to: anchor, visibleInUI: true)
        contentView.layoutSubtreeIfNeeded()
        portal.synchronizeWebViewForAnchor(anchor)
        let slot = try #require(webView.superview as? WindowBrowserSlotView)
        let initialDisplayCount = webView.displayIfNeededCount
        let initialReattachCount = webView.reattachRenderingStateCount
        let initialWidth = slot.frame.width

        // The view's display stream is installed before resize. Consume the redraw at
        // the new geometry, not an earlier queued bind refresh or a run-loop delay.
        splitView.setPosition(280, ofDividerAt: 0)
        contentView.layoutSubtreeIfNeeded()
        NotificationCenter.default.post(name: NSSplitView.didResizeSubviewsNotification, object: splitView)
        let didDisplay = await webView.waitForDisplayedWidth(anchor.bounds.width, timeout: .milliseconds(250))
        #expect(didDisplay, "External split resize should deliver a redraw at the new anchor geometry")
        #expect(!slot.isHidden, "App split resize should keep the browser slot visible")
        #expect(slot.frame.width < initialWidth, "Moving the app split divider should shrink the hosted browser slot")
        #expect(abs(slot.frame.width - anchor.bounds.width) < 0.5)
        #expect(webView.displayIfNeededCount > initialDisplayCount, "External split resize should still repaint the hosted browser")
        #expect(webView.reattachRenderingStateCount == initialReattachCount, "External split resize should not trigger the WebKit reattach path")
    }

    @Test func portalRevealRefreshesWithoutFrameDeltaAndReattachesOnlyAfterHiddenHostAdoption() throws {
        let window = makeWindow(width: 500, height: 320)
        let portal = WindowBrowserPortal(window: window)
        let webView = makeWebView()
        defer { tearDown(portal: portal, webView: webView, window: window) }
        let contentView = try #require(window.contentView)
        let anchor = NSView(frame: NSRect(x: 40, y: 24, width: 220, height: 160))
        contentView.addSubview(anchor)
        portal.bind(webView: webView, to: anchor, visibleInUI: true)
        portal.synchronizeWebViewForAnchor(anchor)
        let slot = try #require(webView.superview as? WindowBrowserSlotView)
        let initialFrame = slot.frame
        let initialDisplayCount = webView.displayIfNeededCount
        let initialReattachCount = webView.reattachRenderingStateCount
        portal.updateEntryVisibility(forWebViewId: ObjectIdentifier(webView), visibleInUI: false, zPriority: 0)
        portal.synchronizeWebViewForAnchor(anchor)
        let hiddenDisplayCount = webView.displayIfNeededCount
        let hiddenReattachCount = webView.reattachRenderingStateCount
        #expect(slot.isHidden)
        #expect(!webView.browserPortalRequiresRenderingStateReattach)
        portal.updateEntryVisibility(forWebViewId: ObjectIdentifier(webView), visibleInUI: true, zPriority: 0)
        portal.synchronizeWebViewForAnchor(anchor)
        #expect(hiddenDisplayCount >= initialDisplayCount)
        #expect(hiddenReattachCount == initialReattachCount, "Hiding a portal-hosted browser should not itself trigger the WebKit reattach path")
        #expect(webView.displayIfNeededCount > hiddenDisplayCount, "Revealing an existing portal-hosted browser should refresh WebKit presentation immediately")
        #expect(webView.reattachRenderingStateCount == hiddenReattachCount, "Ordinary portal visibility changes preserve WebKit lifecycle state")
        #expect(!slot.isHidden)
        #expect(slot.frame == initialFrame)

        // A web view adopted from a hidden prewarm host explicitly requires the
        // lifecycle refresh; ordinary tab visibility must not fire these selectors.
        portal.updateEntryVisibility(forWebViewId: ObjectIdentifier(webView), visibleInUI: false, zPriority: 0)
        portal.synchronizeWebViewForAnchor(anchor)
        webView.browserPortalPrepareForHiddenHostAdoption()
        #expect(webView.browserPortalRequiresRenderingStateReattach)
        portal.bind(webView: webView, to: anchor, visibleInUI: true)
        portal.synchronizeWebViewForAnchor(anchor)
        #expect(webView.reattachRenderingStateCount > hiddenReattachCount)
        #expect(!webView.browserPortalRequiresRenderingStateReattach)
        #expect(!slot.isHidden)
        #expect(slot.frame == initialFrame)
    }

    @Test func transientAnchorRemovalPreservesVisibleSlotUntilRebind() throws {
        let window = makeWindow(width: 500, height: 320)
        let portal = WindowBrowserPortal(window: window)
        let webView = makeWebView()
        defer { tearDown(portal: portal, webView: webView, window: window) }
        let contentView = try #require(window.contentView)
        let anchorFrame = NSRect(x: 40, y: 24, width: 220, height: 160)
        let anchor1 = NSView(frame: anchorFrame)
        contentView.addSubview(anchor1)
        portal.bind(webView: webView, to: anchor1, visibleInUI: true)
        portal.synchronizeWebViewForAnchor(anchor1)
        let slot = try #require(webView.superview as? WindowBrowserSlotView)
        let initialFrame = slot.frame
        anchor1.removeFromSuperview()
        portal.synchronizeWebViewForAnchor(anchor1)
        #expect(webView.superview === slot, "Visible browser entries should not detach during transient anchor removal")
        #expect(!slot.isHidden, "Transient reparent recovery preserves the visible browser slot until rebind")
        #expect(slot.frame == initialFrame)
        #expect(portal.debugEntryCount() == 1)
        let displayCountBeforeRebind = webView.displayIfNeededCount
        let anchor2 = NSView(frame: anchorFrame)
        contentView.addSubview(anchor2)
        portal.bind(webView: webView, to: anchor2, visibleInUI: true)
        portal.synchronizeWebViewForAnchor(anchor2)
        #expect(webView.superview === slot, "Rebinding after transient anchor removal should reuse the existing portal slot")
        #expect(!slot.isHidden)
        #expect(slot.frame == initialFrame)
        #expect(portal.debugEntryCount() == 1)
        #expect(webView.displayIfNeededCount > displayCountBeforeRebind, "Anchor rebinds should refresh hosted browser presentation even when geometry is unchanged")
    }

    private func makeWindow(width: CGFloat, height: CGFloat) -> NSWindow {
        _ = NSApplication.shared
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.titled, .closable], backing: .buffered, defer: false
        )
        window.isReleasedWhenClosed = false
        return window
    }

    private func makeWebView() -> BrowserPortalTrackingWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        return BrowserPortalTrackingWebView(frame: .zero, configuration: configuration)
    }

    private func tearDown(portal: WindowBrowserPortal, webView: BrowserPortalTrackingWebView, window: NSWindow) {
        webView.finishObservingDisplays()
        portal.tearDown()
        window.contentView = nil
        window.close()
    }
}
