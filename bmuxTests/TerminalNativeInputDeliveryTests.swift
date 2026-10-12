import AppKit
import Carbon.HIToolbox
import BmuxTerminal
import GhosttyKit
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

/// Native input assertions require a live runtime, not elapsed wall-clock time.
@MainActor
@Suite(.serialized) struct TerminalNativeInputDeliveryTests {
#if DEBUG
    @Test(.timeLimit(.minutes(1)))
    func koreanPostCompositionHorizontalArrowsReachTerminal() async throws {
        try await withReadySurface { _, view, window in
            let previousObserver = GhosttyNSView.debugGhosttySurfaceKeyEventObserver
            let previousSource = KeyboardLayout.debugInputSourceIdOverride
            let previousInterpret = cjkIMEInterpretKeyEventsHook
            defer {
                GhosttyNSView.debugGhosttySurfaceKeyEventObserver = previousObserver
                KeyboardLayout.debugInputSourceIdOverride = previousSource
                cjkIMEInterpretKeyEventsHook = previousInterpret
            }
            let probes: [(text: String, keyCode: UInt16, before: Int, after: Int)] = [
                ("\u{F702}", UInt16(kVK_LeftArrow), 5, 4),
                ("\u{F703}", UInt16(kVK_RightArrow), 4, 5),
            ]
            AppDelegate.installWindowResponderSwizzlesForTesting()
            KeyboardLayout.debugInputSourceIdOverride = "com.apple.inputmethod.Korean.2SetKorean"
            installCJKIMEInterpretKeyEventsSwizzle()
            cjkIMEInterpretKeyEventsHook = { candidate, events in
                guard candidate === view, let event = events.first,
                      let probe = probes.first(where: { $0.keyCode == event.keyCode }) else { return false }
                candidate.setMarkedText("안녕하세요", selectedRange: NSRange(location: probe.after, length: 0),
                    replacementRange: NSRange(location: NSNotFound, length: 0))
                return true
            }
            var forwarded: [UInt32] = []
            GhosttyNSView.debugGhosttySurfaceKeyEventObserver = { event in
                previousObserver?(event)
                if event.action == GHOSTTY_ACTION_PRESS { forwarded.append(event.keycode) }
            }
            try #require(window.makeFirstResponder(view))
            for probe in probes {
                view.setMarkedText("안녕하세요", selectedRange: NSRange(location: probe.before, length: 0),
                    replacementRange: NSRange(location: NSNotFound, length: 0))
                let event = try #require(NSEvent.keyEvent(with: .keyDown, location: .zero,
                    modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                    windowNumber: window.windowNumber, context: nil, characters: probe.text,
                    charactersIgnoringModifiers: probe.text, isARepeat: false, keyCode: probe.keyCode))
                window.sendEvent(event)
                #expect(view.selectedRange() == NSRange(location: probe.after, length: 0),
                        "Korean 2-Set arrow handling must apply the IME marked-selection update")
            }
            #expect(forwarded == probes.map { UInt32($0.keyCode) },
                    "Korean Left/Right after composition must reach the terminal cursor path")
        }
    }

    @Test(.timeLimit(.minutes(1)))
    func syntheticSpaceReleaseCarriesUnshiftedCodepoint() async throws {
        try await withReadySurface { surface, _, _ in
            let previousObserver = GhosttyNSView.debugGhosttySurfaceKeyEventObserver
            defer { GhosttyNSView.debugGhosttySurfaceKeyEventObserver = previousObserver }
            var release: ghostty_input_key_s?
            GhosttyNSView.debugGhosttySurfaceKeyEventObserver = { event in
                previousObserver?(event)
                if event.action == GHOSTTY_ACTION_RELEASE, event.keycode == 49 { release = event }
            }
            #expect(surface.hostedView.debugSendSyntheticKeyPressAndReleaseForUITest(
                characters: " ", charactersIgnoringModifiers: " ", keyCode: 49))
            let event = try #require(release, "Capture the synthetic Space key release")
            #expect(event.action == GHOSTTY_ACTION_RELEASE)
            #expect(event.keycode == 49)
            #expect(event.unshifted_codepoint == " ".unicodeScalars.first!.value)
            #expect(event.consumed_mods.rawValue == GHOSTTY_MODS_NONE.rawValue)
            #expect(!event.composing)
            #expect(event.text == nil)
        }
    }

    @Test(.timeLimit(.minutes(1)), arguments: [false, true])
    func leadingEscapePreservesDirectInputAndSanitizesAccessibilityInput(accessibility: Bool) async throws {
        try await withReadySurface { _, view, _ in
            let previousObserver = GhosttyNSView.debugGhosttySurfaceKeyEventObserver
            defer { GhosttyNSView.debugGhosttySurfaceKeyEventObserver = previousObserver }
            var texts: [String] = []
            var keycodes: [UInt32] = []
            GhosttyNSView.debugGhosttySurfaceKeyEventObserver = { event in
                previousObserver?(event)
                guard event.action == GHOSTTY_ACTION_PRESS else { return }
                if let text = event.text { texts.append(String(cString: text)) }
                else { keycodes.append(event.keycode) }
            }
            if accessibility { view.setAccessibilityValue("\u{1B}[Adictated line\n") }
            else { view.insertText("\u{1B}[A", replacementRange: NSRange(location: NSNotFound, length: 0)) }
            #expect(texts == (accessibility ? ["dictated line"] : ["\u{1B}[A"]))
            #expect(keycodes == (accessibility ? [36] : []),
                    "AX insertion sanitizes ESC and sends Return; direct NSTextInputClient preserves raw ESC")
        }
    }

    private func withReadySurface(body: (TerminalSurface, GhosttyNSView, NSWindow) throws -> Void) async throws {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 360, height: 240),
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
        // Subscribe before attachment: initial shim preparation may outlast a fixed 50ms delay.
        let surfaceID = surface.id
        let ready = NotificationCenter.default.notifications(named: .terminalSurfaceDidBecomeReady)
            .filter { ($0.object as? TerminalSurface)?.id == surfaceID }.map { _ in true }
        var iterator = ready.makeAsyncIterator()
        content.addSubview(host)
        content.layoutSubtreeIfNeeded()
        host.layoutSubtreeIfNeeded()
        if surface.surface == nil { _ = await iterator.next() }
        try #require(surface.surface != nil, "Runtime creation must complete before native input")
        let view = try #require(host.subviews.compactMap { $0 as? NSScrollView }.first?
            .documentView?.subviews.first as? GhosttyNSView)
        // Synchronous body ensures no other task can replace process-wide probes while installed.
        try body(surface, view, window)
    }
#endif
}
