import AppKit

/// AppKit owns cursor restoration and cursor-rect invalidation as rows move or disappear.
final class SidebarLinkCursorView: NSView {
    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(visibleRect, cursor: .pointingHand)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}
