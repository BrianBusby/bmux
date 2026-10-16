import AppKit
import Testing
import BmuxTerminal

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@MainActor
@Suite("Terminal search overlay mouse release")
struct TerminalSearchOverlayMouseReleaseTests {
    @Test("Search overlay forwards terminal mouse release during selection drag")
    func searchOverlayForwardsTerminalMouseReleaseDuringSelectionDrag() async throws {
        let fixture = TerminalSearchOverlayMouseFixture(readinessTimeout: .seconds(3), mountTimeout: .seconds(1))
        defer { fixture.close() }
        try await fixture.prepare()
        let hostedView = fixture.hostedView
        #expect(hostedView.debugHasSearchOverlay())
        let overlay = try #require(hostedView.debugSearchOverlayHostingViewForTesting())

        try fixture.withFocusedWorkspace { terminalView in
            let downLocation = terminalView.convert(NSPoint(x: 24, y: 24), to: nil)
            terminalView.mouseDown(with: try fixture.mouseEvent(type: .leftMouseDown, location: downLocation))
            #expect(
                hostedView.debugSurfaceHasPendingLeftMouseReleaseForTesting(),
                "Terminal selection should own the left-button release after mouseDown"
            )

            let overlayLocation = overlay.convert(NSPoint(x: overlay.bounds.midX, y: overlay.bounds.midY), to: nil)
            overlay.mouseDragged(with: try fixture.mouseEvent(type: .leftMouseDragged, location: overlayLocation))
            #expect(
                hostedView.debugSurfaceHasPendingLeftMouseReleaseForTesting(),
                "Dragging across the find overlay must keep terminal selection ownership until mouseUp"
            )

            overlay.mouseUp(with: try fixture.mouseEvent(type: .leftMouseUp, location: overlayLocation))
            #expect(
                !hostedView.debugSurfaceHasPendingLeftMouseReleaseForTesting(),
                "An overlay-captured mouseUp must release the terminal selection"
            )
        }
    }

    @Test("Search overlay release clears pending selection after surface release")
    func searchOverlayMouseReleaseClearsSelectionDragAfterSurfaceRelease() async throws {
        let fixture = TerminalSearchOverlayMouseFixture(readinessTimeout: .seconds(3), mountTimeout: .seconds(1))
        defer { fixture.close() }
        try await fixture.prepare()
        let hostedView = fixture.hostedView
        #expect(hostedView.debugHasSearchOverlay())
        let overlay = try #require(hostedView.debugSearchOverlayHostingViewForTesting())

        try fixture.withFocusedWorkspace { terminalView in
            let downLocation = terminalView.convert(NSPoint(x: 24, y: 24), to: nil)
            terminalView.mouseDown(with: try fixture.mouseEvent(type: .leftMouseDown, location: downLocation))
            #expect(hostedView.debugSurfaceHasPendingLeftMouseReleaseForTesting())

            fixture.surface.releaseSurfaceForTesting()
            #expect(fixture.surface.surface == nil)

            let overlayLocation = overlay.convert(NSPoint(x: overlay.bounds.midX, y: overlay.bounds.midY), to: nil)
            overlay.mouseUp(with: try fixture.mouseEvent(type: .leftMouseUp, location: overlayLocation))
            #expect(
                !hostedView.debugSurfaceHasPendingLeftMouseReleaseForTesting(),
                "The pending terminal release state must clear even if the Ghostty surface is gone"
            )
        }
    }
}
