import AppKit
import BmuxTerminal
import GhosttyKit
import Testing
@testable import bmux_DEV

@MainActor
struct TerminalSearchOverlayLifecycleTests {
    @Test func escapeDismissingFindOverlayDoesNotLeakEscapeKeyUpToTerminal() async throws {
        _ = NSApplication.shared
        let surface = makeSurface()
        let hostedView = surface.hostedView
        let window = makeWindow(width: 360, height: 240)
        let readiness = TerminalRuntimeReadinessFixture(surface: surface)
        defer {
            readiness.close()
            close(surface: surface, window: window)
        }
        let contentView = try #require(window.contentView)
        hostedView.frame = contentView.bounds
        hostedView.autoresizingMask = [.width, .height]
        contentView.addSubview(hostedView)
        window.makeKeyAndOrderFront(nil)
        window.displayIfNeeded()
        contentView.layoutSubtreeIfNeeded()
        hostedView.setVisibleInUI(true)
        hostedView.setActive(true)
        // Native runtime setup includes asynchronous bundled-shim preparation, separate from overlay delivery.
        if !surface.hasLiveSurface { try await readiness.wait(timeout: .seconds(3)) }
        try #require(surface.hasLiveSurface)

        let searchState = TerminalSurface.SearchState(needle: "")
        surface.searchState = searchState
        try await deliverQueuedMutation(within: .milliseconds(50)) {
            hostedView.setSearchOverlay(searchState: searchState)
        }
        hostedView.layoutSubtreeIfNeeded()
        let overlay = try #require(hostedView.debugSearchOverlayHostingViewForTesting())
        overlay.layoutSubtreeIfNeeded()
        let searchField = try #require(findEditableTextField(in: hostedView))
        try #require(window.makeFirstResponder(searchField))
        let editor = try #require(searchField.currentEditor())
        try #require(window.firstResponder === searchField || window.firstResponder === editor)

        let escapeKeyUpCount = try dispatchEscape(window: window)
        try await deliverQueuedMutation(within: .milliseconds(50)) {}
        #expect(surface.searchState == nil, "Escape should dismiss find overlay when search text is empty")
        #expect(escapeKeyUpCount == 0, "Escape used to dismiss find must not reach the terminal key-up path")
    }

    @Test func searchOverlaySurvivesPortalRebindDuringSplitLikeChurn() async throws {
        let window = makeWindow(width: 480, height: 320)
        let portal = WindowTerminalPortal(window: window)
        let surface = makeSurface()
        defer {
            portal.tearDown()
            close(surface: surface, window: window)
        }
        let contentView = try #require(window.contentView)
        let anchorA = NSView(frame: NSRect(x: 20, y: 20, width: 180, height: 140))
        let anchorB = NSView(frame: NSRect(x: 220, y: 20, width: 180, height: 140))
        contentView.addSubview(anchorA)
        contentView.addSubview(anchorB)
        let hostedView = surface.hostedView
        try await deliverQueuedMutation(within: .milliseconds(50)) {
            hostedView.setSearchOverlay(searchState: TerminalSurface.SearchState(needle: "split"))
        }
        #expect(hostedView.debugHasSearchOverlay())
        portal.bind(hostedView: hostedView, to: anchorA, visibleInUI: true)
        #expect(hostedView.debugHasSearchOverlay())
        portal.bind(hostedView: hostedView, to: anchorB, visibleInUI: true)
        #expect(hostedView.debugHasSearchOverlay(), "Split-like anchor churn must not unmount terminal search")
    }

