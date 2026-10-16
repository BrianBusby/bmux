import AppKit
import Testing
#if canImport(bmux_DEV)
@testable import bmux_DEV
#else
@testable import bmux
#endif

@MainActor
struct BrowserDropZoneOverlayContractTests {
    private final class CapturingView: NSView {
        override func hitTest(_ point: NSPoint) -> NSView? {
            bounds.contains(point) ? self : nil
        }
    }

    @Test func dropZoneOverlayStaysAboveContentWithoutBlockingHits() async throws {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 200, height: 100))
        let slot = WindowBrowserSlotView(frame: container.bounds)
        container.addSubview(slot)
        defer { container.subviews.forEach { $0.removeFromSuperview() } }
        let child = CapturingView(frame: slot.bounds)
        child.autoresizingMask = [.width, .height]
        slot.addSubview(child)

        slot.setDropZoneOverlay(zone: .right)
        container.layoutSubtreeIfNeeded()
        let overlay = try #require(container.subviews.first(where: {
            $0 !== slot && String(describing: type(of: $0)).contains("BrowserDropZoneOverlayView")
        }))

        #expect(container.subviews.last === overlay, "Overlay should stay above the hosted web view")
        #expect(!overlay.isHidden)
        #expect(abs(overlay.frame.origin.x - 100) <= 0.5)
        #expect(abs(overlay.frame.origin.y - 4) <= 0.5)
        #expect(abs(overlay.frame.size.width - 96) <= 0.5)
        #expect(abs(overlay.frame.size.height - 92) <= 0.5)
        #expect(overlay.hitTest(NSPoint(x: 120, y: 50)) == nil, "Overlay should never intercept pointer hits")
        #expect(slot.hitTest(NSPoint(x: 120, y: 50)) === child)

        try await completeAnimation(within: .milliseconds(250)) {
            slot.setDropZoneOverlay(zone: nil)
        }
        #expect(overlay.isHidden, "Clearing the drop zone should hide the overlay")
    }

    private enum Failure: Error { case animationCompletionTimedOut }

    private func completeAnimation(
        within duration: Duration,
        action: @MainActor () -> Void
    ) async throws {
        let clock = ContinuousClock()
        // Anchor the original 250ms interval before invoking the native action.
        let deadline = clock.now.advanced(by: duration)
        let (events, continuation) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        defer { continuation.finish() }
        NSAnimationContext.runAnimationGroup { _ in
            action()
        } completionHandler: {
            continuation.yield(())
            continuation.finish()
        }
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                for await _ in events { return }
                try Task.checkCancellation()
            }
            group.addTask {
                try await clock.sleep(until: deadline)
                throw Failure.animationCompletionTimedOut
            }
            defer { group.cancelAll() }
            _ = try await group.next()
        }
    }
}
