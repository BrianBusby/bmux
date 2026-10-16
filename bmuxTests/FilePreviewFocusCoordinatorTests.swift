import AppKit
import Testing
@testable import bmux_DEV

/// Exercises pending focus with a Swift-owned window that remains retained through close.
@MainActor
@Suite
struct FilePreviewFocusCoordinatorTests {
    @Test
    func keepsPendingFocusUntilEndpointHasWindow() {
        let textView = FocusView(frame: NSRect(x: 0, y: 0, width: 320, height: 240))
        let coordinator = FilePreviewFocusCoordinator(preferredIntent: .textEditor)
        coordinator.register(root: textView, primaryResponder: textView, intent: .textEditor)

        #expect(!coordinator.focus(.textEditor))

        let window = NSWindow(contentRect: textView.bounds, styleMask: [], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer {
            window.contentView = nil
            window.close()
        }
        window.contentView = textView
        coordinator.fulfillPendingFocusIfNeeded()

        #expect(window.firstResponder === textView)
    }

    private final class FocusView: NSView {
        override var acceptsFirstResponder: Bool { true }
        override var canBecomeKeyView: Bool { true }
    }
}
