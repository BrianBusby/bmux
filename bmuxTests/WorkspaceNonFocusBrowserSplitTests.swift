import Foundation
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@MainActor
struct WorkspaceNonFocusBrowserSplitTests {
    @Test func browserSplitPreservesOriginalFocusedPanel() async throws {
        let workspace = Workspace()
        defer { workspace.teardownRemoteConnection(); workspace.teardownAllPanels() }
        let originalFocusedPanelID = try #require(workspace.focusedPanelId)
        let browser = try #require(workspace.newBrowserSplit(
            from: originalFocusedPanelID, orientation: .horizontal, focus: false
        ))
        try await deliverNonFocusSplitFollowUps(timeout: .seconds(1))
        #expect(browser.id != originalFocusedPanelID)
        #expect(workspace.focusedPanelId == originalFocusedPanelID,
                "Expected non-focus browser split to preserve pre-split focus")
    }

    private func deliverNonFocusSplitFollowUps(timeout: Duration) async throws {
        let (events, signal) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        defer { signal.finish() }
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        // The production non-focus split owner queues two nested main-queue reassertions.
        // A third FIFO delivery follows their queued focus reconcile, all under the same deadline.
        DispatchQueue.main.async {
            DispatchQueue.main.async {
                DispatchQueue.main.async {
                    signal.yield(())
                    signal.finish()
                }
            }
        }
        try await withThrowingTaskGroup(of: Void.self) { group in
            defer { group.cancelAll() }
            group.addTask {
                for await _ in events { return }
                throw CancellationError()
            }
            group.addTask {
                // Retain the original one-second failure bound, with joined cancellation.
                try await clock.sleep(until: deadline)
                throw Failure.deliveryTimedOut
            }
            _ = try await group.next()
        }
        try Task.checkCancellation()
    }

    private enum Failure: Error { case deliveryTimedOut }
}
