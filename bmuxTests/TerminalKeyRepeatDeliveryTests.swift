import AppKit
import BmuxTerminal
import GhosttyKit
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

/// Repeat delivery starts only after the terminal's asynchronous runtime creation completes.
@MainActor
@Suite(.serialized) struct TerminalKeyRepeatDeliveryTests {
#if DEBUG
    @Test(.timeLimit(.minutes(1)), arguments: [false, true])
    func repeatsReachGhosttyWithoutForcingRefresh(commitsIMEText: Bool) async throws {
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
        // Register before mounting, matching ConfiguredCodexLaunchTests and the
        // recovery fixture. Initial shim preparation can exceed a fixed 50ms.
        let surfaceID = surface.id
        let ready = NotificationCenter.default.notifications(named: .terminalSurfaceDidBecomeReady)
            .filter { ($0.object as? TerminalSurface)?.id == surfaceID }.map { _ in true }
        var readyIterator = ready.makeAsyncIterator()
        content.addSubview(host)
        content.layoutSubtreeIfNeeded()
        host.layoutSubtreeIfNeeded()
        if surface.surface == nil { _ = await readyIterator.next() }
        try #require(surface.surface != nil, "Runtime creation must complete before repeat input")
        let view = try #require(host.subviews.compactMap { $0 as? NSScrollView }.first?
            .documentView?.subviews.first as? GhosttyNSView)
        try #require(window.makeFirstResponder(view))

        // No suspension while these existing process-wide probes are installed.
        let previousInput = GhosttyNSView.debugTextInputEventHandler
        let previousObserver = GhosttyNSView.debugGhosttySurfaceKeyEventObserver
        defer {
            GhosttyNSView.debugTextInputEventHandler = previousInput
            GhosttyNSView.debugGhosttySurfaceKeyEventObserver = previousObserver
        }
        GhosttyNSView.debugTextInputEventHandler = { view, _ in
            guard commitsIMEText else { return false }
            view.insertText("あ", replacementRange: NSRange(location: NSNotFound, length: 0))
            return true
        }
        var forwardedRepeatCount = 0
        var forwardedTexts: [String] = []
        GhosttyNSView.debugGhosttySurfaceKeyEventObserver = { event in
            previousObserver?(event)
            guard event.action == GHOSTTY_ACTION_REPEAT, event.keycode == 0 else { return }
            forwardedRepeatCount += 1
            if let text = event.text { forwardedTexts.append(String(cString: text)) }
        }
        surface.resetDebugForceRefreshCount()
        for index in 0..<3 {
            let event = try #require(NSEvent.keyEvent(with: .keyDown, location: .zero,
                modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime + Double(index) * 0.001,
                windowNumber: window.windowNumber, context: nil, characters: "a",
                charactersIgnoringModifiers: "a", isARepeat: true, keyCode: 0))
            view.keyDown(with: event)
        }
        #expect(forwardedRepeatCount == 3, "All repeat keyDown events must still reach Ghostty")
        #expect(forwardedTexts == Array(repeating: commitsIMEText ? "あ" : "a", count: 3),
                "Exercise both committed IME text and the printable fallback path")
        #expect(surface.debugForceRefreshCount() == 0,
                "Key repeat must rely on Ghostty wakeups, not synchronous refresh per key")
    }
#endif
}
