import AppKit
import BmuxTerminal
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@MainActor
struct TerminalSearchResponderRepairTests {
#if DEBUG
    @Test func windowSendEventRepairsFocusedTerminalSearchTypingAfterResponderDrift() async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(30))
        try await withThrowingTaskGroup(of: Void.self) { group in
            defer { group.cancelAll() }
            group.addTask { try await exerciseSearchRepair() }
            group.addTask {
                // Preserve the original thirty-second outer allowance with joined cancellation.
                try await ContinuousClock().sleep(until: deadline)
                throw Failure.testAllowanceExceeded
            }
            _ = try await group.next()
        }
        try Task.checkCancellation()
    }

    private func exerciseSearchRepair() async throws {
        AppDelegate.installWindowResponderSwizzlesForTesting()
        let appDelegate = try #require(AppDelegate.shared)
        let windowID = appDelegate.createMainWindow(initialPrimaryTab: .terminal)
        defer { close(windowID: windowID, appDelegate: appDelegate) }
        let window = try #require(appDelegate.windowForMainWindowId(windowID))
        window.isReleasedWhenClosed = false
        let manager = try #require(appDelegate.tabManagerFor(windowId: windowID))
        let workspace = try #require(manager.selectedWorkspace)
        let panelID = try #require(workspace.focusedPanelId)
        let panel = try #require(workspace.terminalPanel(for: panelID))
        let host = panel.hostedView
        let readiness = TerminalRuntimeReadinessFixture(surface: panel.surface)
        defer { readiness.close() }
        window.makeKeyAndOrderFront(nil)
        window.displayIfNeeded()
        host.setVisibleInUI(true)
        host.setActive(true)
        if !panel.surface.hasLiveSurface { try await readiness.wait(timeout: .seconds(3)) }
        try Task.checkCancellation()
        #expect(panel.surface.hasLiveSurface, "Expected a live terminal surface")
        let focus = TerminalFocusDeliveryFixture(surface: panel.surface)
        defer { focus.close() }
        host.moveFocus()
        if !host.isSurfaceViewFirstResponder() { try await focus.wait(timeout: .seconds(1)) }
        #expect(host.isSurfaceViewFirstResponder(), "Expected terminal surface to own first responder before repair test")

        let state = TerminalSurface.SearchState(needle: "")
        panel.surface.searchState = state
        let searchField = try await mountSearchField(in: host, state: state, timeout: .seconds(3))
        searchField.selectText(nil)
        _ = window.makeFirstResponder(searchField)
        #expect(owns(window.firstResponder, field: searchField),
                "Expected terminal search field to own first responder before drift")

        let stray = FocusableView(frame: NSRect(x: 0, y: 0, width: 24, height: 24))
        (window.contentView?.superview ?? window.contentView)?.addSubview(stray)
        defer { stray.removeFromSuperview() }
        #expect(stray.window === window, "Expected a simulated same-window responder")
        #expect(window.makeFirstResponder(stray), "Expected test to install a visible wrong first responder")
        #expect(window.firstResponder === stray, "Expected real same-window responder drift before repair")
        #expect(!host.responderMatchesPreferredKeyboardFocus(stray),
                "Expected the simulated responder to disagree with terminal search focus")
        #expect(!owns(window.firstResponder, field: searchField),
                "Expected terminal search field to lose first responder before repaired typing")
        let event = try #require(NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber, context: nil, characters: "a",
            charactersIgnoringModifiers: "a", isARepeat: false, keyCode: 0
        ))
        let (events, changed) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        let observer = NotificationCenter.default.addObserver(
            forName: NSControl.textDidChangeNotification, object: searchField, queue: .main
        ) { _ in changed.yield(()) }
        defer { NotificationCenter.default.removeObserver(observer); changed.finish() }
        let deadline = ContinuousClock.now.advanced(by: .seconds(1))
        try #require(!KeyboardShortcutRecorderActivity.isAnyRecorderActive,
                     "Expected no shortcut recorder to own the typing event")
        let result = send(event, to: window, appDelegate: appDelegate, stray: stray)
        if !owns(window.firstResponder, field: searchField) || searchField.stringValue != "a" {
            try await waitForDelivery(events, until: deadline)
        }
        try Task.checkCancellation()
        #expect(owns(window.firstResponder, field: searchField),
                "Typing should repair focus back to the terminal search field")
        #expect(searchField.stringValue == "a", "Typing repair should preserve the first key in the search field")
        #expect(result.count == 1, "window.sendEvent should run the focused terminal search repair path")
        #expect(result.responder === stray, "Repair should evaluate the simulated wrong same-window responder")
    }

    private func mountSearchField(
        in host: GhosttySurfaceScrollView, state: TerminalSurface.SearchState, timeout: Duration
    ) async throws -> NSTextField {
        let (events, signal) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        defer { signal.finish() }
        let deadline = ContinuousClock.now.advanced(by: timeout)
        host.setSearchOverlay(searchState: state)
        // Follow the owner's single queued overlay mutation, then perform one native layout pass.
        DispatchQueue.main.async { signal.yield(()); signal.finish() }
        try await waitForDelivery(events, until: deadline)
        host.debugSearchOverlayHostingViewForTesting()?.layoutSubtreeIfNeeded()
        host.layoutSubtreeIfNeeded()
        return try #require(editableField(in: host), "Expected mounted terminal search field")
    }

    private func waitForDelivery(_ events: AsyncStream<Void>, until deadline: ContinuousClock.Instant) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            defer { group.cancelAll() }
            group.addTask {
                for await _ in events { return }
                throw CancellationError()
            }
            group.addTask {
                // The original phase's absolute failure deadline; successful native delivery cancels it.
                try await ContinuousClock().sleep(until: deadline)
                throw Failure.deliveryTimedOut
            }
            _ = try await group.next()
        }
        try Task.checkCancellation()
    }

    private func send(
        _ event: NSEvent, to window: NSWindow, appDelegate: AppDelegate, stray: NSView
    ) -> (count: Int, responder: NSResponder?) {
        let previousResponder = debugShortcutRoutingFocusedWindowOverrideForTesting.keyRepairFirstResponder
        let previousObserver = appDelegate.debugFocusedTerminalKeyRepairObserverForTesting
        defer {
            appDelegate.debugSetShortcutRoutingKeyRepairFirstResponderForTesting(previousResponder)
            appDelegate.debugFocusedTerminalKeyRepairObserverForTesting = previousObserver
        }
        var count = 0
        var responder: NSResponder?
        appDelegate.debugSetShortcutRoutingKeyRepairFirstResponderForTesting(stray)
        appDelegate.debugFocusedTerminalKeyRepairObserverForTesting = { window, event, candidate in
            previousObserver?(window, event, candidate)
            guard event.keyCode == 0 else { return }
            count += 1
            responder = candidate
        }
        window.sendEvent(event)
        return (count, responder)
    }

    private func editableField(in view: NSView) -> NSTextField? {
        if let field = view as? NSTextField, field.isEditable { return field }
        return view.subviews.lazy.compactMap { editableField(in: $0) }.first
    }

    private func owns(_ responder: NSResponder?, field: NSTextField) -> Bool {
        if responder === field { return true }
        guard let editor = responder as? NSTextView else { return false }
        return editor.isFieldEditor && editor.delegate as? NSTextField === field
    }

    private func close(windowID: UUID, appDelegate: AppDelegate) {
        guard let window = appDelegate.windowForMainWindowId(windowID) else { return }
        let previous = appDelegate.debugCloseMainWindowConfirmationHandler
        appDelegate.debugCloseMainWindowConfirmationHandler = { _ in true }
        defer { appDelegate.debugCloseMainWindowConfirmationHandler = previous }
        window.animationBehavior = .none
        window.orderOut(nil)
        window.close()
    }

    private final class FocusableView: NSView {
        override var acceptsFirstResponder: Bool { true }
    }

    private enum Failure: Error { case testAllowanceExceeded, deliveryTimedOut }
#endif
}
