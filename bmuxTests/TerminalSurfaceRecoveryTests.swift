import AppKit
import BmuxTerminal
import GhosttyKit
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

/// Runtime recovery requires completed initial creation, including asynchronous shim preparation.
@MainActor
@Suite(.serialized) struct TerminalSurfaceRecoveryTests {
#if DEBUG
    @Test(.timeLimit(.minutes(1)))
    func keyDownRecoversReleasedSurfaceWhileHostedViewIsDetached() async throws {
        try await withReadySurface { surface, view, window in
            surface.releaseSurfaceForTesting()
            try #require(surface.surface == nil)
            surface.hostedView.removeFromSuperview()
            try #require(view.window == nil)

            let surfaceID = surface.id
            let ready = NotificationCenter.default.notifications(named: .terminalSurfaceDidBecomeReady)
                .filter { ($0.object as? TerminalSurface)?.id == surfaceID }.map { _ in true }
            var readyIterator = ready.makeAsyncIterator()
            view.keyDown(with: try keyEvent(window: window))
            if surface.surface == nil { _ = await readyIterator.next() }
            #expect(surface.surface != nil,
                    "Missing-surface keyDown must recreate a detached terminal's runtime surface")
        }
    }

    @Test(.timeLimit(.minutes(1)))
    func keyDownRecoveryDoesNotRecreateClosedSurface() async throws {
        try await withReadySurface { surface, view, window in
            surface.beginPortalCloseLifecycle(reason: "test.close")
            surface.teardownSurface()
            try #require(surface.surface == nil)
            try #require(surface.portalBindingStateLabel() == "closed")
            surface.hostedView.removeFromSuperview()
            try #require(view.window == nil)

            let attempts = surface.debugRuntimeSurfaceCreateAttemptCountForTesting()
            view.keyDown(with: try keyEvent(window: window))
            #expect(surface.surface == nil,
                    "Missing-surface keyDown must not recreate a closed terminal")
            #expect(!surface.debugBackgroundSurfaceStartQueuedForTesting())
            #expect(surface.debugRuntimeSurfaceCreateAttemptCountForTesting() == attempts)
        }
    }

    private func withReadySurface(
        body: (TerminalSurface, GhosttyNSView, NSWindow) async throws -> Void
    ) async throws {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 320),
            styleMask: [.titled, .closable], backing: .buffered, defer: false)
        let surface = TerminalSurface(tabId: UUID(), context: GHOSTTY_SURFACE_CONTEXT_SPLIT,
            configTemplate: nil, workingDirectory: nil)
        defer {
            surface.beginPortalCloseLifecycle(reason: "test.cleanup")
            surface.teardownSurface()
            window.contentView = nil
            window.orderOut(nil)
        }
        let content = try #require(window.contentView)
        let host = surface.hostedView
        host.frame = content.bounds
        host.autoresizingMask = [.width, .height]
        // Subscribe before attachment, as ConfiguredCodexLaunchTests does. A fixed
        // run-loop delay could release nil and detach before the first creation.
        let surfaceID = surface.id
        let ready = NotificationCenter.default.notifications(named: .terminalSurfaceDidBecomeReady)
            .filter { ($0.object as? TerminalSurface)?.id == surfaceID }.map { _ in true }
        var readyIterator = ready.makeAsyncIterator()
        content.addSubview(host)
        content.layoutSubtreeIfNeeded()
        host.layoutSubtreeIfNeeded()
        if surface.surface == nil { _ = await readyIterator.next() }
        try #require(surface.surface != nil, "Initial runtime creation must complete before recovery setup")
        let view = try #require(host.subviews.compactMap { $0 as? NSScrollView }.first?
            .documentView?.subviews.first as? GhosttyNSView)
        try await body(surface, view, window)
    }

    private func keyEvent(window: NSWindow) throws -> NSEvent {
        try #require(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
            context: nil, characters: "a", charactersIgnoringModifiers: "a", isARepeat: false, keyCode: 0))
    }
#endif
}
