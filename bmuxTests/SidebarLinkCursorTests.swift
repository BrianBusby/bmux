import AppKit
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@Suite(.serialized)
@MainActor
struct SidebarLinkCursorTests {
    @Test
    func cursorUpdateRestoresHandAfterHostingViewResetsCursor() throws {
        _ = NSApplication.shared
        let previousCursor = NSCursor.current
        defer { previousCursor.set() }
        let view = SidebarLinkCursorView(frame: NSRect(x: 0, y: 0, width: 120, height: 20))
        NSCursor.arrow.set()
        view.cursorUpdate(with: try event(.cursorUpdate))
        #expect(NSCursor.current == NSCursor.pointingHand)
        NSCursor.arrow.set()
        view.cursorUpdate(with: try event(.cursorUpdate))
        #expect(NSCursor.current == NSCursor.pointingHand)
    }

    @Test
    func enteringAndLeavingLinkRestoresArrow() throws {
        _ = NSApplication.shared
        let previousCursor = NSCursor.current
        defer { previousCursor.set() }
        let view = SidebarLinkCursorView(frame: NSRect(x: 0, y: 0, width: 120, height: 20))
        NSCursor.arrow.set()
        view.mouseEntered(with: try event(.mouseEntered))
        #expect(NSCursor.current == NSCursor.pointingHand)
        view.mouseExited(with: try event(.mouseExited))
        #expect(NSCursor.current == NSCursor.arrow)
    }

    @Test
    func removingHoveredLinkRestoresArrow() throws {
        _ = NSApplication.shared
        let previousCursor = NSCursor.current
        defer { previousCursor.set() }
        let view = SidebarLinkCursorView(frame: NSRect(x: 0, y: 0, width: 120, height: 20))
        view.mouseEntered(with: try event(.mouseEntered))
        view.viewWillMove(toWindow: nil)
        #expect(NSCursor.current == NSCursor.arrow)
    }

    @Test
    func cursorRegionDoesNotInterceptButtonClicks() {
        let view = SidebarLinkCursorView(frame: NSRect(x: 0, y: 0, width: 120, height: 20))
        #expect(view.hitTest(NSPoint(x: 60, y: 10)) == nil)
    }

    private func event(_ type: NSEvent.EventType) throws -> NSEvent {
        try #require(NSEvent.enterExitEvent(
            with: type, location: NSPoint(x: 60, y: 10), modifierFlags: [],
            timestamp: 0, windowNumber: 0, context: nil, eventNumber: 0,
            trackingNumber: 0, userData: nil
        ))
    }
}
