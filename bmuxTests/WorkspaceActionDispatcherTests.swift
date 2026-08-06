import Foundation
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@MainActor
@Suite struct WorkspaceActionDispatcherTests {
    @Test func singleAndSidebarTargetsResolveTheSamePinState() throws {
        let manager = TabManager()
        let workspace = try #require(manager.tabs.first)

        let singleState = try #require(
            WorkspaceActionDispatcher.pinState(
                in: manager,
                target: .single(workspace.id)
            )
        )
        let sidebarState = try #require(
            WorkspaceActionDispatcher.pinState(
                in: manager,
                target: WorkspaceActionDispatcher.Target(
                    workspaceIds: [workspace.id],
                    anchorWorkspaceId: workspace.id
                )
            )
        )

        #expect(singleState == sidebarState)
        #expect(singleState.pinned == !workspace.isPinned)
    }

    @Test func pinActionPinsMultipleTargetsFromAnchorState() throws {
        let manager = TabManager()
        let first = try #require(manager.tabs.first)
        let second = manager.addWorkspace()
        let third = manager.addWorkspace()
        let target = WorkspaceActionDispatcher.Target(
            workspaceIds: [second.id, third.id],
            anchorWorkspaceId: second.id
        )

        let state = try #require(WorkspaceActionDispatcher.pinState(in: manager, target: target))
        let result = WorkspaceActionDispatcher.performPinAction(state, in: manager)

        #expect(state.pinned)
        #expect(result.targetWorkspaceIds == [second.id, third.id])
        #expect(result.changedWorkspaceIds == [second.id, third.id])
        #expect(second.isPinned)
        #expect(third.isPinned)
        #expect(!first.isPinned)
        #expect(manager.tabs.map(\.id) == [second.id, third.id, first.id])
    }

    @Test func pinActionUnpinsMultipleTargetsWithExistingOrdering() throws {
        let manager = TabManager()
        let first = try #require(manager.tabs.first)
        let second = manager.addWorkspace()
        let third = manager.addWorkspace()
        manager.setPinned(first, pinned: true)
        manager.setPinned(second, pinned: true)
        manager.setPinned(third, pinned: true)
        let target = WorkspaceActionDispatcher.Target(
            workspaceIds: [second.id, third.id],
            anchorWorkspaceId: second.id
        )

        let state = try #require(WorkspaceActionDispatcher.pinState(in: manager, target: target))
        let result = WorkspaceActionDispatcher.performPinAction(state, in: manager)

        #expect(!state.pinned)
        #expect(result.targetWorkspaceIds == [second.id, third.id])
        #expect(result.changedWorkspaceIds == [second.id, third.id])
        #expect(first.isPinned)
        #expect(!second.isPinned)
        #expect(!third.isPinned)
        #expect(manager.tabs.map(\.id) == [first.id, third.id, second.id])
    }

    @Test func capturedPinStateKeepsLabelAndActionConsistent() throws {
        let manager = TabManager()
        let workspace = try #require(manager.tabs.first)
        let state = try #require(
            WorkspaceActionDispatcher.pinState(
                in: manager,
                target: .single(workspace.id)
            )
        )

        manager.setPinned(workspace, pinned: true)
        let result = WorkspaceActionDispatcher.performPinAction(state, in: manager)

        #expect(state.pinned)
        #expect(workspace.isPinned)
        #expect(result.changedWorkspaceIds.isEmpty)
    }

    @Test func workspaceActionPinUsesWorkspaceReorderCoordinatorPath() throws {
        let manager = TabManager()
        let first = try #require(manager.tabs.first)
        let second = manager.addWorkspace()

        #expect(manager.setWorkspacePinnedForAction(tabId: second.id, pinned: true))

        #expect(second.isPinned)
        #expect(manager.tabs.map(\.id) == [second.id, first.id])
    }

    @Test func workspaceActionBatchPinFiltersStaleAndDuplicateTargets() throws {
        let manager = TabManager()
        let first = try #require(manager.tabs.first)
        let second = manager.addWorkspace()
        let third = manager.addWorkspace()
        let missingWorkspaceId = UUID()

        let changedWorkspaceIds = manager.setWorkspacesPinnedForAction(
            workspaceIds: [second.id, missingWorkspaceId, second.id, first.id],
            pinned: true
        )

        #expect(changedWorkspaceIds == [second.id, first.id])
        #expect(first.isPinned)
        #expect(second.isPinned)
        #expect(!third.isPinned)
        #expect(manager.tabs.map(\.id) == [second.id, first.id, third.id])
    }

    @Test func workspaceActionMoveUsesWorkspaceReorderCoordinatorPath() throws {
        let manager = TabManager()
        _ = manager.addWorkspace()
        _ = manager.addWorkspace()
        let originalOrder = manager.tabs.map(\.id)
        #expect(originalOrder.count == 3)

        let movingWorkspaceId = originalOrder[1]
        let movedIndex = manager.moveWorkspaceForAction(tabId: movingWorkspaceId, by: -1)
        var expectedOrder = originalOrder
        let movedWorkspaceId = expectedOrder.remove(at: 1)
        expectedOrder.insert(movedWorkspaceId, at: 0)

        #expect(movedIndex == 0)
        #expect(manager.tabs.map(\.id) == expectedOrder)
    }

    @Test func workspaceActionDescriptionNormalizesThroughWorkspaceModel() throws {
        let manager = TabManager()
        let workspace = try #require(manager.tabs.first)

        let description = manager.setWorkspaceDescriptionForAction(
            tabId: workspace.id,
            description: "  one\r\ntwo  "
        )

        #expect(description == "  one\ntwo  ")
        #expect(workspace.customDescription == "  one\ntwo  ")
        #expect(manager.clearWorkspaceDescriptionForAction(tabId: workspace.id))
        #expect(workspace.customDescription == nil)
    }

    @Test func workspaceActionColorUsesSharedColorResolution() throws {
        let manager = TabManager()
        let workspace = try #require(manager.tabs.first)

        let hexColor = manager.setWorkspaceColorForAction(tabId: workspace.id, colorInput: "  abcdef  ")
        #expect(hexColor == "#ABCDEF")
        #expect(workspace.customColor == "#ABCDEF")

        #expect(manager.setWorkspaceColorForAction(tabId: workspace.id, colorInput: "not-a-color") == nil)
        #expect(workspace.customColor == "#ABCDEF")
        #expect(manager.clearWorkspaceColorForAction(tabId: workspace.id))
        #expect(workspace.customColor == nil)
    }

    @Test func workspaceActionBatchColorFiltersStaleAndDuplicateTargets() throws {
        let manager = TabManager()
        let first = try #require(manager.tabs.first)
        let second = manager.addWorkspace()
        let third = manager.addWorkspace()
        let missingWorkspaceId = UUID()

        let coloredWorkspaceIds = manager.setWorkspacesColorForAction(
            workspaceIds: [second.id, missingWorkspaceId, second.id, first.id],
            color: "#123456"
        )

        #expect(coloredWorkspaceIds == [second.id, first.id])
        #expect(first.customColor == "#123456")
        #expect(second.customColor == "#123456")
        #expect(third.customColor == nil)

        let clearedWorkspaceIds = manager.setWorkspacesColorForAction(
            workspaceIds: [first.id, third.id],
            color: nil
        )

        #expect(clearedWorkspaceIds == [first.id, third.id])
        #expect(first.customColor == nil)
        #expect(second.customColor == "#123456")
        #expect(third.customColor == nil)
    }

    @Test func relativeCloseCandidatesUseCurrentWorkspaceOrder() throws {
        let manager = TabManager()
        _ = manager.addWorkspace()
        _ = manager.addWorkspace()
        let order = manager.tabs.map(\.id)
        #expect(order.count == 3)

        let anchor = order[1]

        #expect(manager.workspaceIdsForRelativeClose(.above(anchor: anchor), allowPinned: true) == [order[0]])
        #expect(manager.workspaceIdsForRelativeClose(.below(anchor: anchor), allowPinned: true) == [order[2]])
        #expect(manager.workspaceIdsForRelativeClose(.others(keeping: [anchor]), allowPinned: true) == [
            order[0],
            order[2]
        ])
    }

    @Test func relativeCloseCandidatesRespectPinnedPolicy() throws {
        let manager = TabManager()
        _ = manager.addWorkspace()
        _ = manager.addWorkspace()
        let pinnedWorkspace = try #require(manager.tabs.first)
        manager.setPinned(pinnedWorkspace, pinned: true)
        let anchor = try #require(manager.tabs.last)

        let expectedWithPinned = manager.tabs.compactMap { $0.id == anchor.id ? nil : $0.id }
        let expectedWithoutPinned = manager.tabs.compactMap { workspace -> UUID? in
            workspace.id == anchor.id || workspace.isPinned ? nil : workspace.id
        }

        #expect(
            manager.workspaceIdsForRelativeClose(.others(keeping: [anchor.id]), allowPinned: true)
            == expectedWithPinned
        )
        #expect(
            manager.workspaceIdsForRelativeClose(.others(keeping: [anchor.id]), allowPinned: false)
            == expectedWithoutPinned
        )
    }

    @Test func workspaceActionRelativeCloseSkipsPinnedAndClosesThroughWorkspaceClosePath() throws {
        let manager = TabManager()
        _ = manager.addWorkspace()
        _ = manager.addWorkspace()
        let pinnedWorkspace = try #require(manager.tabs.first)
        manager.setPinned(pinnedWorkspace, pinned: true)
        let anchor = try #require(manager.tabs.last)
        let expectedClosedIds = manager.workspaceIdsForRelativeClose(
            .others(keeping: [anchor.id]),
            allowPinned: false
        )

        let closed = manager.closeWorkspacesForAction(.others(keeping: [anchor.id]))

        #expect(closed == expectedClosedIds.count)
        #expect(manager.tabs.contains { $0.id == anchor.id })
        #expect(manager.tabs.contains { $0.id == pinnedWorkspace.id })
        for closedId in expectedClosedIds {
            #expect(!manager.tabs.contains { $0.id == closedId })
        }
    }

    @Test func workspaceCloseActionRejectsMissingAndPinnedTargets() throws {
        let manager = TabManager()
        let first = try #require(manager.tabs.first)
        let second = manager.addWorkspace()

        #expect(manager.closeWorkspaceForAction(tabId: UUID()) == .notFound)

        #expect(manager.setWorkspacePinnedForAction(tabId: second.id, pinned: true))
        #expect(manager.closeWorkspaceForAction(tabId: second.id) == .protected)
        #expect(manager.tabs.map(\.id) == [second.id, first.id])

        #expect(manager.closeWorkspaceForAction(tabId: second.id, allowPinned: true) == .accepted)
        #expect(manager.tabs.map(\.id) == [first.id])
    }

    @Test func workspaceSelectionActionRejectsMissingWorkspaceWithoutChangingSelection() throws {
        let manager = TabManager()
        _ = manager.addWorkspace()
        let targetWorkspace = try #require(manager.tabs.last)

        #expect(manager.selectWorkspaceIdForAction(targetWorkspace.id))
        #expect(manager.selectedTabId == targetWorkspace.id)

        #expect(!manager.selectWorkspaceIdForAction(UUID()))
        #expect(manager.selectedTabId == targetWorkspace.id)
    }

    @Test func workspaceSurfaceFocusActionSelectsWorkspaceAndRejectsInvalidTargets() throws {
        let manager = TabManager()
        let originalWorkspace = try #require(manager.tabs.first)
        let targetWorkspace = manager.addWorkspace(select: false)
        let targetSurfaceId = try #require(targetWorkspace.focusedPanelId)

        #expect(manager.selectedTabId == originalWorkspace.id)
        #expect(
            manager.focusWorkspaceSurfaceForAction(
                workspaceId: targetWorkspace.id,
                surfaceId: targetSurfaceId
            ) == .focused(workspaceId: targetWorkspace.id, surfaceId: targetSurfaceId)
        )
        #expect(manager.selectedTabId == targetWorkspace.id)
        #expect(targetWorkspace.focusedPanelId == targetSurfaceId)

        let missingSurface = UUID()
        #expect(
            manager.focusWorkspaceSurfaceForAction(
                workspaceId: targetWorkspace.id,
                surfaceId: missingSurface
            ) == .surfaceNotFound
        )
        #expect(manager.selectedTabId == targetWorkspace.id)
        #expect(
            manager.focusWorkspaceSurfaceForAction(
                workspaceId: UUID(),
                surfaceId: targetSurfaceId
            ) == .workspaceNotFound
        )
        #expect(manager.selectedTabId == targetWorkspace.id)
    }
}
