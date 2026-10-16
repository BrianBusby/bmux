import Foundation
import BmuxWorkspaces
import Testing
#if canImport(bmux_DEV)
@testable import bmux_DEV
#else
@testable import bmux
#endif

@MainActor
struct SidebarToolFocusContractTests {
    @Test
    func nonfocusedToolCreationPreservesPanelAcrossDeferredFocusRestoration() async throws {
        let workspace = Workspace()
        defer {
            workspace.teardownRemoteConnection()
            workspace.teardownAllPanels()
        }
        let originalPanel = try #require(workspace.focusedPanelId)
        let originalPane = try #require(workspace.paneId(forPanelId: originalPanel))
        let originalTab = try #require(workspace.surfaceIdFromPanelId(originalPanel))
        let tool = try #require(workspace.newRightSidebarToolSurface(
            inPane: originalPane, mode: .files, focus: false
        ))

        // Preserve the owner's two nested reassertions and subsequent focus reconciliation.
        try await deliverFocusQueue()
        try await deliverFocusQueue()
        try await deliverFocusQueue()

        #expect(tool.id != originalPanel)
        #expect(tool.panelType == .rightSidebarTool)
        #expect(tool.mode == .files)
        #expect(workspace.focusedPanelId == originalPanel)
        #expect(workspace.bonsplitController.selectedTab(inPane: originalPane)?.id == originalTab)
        #expect(workspace.surfaceIdFromPanelId(tool.id).flatMap {
            workspace.bonsplitController.tab($0)?.kind
        } == SurfaceKind.rightSidebarTool.rawValue)
    }

    private func deliverFocusQueue() async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(1))
        let delivery = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        defer { delivery.continuation.finish() }
        // Bridge the existing focus owner's FIFO event delivery, not a settling delay.
        DispatchQueue.main.async {
            delivery.continuation.yield(())
            delivery.continuation.finish()
        }
        try await withThrowingTaskGroup(of: Void.self) { group in
            defer { group.cancelAll() }
            group.addTask {
                for await _ in delivery.stream { return }
                throw CancellationError()
            }
            group.addTask {
                // Preserve the original one-second failure bound for each delivery.
                try await ContinuousClock().sleep(until: deadline)
                throw DeliveryFailure.timedOut
            }
            try await group.next()
        }
        try Task.checkCancellation()
    }

    private enum DeliveryFailure: Error { case timedOut }
}
