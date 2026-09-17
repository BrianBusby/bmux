import AppKit

/// Reasserts the link cursor when the SwiftUI host updates the pointer.
final class SidebarLinkCursorView: NSView {
    private var linkTrackingArea: NSTrackingArea?
    private var isPointerInside = false

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let linkTrackingArea {
            removeTrackingArea(linkTrackingArea)
        }
        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .cursorUpdate, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        linkTrackingArea = area
    }

    override func cursorUpdate(with event: NSEvent) {
        isPointerInside = true
        NSCursor.pointingHand.set()
    }

    override func mouseEntered(with event: NSEvent) {
        isPointerInside = true
        NSCursor.pointingHand.set()
    }

    override func mouseExited(with event: NSEvent) {
        restoreCursor()
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if newWindow !== window || newWindow == nil {
            restoreCursor()
        }
        super.viewWillMove(toWindow: newWindow)
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(visibleRect, cursor: .pointingHand)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    private func restoreCursor() {
        guard isPointerInside else { return }
        isPointerInside = false
        NSCursor.arrow.set()
    }
}
