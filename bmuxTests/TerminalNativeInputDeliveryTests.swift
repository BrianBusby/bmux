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

    @Test(.timeLimit(.minutes(1)))
    func directInsertTextUsesTypedInputSemantics() async throws {
        try await withReadySurface { _, view, _ in
            let previousObserver = GhosttyNSView.debugGhosttySurfaceKeyEventObserver
            defer { GhosttyNSView.debugGhosttySurfaceKeyEventObserver = previousObserver }
            var pressedText: [String] = []
            var pressedKeycodes: [UInt32] = []
            GhosttyNSView.debugGhosttySurfaceKeyEventObserver = { event in
                previousObserver?(event)
                guard event.action == GHOSTTY_ACTION_PRESS else { return }
                if let text = event.text { pressedText.append(String(cString: text)) }
                else { pressedKeycodes.append(event.keycode) }
            }
            view.insertText("dictated line\n", replacementRange: NSRange(location: NSNotFound, length: 0))
            #expect(pressedText == ["dictated line"])
            #expect(pressedKeycodes == [36], "Trailing newline should be delivered as Return, not pasted text")
        }
    }

    @Test(.timeLimit(.minutes(1)))
    func returnAfterKoreanCommitAlsoSendsReturnToSurface() async throws {
        try await withReadySurface { _, view, window in
            let previousObserver = GhosttyNSView.debugGhosttySurfaceKeyEventObserver
            let previousSource = KeyboardLayout.debugInputSourceIdOverride
            let previousHandler = GhosttyNSView.debugTextInputEventHandler
            defer {
                GhosttyNSView.debugGhosttySurfaceKeyEventObserver = previousObserver
                KeyboardLayout.debugInputSourceIdOverride = previousSource
                GhosttyNSView.debugTextInputEventHandler = previousHandler
            }
            view.setMarkedText("\u{D55C}", selectedRange: NSRange(location: 0, length: 1),
                replacementRange: NSRange(location: NSNotFound, length: 0))
            KeyboardLayout.debugInputSourceIdOverride = "com.apple.inputmethod.Korean.2SetKorean"
            var interpreted = 0
            GhosttyNSView.debugTextInputEventHandler = { candidate, _ in
                guard candidate === view else { return false }
                interpreted += 1
                candidate.insertText("\u{D55C}", replacementRange: NSRange(location: NSNotFound, length: 0))
                return true
            }
            var returnPresses = 0
            GhosttyNSView.debugGhosttySurfaceKeyEventObserver = { event in
                previousObserver?(event)
                if event.action == GHOSTTY_ACTION_PRESS, event.keycode == 36, event.text == nil {
                    returnPresses += 1
                }
            }
            let event = try #require(NSEvent.keyEvent(with: .keyDown, location: .zero,
                modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: window.windowNumber, context: nil, characters: "\r",
                charactersIgnoringModifiers: "\r", isARepeat: false, keyCode: 36))
            try #require(window.makeFirstResponder(view))
            view.keyDown(with: event)
            #expect(!view.hasMarkedText(), "Return should commit the active Hangul composition")
            #expect(returnPresses == 1, "Return should still be forwarded after IME commit so the command executes once")
            #expect(interpreted == 1)
        }
    }

    @Test(.timeLimit(.minutes(1)))
    func optionTildeDeadKeyUsesOriginalEventBeforeAltTranslation() async throws {
        try await withReadySurface { surface, view, window in
            surface.hostedView.setVisibleInUI(true)
            surface.hostedView.setActive(true)
            let previousObserver = GhosttyNSView.debugGhosttySurfaceKeyEventObserver
            let previousHandler = GhosttyNSView.debugTextInputEventHandler
            defer {
                GhosttyNSView.debugGhosttySurfaceKeyEventObserver = previousObserver
                GhosttyNSView.debugTextInputEventHandler = previousHandler
            }
            var deadKeyPrimed = false
            GhosttyNSView.debugTextInputEventHandler = { candidate, event in
                guard candidate === view else { return false }
                let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                if event.keyCode == 45, flags.contains(.option), !flags.contains(.command),
                   !flags.contains(.control), (event.characters ?? "").isEmpty {
                    deadKeyPrimed = true
                    candidate.setMarkedText("~", selectedRange: NSRange(location: 1, length: 0),
                        replacementRange: NSRange(location: NSNotFound, length: 0))
                    return true
                }
                if event.keyCode == 0, deadKeyPrimed, candidate.hasMarkedText() {
                    candidate.insertText("ã", replacementRange: NSRange(location: NSNotFound, length: 0))
                    return true
                }
                return false
            }
            var pressedText: [String] = []
            var pressedKeycodes: [UInt32] = []
            GhosttyNSView.debugGhosttySurfaceKeyEventObserver = { event in
                previousObserver?(event)
                guard event.action == GHOSTTY_ACTION_PRESS else { return }
                if let text = event.text { pressedText.append(String(cString: text)) }
                else { pressedKeycodes.append(event.keycode) }
            }
            try #require(window.makeFirstResponder(view))
            let optionN = try #require(NSEvent.keyEvent(with: .keyDown, location: .zero,
                modifierFlags: [.option], timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: window.windowNumber, context: nil, characters: "",
                charactersIgnoringModifiers: "n", isARepeat: false, keyCode: 45))
            let letterA = try #require(NSEvent.keyEvent(with: .keyDown, location: .zero,
                modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: window.windowNumber, context: nil, characters: "a",
                charactersIgnoringModifiers: "a", isARepeat: false, keyCode: 0))
            view.keyDown(with: optionN)
            view.keyDown(with: letterA)
            #expect(pressedText == ["ã"])
            #expect(pressedKeycodes == [])
            #expect(!view.hasMarkedText())
        }
    }

    @Test(.timeLimit(.minutes(1)))
    func shiftBackquoteEscFallbackSendsLiteralTilde() async throws {
        try await withReadySurface { surface, view, _ in
            surface.hostedView.setVisibleInUI(true)
            surface.hostedView.setActive(true)
            let previousObserver = GhosttyNSView.debugGhosttySurfaceKeyEventObserver
            let previousHandler = GhosttyNSView.debugTextInputEventHandler
            defer {
                GhosttyNSView.debugGhosttySurfaceKeyEventObserver = previousObserver
                GhosttyNSView.debugTextInputEventHandler = previousHandler
            }
            // Exercise textForKeyEvent's fallback when interpretation commits no text.
            GhosttyNSView.debugTextInputEventHandler = { candidate, _ in candidate === view }
            var pressText: String?
            var pressUnshiftedCodepoint: UInt32?
            GhosttyNSView.debugGhosttySurfaceKeyEventObserver = { event in
                previousObserver?(event)
                guard event.action == GHOSTTY_ACTION_PRESS, event.keycode == 50 else { return }
                pressUnshiftedCodepoint = event.unshifted_codepoint
                pressText = event.text.map { String(cString: $0) }
            }
            #expect(surface.hostedView.debugSendSyntheticKeyPressAndReleaseForUITest(
                characters: "\u{1B}", charactersIgnoringModifiers: "`", keyCode: 50, modifierFlags: [.shift]))
            #expect(pressText == "~")
            #expect(pressUnshiftedCodepoint == "`".unicodeScalars.first!.value)
        }
    }

    @Test(.timeLimit(.minutes(1)))
    func optionDeletePreservesAltAsModifierForWordDelete() async throws {
        try await withReadySurface { surface, _, _ in
            surface.hostedView.setVisibleInUI(true)
            surface.hostedView.setActive(true)
            let previousObserver = GhosttyNSView.debugGhosttySurfaceKeyEventObserver
            defer { GhosttyNSView.debugGhosttySurfaceKeyEventObserver = previousObserver }
            var pressEvent: ghostty_input_key_s?
            GhosttyNSView.debugGhosttySurfaceKeyEventObserver = { event in
                previousObserver?(event)
                if event.action == GHOSTTY_ACTION_PRESS, event.keycode == 51 { pressEvent = event }
            }
            #expect(surface.hostedView.debugSendSyntheticKeyPressAndReleaseForUITest(
                characters: "\u{7F}", charactersIgnoringModifiers: "\u{7F}", keyCode: 51, modifierFlags: [.option]))
            let event = try #require(pressEvent, "Capture the Option+Delete key press")
            #expect(event.action == GHOSTTY_ACTION_PRESS)
            #expect(event.keycode == 51)
            #expect(event.mods.rawValue & GHOSTTY_MODS_ALT.rawValue == GHOSTTY_MODS_ALT.rawValue)
            #expect(event.consumed_mods.rawValue == GHOSTTY_MODS_NONE.rawValue)
            #expect(event.text == nil)
        }
    }

    @Test(.timeLimit(.minutes(1)))
    func keyDownDoesNotForwardWhenZhuyinStartsMarkedText() async throws {
        try await withReadySurface { surface, view, window in
            surface.hostedView.setVisibleInUI(true)
            surface.hostedView.setActive(true)
            let previousObserver = GhosttyNSView.debugGhosttySurfaceKeyEventObserver
            let previousSource = KeyboardLayout.debugInputSourceIdOverride
            let previousHandler = GhosttyNSView.debugTextInputEventHandler
            defer {
                GhosttyNSView.debugGhosttySurfaceKeyEventObserver = previousObserver
                KeyboardLayout.debugInputSourceIdOverride = previousSource
                GhosttyNSView.debugTextInputEventHandler = previousHandler
            }
            KeyboardLayout.debugInputSourceIdOverride = "com.apple.inputmethod.TCIM.Zhuyin"
            GhosttyNSView.debugTextInputEventHandler = { candidate, _ in
                guard candidate === view else { return false }
                candidate.setMarkedText("ㄓ", selectedRange: NSRange(location: 1, length: 0),
                    replacementRange: NSRange(location: NSNotFound, length: 0))
                return true
            }
            var forwardedPressCount = 0
            GhosttyNSView.debugGhosttySurfaceKeyEventObserver = { event in
                previousObserver?(event)
                if event.action == GHOSTTY_ACTION_PRESS { forwardedPressCount += 1 }
            }
            let event = try #require(NSEvent.keyEvent(with: .keyDown, location: .zero,
                modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: window.windowNumber, context: nil, characters: "5",
                charactersIgnoringModifiers: "5", isARepeat: false, keyCode: 23))
            try #require(window.makeFirstResponder(view))
            view.keyDown(with: event)
            #expect(view.hasMarkedText(), "Zhuyin keyDown should start marked text")
            #expect(forwardedPressCount == 0,
                    "AppKit-consumed Zhuyin marked-text changes must not forward a duplicate Ghostty key")
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
        let readiness = TerminalRuntimeReadinessFixture(surface: surface)
        defer { readiness.close() }
        content.addSubview(host)
        content.layoutSubtreeIfNeeded()
        host.layoutSubtreeIfNeeded()
        if surface.surface == nil { try await readiness.wait(timeout: .seconds(3)) }
        try #require(surface.surface != nil, "Runtime creation must complete before native input")
        let view = try #require(host.subviews.compactMap { $0 as? NSScrollView }.first?
            .documentView?.subviews.first as? GhosttyNSView)
        // Synchronous body ensures no other task can replace process-wide probes while installed.
        try body(surface, view, window)
    }
#endif
}
