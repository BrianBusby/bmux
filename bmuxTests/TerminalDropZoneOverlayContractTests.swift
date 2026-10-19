import AppKit
import Testing
@testable import bmux_DEV

@MainActor
struct TerminalDropZoneOverlayContractTests {
    @Test func dropHoverOverlayAttachesToParentContainerInsteadOfHostedTerminalView() async throws {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 240, height: 120))
        let surfaceView = GhosttyNSView(frame: .zero)
        let hostedView = GhosttySurfaceScrollView(surfaceView: surfaceView)
        hostedView.frame = container.bounds
        container.addSubview(hostedView)
        defer { container.subviews.forEach { $0.removeFromSuperview() } }

        hostedView.setDropZoneOverlay(zone: .right)
        container.layoutSubtreeIfNeeded()
        let state = hostedView.debugDropZoneOverlayState()
        #expect(!state.isHidden)
        #expect(!state.isAttachedToHostedView, "Drop-hover overlay must remain outside the hosted terminal view")
        #expect(state.isAttachedToParentContainer, "Drop-hover overlay must remain in the parent container")
        #expect(abs(state.frame.origin.x - 120) <= 0.5)
        #expect(abs(state.frame.origin.y - 4) <= 0.5)
        #expect(abs(state.frame.size.width - 116) <= 0.5)
        #expect(abs(state.frame.size.height - 112) <= 0.5)

        try await completeAnimation(within: .milliseconds(250)) {
            hostedView.setDropZoneOverlay(zone: nil)
        }
        #expect(hostedView.debugDropZoneOverlayState().isHidden)
    }

    private func completeAnimation(within duration: Duration, action: @MainActor () -> Void) async throws {
        let deadline = ContinuousClock.now.advanced(by: duration)
        let (events, signal) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        defer { signal.finish() }
        NSAnimationContext.runAnimationGroup { _ in
            action()
        } completionHandler: {
            signal.yield(())
            signal.finish()
        }
        try await withThrowingTaskGroup(of: Void.self) { group in
            defer { group.cancelAll() }
            group.addTask {
                for await _ in events { return }
                throw CancellationError()
            }
            group.addTask {
                // The original 250ms failure bound observes native completion, never settling.
                try await ContinuousClock().sleep(until: deadline)
                throw Failure.animationCompletionTimedOut
            }
            _ = try await group.next()
        }
    }

    private enum Failure: Error { case animationCompletionTimedOut }
}
