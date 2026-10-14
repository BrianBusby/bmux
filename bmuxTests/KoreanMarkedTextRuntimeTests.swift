import AppKit
import BmuxTerminal
import GhosttyKit
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@MainActor
@Suite(.serialized)
struct KoreanMarkedTextRuntimeTests {
    @Test func keyDownDoesNotLeakJamoWhileMarkedTextIsActive() async throws {
        let surface = TerminalSurface(tabId: UUID(), context: GHOSTTY_SURFACE_CONTEXT_SPLIT,
            configTemplate: nil, workingDirectory: nil)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 360, height: 240),
            styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer {
            surface.beginPortalCloseLifecycle(reason: "test.cleanup")
            surface.teardownSurface()
            window.contentView = nil
            window.close()
        }
        let content = try #require(window.contentView)
        let host = surface.hostedView
        let readiness = TerminalRuntimeReadinessFixture(surface: surface)
        defer { readiness.close() }
        host.frame = content.bounds
        host.autoresizingMask = [.width, .height]
        content.addSubview(host)
        content.layoutSubtreeIfNeeded()
        host.layoutSubtreeIfNeeded()
        if surface.surface == nil { try await readiness.wait(timeout: .seconds(3)) }
        try #require(surface.surface != nil)
        let view = try #require(host.subviews.compactMap { $0 as? NSScrollView }.first?
            .documentView?.subviews.first as? GhosttyNSView)
        host.setVisibleInUI(true)
        host.setActive(true)
        view.setMarkedText("하", selectedRange: NSRange(location: 0, length: 1),
            replacementRange: NSRange(location: NSNotFound, length: 0))

        // The event phase is synchronous; shared input probes never span a suspension.
        let previousObserver = GhosttyNSView.debugGhosttySurfaceKeyEventObserver
        let previousSource = KeyboardLayout.debugInputSourceIdOverride
        let previousHandler = GhosttyNSView.debugTextInputEventHandler
        defer {
            GhosttyNSView.debugGhosttySurfaceKeyEventObserver = previousObserver
            KeyboardLayout.debugInputSourceIdOverride = previousSource
            GhosttyNSView.debugTextInputEventHandler = previousHandler
        }
        KeyboardLayout.debugInputSourceIdOverride = "com.apple.inputmethod.Korean.2SetKorean"
        GhosttyNSView.debugTextInputEventHandler = { candidate, event in
            candidate === view ? true : (previousHandler?(candidate, event) ?? false)
        }
        var capturedEvent: ghostty_input_key_s?
        GhosttyNSView.debugGhosttySurfaceKeyEventObserver = { event in
            previousObserver?(event)
            if event.action == GHOSTTY_ACTION_PRESS, event.keycode == 45 { capturedEvent = event }
        }
        let event = try #require(NSEvent.keyEvent(with: .keyDown, location: .zero,
            modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber, context: nil, characters: "ㄴ",
            charactersIgnoringModifiers: "ㄴ", isARepeat: false, keyCode: 45))
        try #require(window.makeFirstResponder(view))
        view.keyDown(with: event)
        let captured = try #require(capturedEvent,
            "Expected a composing key event to reach Ghostty after runtime readiness")
        #expect(captured.composing, "Hangul composition must remain active")
        #expect(captured.text == nil, "Uncommitted Hangul jamo must not enter the terminal")
        #expect(view.hasMarkedText(), "Composition remains active until commit or cancellation")
    }
}
