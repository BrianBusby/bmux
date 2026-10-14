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

            let readiness = TerminalRuntimeReadinessFixture(surface: surface)
            defer { readiness.close() }
            view.keyDown(with: try keyEvent(window: window))
            if surface.surface == nil { try await readiness.wait(timeout: .seconds(5)) }
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

    @Test(.timeLimit(.minutes(1)))
    func keyDownRecoveryDoesNotReplayFocusAfterResponderMovesAway() async throws {
        try await withReadySurface { surface, view, window in
            let content = try #require(window.contentView)
            let otherResponder = ForeignResponder(frame: NSRect(x: 0, y: 0, width: 40, height: 40))
            content.addSubview(otherResponder)
            #expect(window.makeFirstResponder(view))
            #expect(surface.debugDesiredFocusState(), "Focused terminal should start with desired Ghostty focus")
            surface.releaseSurfaceForTesting()
            #expect(surface.surface == nil)
            surface.hostedView.removeFromSuperview()
            #expect(view.window == nil)
            if window.firstResponder !== view {
                // Some runners clear the window responder during detach without calling the view hook.
                surface.recordExternalFocusState(false)
                #expect(!surface.debugDesiredFocusState())
            }
            let readiness = TerminalRuntimeReadinessFixture(surface: surface)
            defer { readiness.close() }
            view.keyDown(with: try keyEvent(window: window))
            #expect(window.makeFirstResponder(otherResponder))
            #expect(window.firstResponder === otherResponder)
            #expect(!surface.debugDesiredFocusState(),
                    "Responder loss must clear desired Ghostty focus before recovery completes")
            if surface.surface == nil { try await readiness.wait(timeout: .seconds(5)) }
            #expect(surface.surface != nil, "Missing-surface recovery must still recreate the runtime")
            #expect(!surface.debugDesiredFocusState(),
                    "Recovered runtime must not restore focus after the pane lost first responder")
        }
    }

    @Test(.timeLimit(.minutes(1)))
    func visibilityRestoreRefreshesSurfaceWhileTerminalIsInactive() async throws {
        try await withReadySurface { surface, _, _ in
            #expect(surface.surface != nil, "Runtime must exist before measuring visibility-restore redraws")
            surface.hostedView.setActive(false)
            surface.hostedView.setVisibleInUI(false)
            surface.resetDebugForceRefreshCount()
            surface.hostedView.setVisibleInUI(true)
            #expect(surface.debugForceRefreshCount() == 1,
                    "Restoring panel visibility must redraw even when focus recovery is inactive")
        }
    }

    @Test(.timeLimit(.minutes(1)))
    func directFirstResponderFocusRefreshesCursorStateAfterForeignResponder() async throws {
        try await withReadySurface { surface, view, window in
            let content = try #require(window.contentView)
            let otherResponder = ForeignResponder(frame: NSRect(x: 0, y: 0, width: 40, height: 40))
            content.addSubview(otherResponder)
            surface.hostedView.setVisibleInUI(true)
            surface.hostedView.setActive(true)
            #expect(surface.surface != nil, "Runtime must exist before measuring focus redraws")
            #expect(window.makeFirstResponder(view))
            #expect(window.makeFirstResponder(otherResponder))
            surface.resetDebugForceRefreshCount()
            #expect(window.makeFirstResponder(view))
            #expect(surface.debugForceRefreshCount() > 0,
                    "Returning to the terminal must immediately redraw its focused cursor")
        }
    }

    private final class ForeignResponder: NSView {
        override var acceptsFirstResponder: Bool { true }
    }

    private func withReadySurface(
        body: @MainActor (TerminalSurface, GhosttyNSView, NSWindow) async throws -> Void
    ) async throws {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 320),
            styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let surface = TerminalSurface(tabId: UUID(), context: GHOSTTY_SURFACE_CONTEXT_SPLIT,
            configTemplate: nil, workingDirectory: nil)
        defer {
            surface.beginPortalCloseLifecycle(reason: "test.cleanup")
            surface.teardownSurface()
            window.contentView = nil
            window.close()
        }
        let content = try #require(window.contentView)
        let host = surface.hostedView
        host.frame = content.bounds
        host.autoresizingMask = [.width, .height]
        // Subscribe before attachment, as ConfiguredCodexLaunchTests does. A fixed
        // run-loop delay could release nil and detach before the first creation.
        let readiness = TerminalRuntimeReadinessFixture(surface: surface)
        defer { readiness.close() }
        content.addSubview(host)
        content.layoutSubtreeIfNeeded()
        host.layoutSubtreeIfNeeded()
        if surface.surface == nil { try await readiness.wait(timeout: .seconds(3)) }
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
