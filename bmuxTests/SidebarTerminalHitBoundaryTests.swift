import AppKit
import Testing
#if canImport(bmux_DEV)
@testable import bmux_DEV
#else
@testable import bmux
#endif

@MainActor
struct SidebarTerminalHitBoundaryTests {
    @Test func terminalContentWinsImmediatelyAfterSidebarResizeBand() throws {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 180),
            styleMask: [.titled, .closable], backing: .buffered, defer: false
        )
        window.isReleasedWhenClosed = false
        defer { window.contentView = nil; window.close() }
        let content = try #require(window.contentView)
        let host = WindowTerminalHostView(frame: content.bounds)
        content.addSubview(host)
        // Sidebar geometry comes from the hosted content edge, not an internal split divider.
        let terminalFrame = NSRect(x: 120, y: 0, width: 180, height: 180)
        let terminal = GhosttyNSView(frame: terminalFrame)
        let hosted = GhosttySurfaceScrollView(surfaceView: terminal)
        hosted.frame = terminalFrame
        host.addSubview(hosted)
        let resizePoint = NSPoint(x: 124, y: 90)
        let event = try #require(NSEvent.mouseEvent(
            with: .leftMouseDown, location: resizePoint, modifierFlags: [], timestamp: 0,
            windowNumber: window.windowNumber, context: nil, eventNumber: 1,
            clickCount: 1, pressure: 1
        ))
        #expect(host.performHitTest(at: resizePoint, currentEvent: event) == nil,
                "The four-point terminal-side overlap passes through to the sidebar resizer")
        let hit = try #require(host.performHitTest(at: NSPoint(x: 125, y: 90), currentEvent: event))
        #expect(hit === hosted || hit.isDescendant(of: hosted),
                "Terminal content receives hits one point beyond the sidebar resize band")
    }
}
