import AppKit
import BmuxTerminal
import Testing
#if canImport(bmux_DEV)
@testable import bmux_DEV
#else
@testable import bmux
#endif

@MainActor
struct TerminalPortalGeometryContractTests {
    @Test(arguments: [false, true])
    func pruneDeadEntriesDetachesAnchorlessHostedView(visibleDuringAnchorLoss: Bool) throws {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        defer { window.close() }
        let portal = WindowTerminalPortal(window: window)
        defer { portal.tearDown() }
        let contentView = try #require(window.contentView)

        let hosted1 = GhosttySurfaceScrollView(
            surfaceView: GhosttyNSView(frame: NSRect(x: 0, y: 0, width: 40, height: 30))
        )

        var anchor1: NSView? = NSView(frame: NSRect(x: 20, y: 20, width: 120, height: 80))
        contentView.addSubview(anchor1!)
        // Visible anchorless entries are retained for transient drag recovery.
        portal.bind(hostedView: hosted1, to: anchor1!, visibleInUI: visibleDuringAnchorLoss)

        anchor1?.removeFromSuperview()
        anchor1 = nil

        let hosted2 = GhosttySurfaceScrollView(
            surfaceView: GhosttyNSView(frame: NSRect(x: 0, y: 0, width: 40, height: 30))
        )
        let anchor2 = NSView(frame: NSRect(x: 180, y: 20, width: 120, height: 80))
        contentView.addSubview(anchor2)
        portal.bind(hostedView: hosted2, to: anchor2, visibleInUI: true)

        let expectedCount = visibleDuringAnchorLoss ? 2 : 1
        #expect(portal.debugEntryCount() == expectedCount, "Only live anchors and visible recovery entries should remain tracked")
        #expect(portal.debugStats().terminalSubviewCount == expectedCount, "Hidden stale anchorless hosted views should be detached from hostView")
        #expect((hosted1.superview != nil) == visibleDuringAnchorLoss)
    }

    @Test func scheduledExternalGeometrySyncWaitsForQueuedLayoutShift() async throws {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 420),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        defer { window.close() }

        let surface = TerminalSurface(
            tabId: UUID(),
            context: GHOSTTY_SURFACE_CONTEXT_SPLIT,
            configTemplate: nil,
            workingDirectory: nil
        )
        defer {
            TerminalWindowPortalRegistry.detach(hostedView: surface.hostedView)
            surface.teardownSurface()
        }
        let contentView = try #require(window.contentView)

        let shiftedContainer = NSView(frame: NSRect(x: 40, y: 60, width: 260, height: 180))
        contentView.addSubview(shiftedContainer)
        let anchor = NSView(frame: NSRect(x: 0, y: 0, width: 260, height: 180))
        shiftedContainer.addSubview(anchor)
        let hosted = surface.hostedView
        TerminalWindowPortalRegistry.bind(
            hostedView: hosted,
            to: anchor,
            visibleInUI: true,
            expectedSurfaceId: surface.id,
            expectedGeneration: surface.portalBindingGeneration()
        )
        TerminalWindowPortalRegistry.synchronizeForAnchor(anchor)

        let anchorCenter = NSPoint(x: anchor.bounds.midX, y: anchor.bounds.midY)
        let originalWindowPoint = anchor.convert(anchorCenter, to: nil)
        let originalAnchorFrameInWindow = anchor.convert(anchor.bounds, to: nil)
        #expect(
            TerminalWindowPortalRegistry.terminalViewAtWindowPoint(originalWindowPoint, in: window) != nil,
            "Initial hit-testing should resolve the portal-hosted terminal at its original window position"
        )

        // Finish the bind-triggered two-hop geometry delivery before the request under test.
        await deliverQueuedGeometry {}
        await deliverQueuedGeometry {}
        TerminalWindowPortalRegistry.scheduleExternalGeometrySynchronize(for: window, forceImmediate: false)
        await deliverQueuedGeometry {
            shiftedContainer.frame.origin.x += 72
            contentView.layoutSubtreeIfNeeded()
            window.displayIfNeeded()
        }

        // The owner queued its second hop before this sentinel.
        await deliverQueuedGeometry {}

        let shiftedAnchorFrameInWindow = anchor.convert(anchor.bounds, to: nil)
        #expect(
            shiftedAnchorFrameInWindow.minX > originalAnchorFrameInWindow.minX + 1,
            "The queued layout shift should move the anchor to the right"
        )
        #expect(
            shiftedAnchorFrameInWindow.maxX > originalAnchorFrameInWindow.maxX + 1,
            "The shifted anchor should expose a new trailing region outside the stale portal frame"
        )
        let retiredStaleWindowPoint = NSPoint(
            x: (originalAnchorFrameInWindow.minX + shiftedAnchorFrameInWindow.minX) / 2,
            y: shiftedAnchorFrameInWindow.midY
        )
        let shiftedWindowPoint = NSPoint(
            x: (originalAnchorFrameInWindow.maxX + shiftedAnchorFrameInWindow.maxX) / 2,
            y: shiftedAnchorFrameInWindow.midY
        )
        #expect(
            TerminalWindowPortalRegistry.terminalViewAtWindowPoint(retiredStaleWindowPoint, in: window) == nil,
            "The queued external sync should wait until the later layout shift settles, clearing the stale portal location"
        )
        #expect(
            TerminalWindowPortalRegistry.terminalViewAtWindowPoint(shiftedWindowPoint, in: window) != nil,
            "The delayed external sync should move the portal-hosted terminal to the queued layout shift position"
        )
    }

    // Bridge the legacy portal's FIFO main-queue event delivery, not a time-based settling wait.
    private func deliverQueuedGeometry(_ operation: @escaping @MainActor @Sendable () -> Void) async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                operation()
                continuation.resume()
            }
        }
    }
}
