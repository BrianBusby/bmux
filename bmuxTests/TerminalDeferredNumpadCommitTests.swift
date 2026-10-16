import AppKit
import BmuxTerminal
import GhosttyKit
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

/// Exercises actual queued IME delivery without leaving process-wide probes installed across await.
@MainActor
struct TerminalDeferredNumpadCommitTests {
    @Test
    func keypadDigitDoesNotDuplicateWhenTraditionalChineseIMECommitsAfterKeyDown() async throws {
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
        try #require(window.makeFirstResponder(view))
        let event = try #require(NSEvent.keyEvent(with: .keyDown, location: .zero,
            modifierFlags: [.numericPad], timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber, context: nil, characters: "1",
            charactersIgnoringModifiers: "1", isARepeat: false, keyCode: 83))
        let completion = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        var callbackPending = true
        var callbackCount = 0
        var keyDownReturned = false
        var pressedText: [String] = []
        defer { callbackPending = false; completion.continuation.finish() }

        // Each phase owns/restores hooks synchronously. No unrelated task can see them while suspended.
        func withInputProbes(_ action: () -> Void) {
            let previousObserver = GhosttyNSView.debugGhosttySurfaceKeyEventObserver
            let previousSource = KeyboardLayout.debugInputSourceIdOverride
            defer {
                GhosttyNSView.debugGhosttySurfaceKeyEventObserver = previousObserver
                KeyboardLayout.debugInputSourceIdOverride = previousSource
            }
            KeyboardLayout.debugInputSourceIdOverride = "com.apple.inputmethod.TCIM.Pinyin"
            GhosttyNSView.debugGhosttySurfaceKeyEventObserver = { event in
                previousObserver?(event)
                if event.action == GHOSTTY_ACTION_PRESS, let text = event.text {
                    pressedText.append(String(cString: text))
                }
            }
            action()
        }
        withInputProbes {
            let previousHandler = GhosttyNSView.debugTextInputEventHandler
            defer { GhosttyNSView.debugTextInputEventHandler = previousHandler }
            GhosttyNSView.debugTextInputEventHandler = { candidate, _ in
                guard candidate === view else { return false }
                // Reproduce AppKit's deferred callback on its real queue; not a settling delay.
                DispatchQueue.main.async {
                    guard callbackPending else { return }
                    callbackCount += 1
                    #expect(keyDownReturned)
                    withInputProbes {
                        candidate.insertText("1", replacementRange: NSRange(location: NSNotFound, length: 0))
                    }
                    callbackPending = false
                    completion.continuation.yield(())
                    completion.continuation.finish()
                }
                return true
            }
            view.keyDown(with: event)
            keyDownReturned = true
            #expect(pressedText == ["1"], "Raw keypad fallback must be sent once before deferred commit")
        }
        try await waitForCommit(completion.stream, timeout: .seconds(1))
        #expect(callbackCount == 1, "The queued IME callback must actually run")
        #expect(pressedText == ["1"], "Deferred Traditional Chinese IME commit must not double-dispatch the digit")
    }

    private func waitForCommit(_ events: AsyncStream<Void>, timeout: Duration) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            defer { group.cancelAll() }
            group.addTask {
                for await _ in events { return }
                throw CancellationError()
            }
            group.addTask {
                // Original one-second failure bound; injected, cancellable, and joined on completion.
                try await ContinuousClock().sleep(for: timeout)
                throw Failure.commitTimedOut
            }
            _ = try await group.next()
        }
    }

    private enum Failure: Error { case commitTimedOut }
}
