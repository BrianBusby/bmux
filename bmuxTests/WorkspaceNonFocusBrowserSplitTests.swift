import Foundation
import Bonsplit
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
        try await waitForDeliveries(nonFocusSplitDeliveries(), count: 3, timeout: .seconds(1))
        #expect(browser.id != originalFocusedPanelID)
        #expect(workspace.focusedPanelId == originalFocusedPanelID,
                "Expected non-focus browser split to preserve pre-split focus")
    }

    @Test func terminalSplitPreservesOriginalFocusedPanel() async throws {
        let workspace = Workspace()
        defer { workspace.teardownRemoteConnection(); workspace.teardownAllPanels() }
        let originalFocusedPanelID = try #require(workspace.focusedPanelId)
        let terminal = try #require(workspace.newTerminalSplit(
            from: originalFocusedPanelID, orientation: .horizontal, focus: false
        ))
        try await waitForDeliveries(nonFocusSplitDeliveries(), count: 3, timeout: .seconds(1))
        #expect(terminal.id != originalFocusedPanelID)
        #expect(workspace.focusedPanelId == originalFocusedPanelID,
                "Expected non-focus terminal split to preserve pre-split focus")
    }

    @Test func browserSplitRecoversFromDelayedStaleSelection() async throws {
        let workspace = Workspace()
        defer { workspace.teardownRemoteConnection(); workspace.teardownAllPanels() }
        let originalFocusedPanelID = try #require(workspace.focusedPanelId)
        let originalPaneID = try #require(workspace.paneId(forPanelId: originalFocusedPanelID))
        let browser = try #require(workspace.newBrowserSplit(
            from: originalFocusedPanelID, orientation: .horizontal, focus: false
        ))
        let splitPaneID = try #require(workspace.paneId(forPanelId: browser.id))
        let splitTabID = try #require(workspace.surfaceIdFromPanelId(browser.id))
        let splitTab = try #require(workspace.bonsplitController.tabs(inPane: splitPaneID)
            .first { $0.id == splitTabID })
        var staleSelectionPending = true
        defer { staleSelectionPending = false }
        // Preserve the original delayed Bonsplit event; cancellation invalidates it before teardown.
        DispatchQueue.main.async {
            guard staleSelectionPending else { return }
            staleSelectionPending = false
            workspace.splitTabBar(workspace.bonsplitController, didSelectTab: splitTab, inPane: splitPaneID)
        }
        let deliveries = nonFocusSplitDeliveries()
        // The original stale-selection case had three sequential one-second queue waits.
        for _ in 0..<3 { try await waitForDeliveries(deliveries, count: 1, timeout: .seconds(1)) }
        #expect(!staleSelectionPending, "Expected the actual delayed selection callback to be delivered")
        #expect(workspace.focusedPanelId == originalFocusedPanelID,
                "Expected non-focus split to reassert the pre-split focused panel")
        #expect(workspace.bonsplitController.focusedPaneId == originalPaneID,
                "Expected focused pane to converge back to the pre-split pane")
        #expect(workspace.bonsplitController.selectedTab(inPane: originalPaneID)?.id
                == workspace.surfaceIdFromPanelId(originalFocusedPanelID),
                "Expected selected tab to converge back to the pre-split focused panel")
    }

    private func nonFocusSplitDeliveries() -> AsyncStream<Void> {
        let (events, signal) = AsyncStream<Void>.makeStream()
        // Two native queued reassertions enqueue a focus reconcile; each FIFO event follows its phase.
        DispatchQueue.main.async {
            signal.yield(())
            DispatchQueue.main.async {
                signal.yield(())
                DispatchQueue.main.async {
                    signal.yield(())
                    signal.finish()
                }
            }
        }
        return events
    }

    private func waitForDeliveries(_ events: AsyncStream<Void>, count: Int, timeout: Duration) async throws {
        let deadline = ContinuousClock.now.advanced(by: timeout)
        try await withThrowingTaskGroup(of: Void.self) { group in
            defer { group.cancelAll() }
            group.addTask {
                var received = 0
                for await _ in events {
                    received += 1
                    if received == count { return }
                }
                throw CancellationError()
            }
            group.addTask {
                // Preserve each original failure bound; event delivery cancels and joins the timer.
                try await ContinuousClock().sleep(until: deadline)
                throw Failure.deliveryTimedOut
            }
            _ = try await group.next()
        }
        try Task.checkCancellation()
    }

    private enum Failure: Error { case deliveryTimedOut }
}