    @Test func searchOverlaySurvivesPortalVisibilityToggleDuringWorkspaceSwitchLikeChurn() async throws {
        let window = makeWindow(width: 480, height: 320)
        let portal = WindowTerminalPortal(window: window)
        let surface = makeSurface()
        defer {
            portal.tearDown()
            close(surface: surface, window: window)
        }
        let contentView = try #require(window.contentView)
        let anchor = NSView(frame: NSRect(x: 40, y: 40, width: 220, height: 160))
        contentView.addSubview(anchor)
        let hostedView = surface.hostedView
        try await deliverQueuedMutation(within: .milliseconds(50)) {
            hostedView.setSearchOverlay(searchState: TerminalSurface.SearchState(needle: "workspace"))
        }
        #expect(hostedView.debugHasSearchOverlay())
        portal.bind(hostedView: hostedView, to: anchor, visibleInUI: true)
        #expect(hostedView.debugHasSearchOverlay())
        portal.bind(hostedView: hostedView, to: anchor, visibleInUI: false)
        #expect(hostedView.debugHasSearchOverlay())
        portal.bind(hostedView: hostedView, to: anchor, visibleInUI: true)
        #expect(
            hostedView.debugHasSearchOverlay(),
            "Workspace-switch-like visibility toggles should not unmount terminal search overlay"
        )
    }

    private func makeSurface() -> TerminalSurface {
        TerminalSurface(
            tabId: UUID(), context: GHOSTTY_SURFACE_CONTEXT_SPLIT,
            configTemplate: nil, workingDirectory: nil, manualIO: true, manualInputHandler: { _ in }
        )
    }

    private func makeWindow(width: CGFloat, height: CGFloat) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.titled, .closable], backing: .buffered, defer: false
        )
        window.isReleasedWhenClosed = false
        return window
    }

    private func close(surface: TerminalSurface, window: NSWindow) {
        surface.beginPortalCloseLifecycle(reason: "search-overlay-lifecycle-test.cleanup")
        surface.releaseSurfaceForTesting()
        surface.teardownSurface()
        surface.hostedView.removeFromSuperview()
        window.contentView = nil
        window.orderOut(nil)
        window.close()
    }

    private func deliverQueuedMutation(within duration: Duration, action: @MainActor () -> Void) async throws {
        let deadline = ContinuousClock.now.advanced(by: duration)
        let (events, signal) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        defer { signal.finish() }
        action()
        // The legacy owner enqueues one mutation; this observes its FIFO delivery.
        DispatchQueue.main.async { signal.yield(()); signal.finish() }
        try await withThrowingTaskGroup(of: Void.self) { group in
            defer { group.cancelAll() }
            group.addTask {
                for await _ in events { return }
                throw CancellationError()
            }
            group.addTask {
                // Preserve the original 50ms phase cap without a settling delay.
                try await ContinuousClock().sleep(until: deadline)
                throw Failure.deliveryTimedOut
            }
            _ = try await group.next()
        }
    }

    private func dispatchEscape(window: NSWindow) throws -> Int {
        var escapeKeyUpCount = 0
        let previousObserver = GhosttyNSView.debugGhosttySurfaceKeyEventObserver
        defer { GhosttyNSView.debugGhosttySurfaceKeyEventObserver = previousObserver }
        GhosttyNSView.debugGhosttySurfaceKeyEventObserver = { keyEvent in
            guard keyEvent.action == GHOSTTY_ACTION_RELEASE, keyEvent.keycode == 53 else { return }
            escapeKeyUpCount += 1
        }
        let timestamp = ProcessInfo.processInfo.systemUptime
        let down = try #require(NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: [], timestamp: timestamp,
            windowNumber: window.windowNumber, context: nil, characters: "\u{1b}",
            charactersIgnoringModifiers: "\u{1b}", isARepeat: false, keyCode: 53
        ))
        let up = try #require(NSEvent.keyEvent(
            with: .keyUp, location: .zero, modifierFlags: [], timestamp: timestamp + 0.001,
            windowNumber: window.windowNumber, context: nil, characters: "\u{1b}",
            charactersIgnoringModifiers: "\u{1b}", isARepeat: false, keyCode: 53
        ))
        NSApp.sendEvent(down)
        NSApp.sendEvent(up)
        let dismissalKeyUpCount = escapeKeyUpCount
        let subsequentUp = try #require(NSEvent.keyEvent(
            with: .keyUp, location: .zero, modifierFlags: [], timestamp: timestamp + 0.002,
            windowNumber: window.windowNumber, context: nil, characters: "\u{1b}",
            charactersIgnoringModifiers: "\u{1b}", isARepeat: false, keyCode: 53
        ))
        // The first release must consume suppression; this later release proves delivery is observable.
        NSApp.sendEvent(subsequentUp)
        #expect(escapeKeyUpCount == 1, "A subsequent Escape release must reach the terminal after suppression clears")
        return dismissalKeyUpCount
    }

    private func findEditableTextField(in view: NSView) -> NSTextField? {
        if let field = view as? NSTextField, field.isEditable { return field }
        for subview in view.subviews {
            if let field = findEditableTextField(in: subview) { return field }
        }
        return nil
    }

    private enum Failure: Error { case deliveryTimedOut }
}
