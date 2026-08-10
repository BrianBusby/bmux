import Foundation
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@MainActor
@Suite struct WorkspaceMoveToTopActionTests {
    @Test func workspaceActionMoveToTopUsesSharedBatchPath() throws {
        let manager = TabManager()
        _ = manager.addWorkspace()
        _ = manager.addWorkspace()
        let originalOrder = manager.tabs.map(\.id)
        #expect(originalOrder.count == 3)

        let movedIndex = manager.moveWorkspaceToTopForAction(tabId: originalOrder[2])

        #expect(movedIndex == 0)
        #expect(manager.tabs.map(\.id) == [originalOrder[2], originalOrder[0], originalOrder[1]])
    }

    @Test func workspaceActionBatchMoveToTopFiltersStaleAndDuplicateTargets() throws {
        let manager = TabManager()
        _ = manager.addWorkspace()
        _ = manager.addWorkspace()
        _ = manager.addWorkspace()
        let originalOrder = manager.tabs.map(\.id)
        #expect(originalOrder.count == 4)

        let movedWorkspaceIds = manager.moveWorkspacesToTopForAction(
            workspaceIds: [originalOrder[2], UUID(), originalOrder[2], originalOrder[3]]
        )

        #expect(movedWorkspaceIds == [originalOrder[2], originalOrder[3]])
        #expect(manager.tabs.map(\.id) == [originalOrder[2], originalOrder[3], originalOrder[0], originalOrder[1]])
        #expect(manager.moveWorkspacesToTopForAction(workspaceIds: [UUID()]).isEmpty)
    }
}
