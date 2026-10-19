import AppKit
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@MainActor
@Suite
struct VisibleTerminalResponderRepairTests {
#if DEBUG
    @Test
    func windowSendEventRepairsVisibleSameWindowResponderDriftForFocusedTerminalTyping() async throws {
        try await withinAllowance(.seconds(30)) {
            try await exerciseVisibleResponderRepair()
        }
    }

    private func exerciseVisibleResponderRepair() async throws {
        AppDelegate.installWindowResponderSwizzlesForTesting()
        let appDelegate = try #require(AppDelegate.shared)
        let windowID = appDelegate.createMainWindow(initialPrimaryTab: .terminal)
        defer { close(windowID: windowID, appDelegate: appDelegate) }
        let window = try #require(NSApp.windows.first {
            $0.identifier?.rawValue == "bmux.main.\(windowID.uuidString)"
        })
        window.isReleasedWhenClosed = false
        let manager = try #require(appDelegate.tabManagerFor(windowId: windowID))
        let workspace = try #require(manager.selectedWorkspace)
        let panelID = try #require(workspace.focusedPanelId)
        let panel = try #require(workspace.terminalPanel(for: panelID))
        let hostedView = panel.hostedView
        let terminalView = hostedView.surfaceView
        let readiness = TerminalRuntimeReadinessFixture(surface: panel.surface)
        defer { readiness.close() }
        window.makeKeyAndOrderFront(nil)
        window.displayIfNeeded()
        hostedView.setVisibleInUI(true)
        hostedView.setActive(true)
        if !panel.surface.hasLiveSurface {
            try await readiness.wait(timeout: .seconds(3))
        }
        try Task.checkCancellation()
        #expect(panel.surface.hasLiveSurface, "Expected a live terminal surface")

        let initialFocus = TerminalFocusDeliveryFixture(surface: panel.surface)
        defer { initialFocus.close() }
        hostedView.moveFocus()
        if !hostedView.isSurfaceViewFirstResponder() {
            try await initialFocus.wait(timeout: .seconds(1))
        }
        #expect(hostedView.isSurfaceViewFirstResponder(),
                "Expected terminal surface to own first responder before repair test")

        let strayView = FocusableView(frame: NSRect(x: 0, y: 0, width: 24, height: 24))
        (window.contentView?.superview ?? window.contentView)?.addSubview(strayView)
        defer { strayView.removeFromSuperview() }
        #expect(strayView.window === window, "Expected a simulated same-window responder")
        #expect(window.makeFirstResponder(strayView), "Expected test to install a visible wrong first responder")
        #expect(window.firstResponder === strayView, "Expected real same-window responder drift before repair")
        #expect(!hostedView.responderMatchesPreferredKeyboardFocus(strayView),
                "Expected the simulated responder to disagree with the focused terminal")
        #expect(!hostedView.isSurfaceViewFirstResponder(),
                "Expected terminal surface to lose first responder before repaired typing")
        let event = try #require(NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber, context: nil, characters: "a",
            charactersIgnoringModifiers: "a", isARepeat: false, keyCode: 0
        ))
        let repairedFocus = TerminalFocusDeliveryFixture(surface: panel.surface)
        defer { repairedFocus.close() }
        // Global probes exist only during synchronous native dispatch, never across a wait.
        try #require(!KeyboardShortcutRecorderActivity.isAnyRecorderActive,
                     "Expected no shortcut recorder to own the typing event")
        let result = send(event, to: window, appDelegate: appDelegate, strayView: strayView)
        if !hostedView.isSurfaceViewFirstResponder() || window.firstResponder !== terminalView {
            try await repairedFocus.wait(timeout: .seconds(1))
        }
        try Task.checkCancellation()
        #expect(hostedView.isSurfaceViewFirstResponder(),
                "Typing should repair first responder back to the focused terminal surface")
        #expect(window.firstResponder === terminalView,
                "Typing repair should restore the Ghostty surface view as first responder")
        #expect(result.repairs == 1, "window.sendEvent should run the focused terminal repair path")
        #expect(result.responder === strayView, "Repair should evaluate the simulated wrong same-window responder")
        #expect(result.keys > 0, "Typing repair should forward the keyDown into Ghostty")
    }

    private func send(
        _ event: NSEvent, to window: NSWindow, appDelegate: AppDelegate, strayView: NSView
    ) -> (repairs: Int, responder: NSResponder?, keys: Int) {
        let previousResponder = debugShortcutRoutingFocusedWindowOverrideForTesting.keyRepairFirstResponder
        let previousRepair = appDelegate.debugFocusedTerminalKeyRepairObserverForTesting
        let previousKey = GhosttyNSView.debugGhosttySurfaceKeyEventObserver
        defer {
            appDelegate.debugSetShortcutRoutingKeyRepairFirstResponderForTesting(previousResponder)
            appDelegate.debugFocusedTerminalKeyRepairObserverForTesting = previousRepair
            GhosttyNSView.debugGhosttySurfaceKeyEventObserver = previousKey
        }
        var repairs = 0
        var responder: NSResponder?
        var keys = 0
        appDelegate.debugSetShortcutRoutingKeyRepairFirstResponderForTesting(strayView)
        appDelegate.debugFocusedTerminalKeyRepairObserverForTesting = { window, event, candidate in
            previousRepair?(window, event, candidate)
            guard event.keyCode == 0 else { return }
            repairs += 1
            responder = candidate
        }
        GhosttyNSView.debugGhosttySurfaceKeyEventObserver = { event in
            previousKey?(event)
            if event.action == GHOSTTY_ACTION_PRESS, event.keycode == 0 { keys += 1 }
        }
        window.sendEvent(event)
        return (repairs, responder, keys)
    }

    private func close(windowID: UUID, appDelegate: AppDelegate) {
        guard let window = NSApp.windows.first(where: {
            $0.identifier?.rawValue == "bmux.main.\(windowID.uuidString)"
        }) else { return }
        let previous = appDelegate.debugCloseMainWindowConfirmationHandler
        appDelegate.debugCloseMainWindowConfirmationHandler = { _ in true }
        defer { appDelegate.debugCloseMainWindowConfirmationHandler = previous }
        window.animationBehavior = .none
        window.orderOut(nil)
        window.close()
    }

    private func withinAllowance(
        _ timeout: Duration, operation: @escaping @MainActor @Sendable () async throws -> Void
    ) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        try await withThrowingTaskGroup(of: Void.self) { group in
            defer { group.cancelAll() }
            group.addTask { try await operation() }
            group.addTask {
                // Preserve the original XCTest 30-second outer failure allowance, with joined cancellation.
                try await clock.sleep(until: deadline)
                throw Failure.testAllowanceExceeded
            }
            _ = try await group.next()
        }
        try Task.checkCancellation()
    }

    private final class FocusableView: NSView {
        override var acceptsFirstResponder: Bool { true }
    }

    private enum Failure: Error { case testAllowanceExceeded }
#endif
}
