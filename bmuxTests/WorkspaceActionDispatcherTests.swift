import Foundation
import Testing
import Bonsplit

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

    @Test func workspaceUnreadActionFiltersStaleDuplicateAndAlreadyMatchingTargets() throws {
        let manager = TabManager()
        let store = TerminalNotificationStore.shared
        store.replaceNotificationsForTesting([])
        defer { store.replaceNotificationsForTesting([]) }

        let first = try #require(manager.tabs.first)
        let second = manager.addWorkspace()
        let third = manager.addWorkspace()
        let missingWorkspaceId = UUID()
        store.markUnread(forTabId: second.id)

        let markedUnread = manager.setWorkspacesUnreadForAction(
            workspaceIds: [second.id, missingWorkspaceId, third.id, third.id],
            unread: true,
            notificationStore: store
        )

        #expect(markedUnread == [third.id])
        #expect(!store.workspaceIsUnread(forTabId: first.id))
        #expect(store.workspaceIsUnread(forTabId: second.id))
        #expect(store.workspaceIsUnread(forTabId: third.id))

        let markedRead = manager.setWorkspacesUnreadForAction(
            workspaceIds: [second.id, third.id, missingWorkspaceId, second.id],
            unread: false,
            notificationStore: store
        )

        #expect(markedRead == [second.id, third.id])
        #expect(!store.workspaceIsUnread(forTabId: second.id))
        #expect(!store.workspaceIsUnread(forTabId: third.id))
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

    @Test func workspaceActionReorderPlansRelativeTargetsAndDryRun() throws {
        let manager = TabManager()
        _ = manager.addWorkspace()
        _ = manager.addWorkspace()
        let originalOrder = manager.tabs.map(\.id)
        #expect(originalOrder.count == 3)

        let dryRunResult = manager.reorderWorkspaceForAction(
            tabId: originalOrder[0],
            target: .after(originalOrder[2]),
            dryRun: true
        )
        guard case .resolved(let dryRunPlan) = dryRunResult else {
            Issue.record("Expected dry-run reorder plan")
            return
        }
        #expect(dryRunPlan.workspaceId == originalOrder[0])
        #expect(dryRunPlan.fromIndex == 0)
        #expect(dryRunPlan.toIndex == 2)
        #expect(manager.tabs.map(\.id) == originalOrder)

        let appliedResult = manager.reorderWorkspaceForAction(
            tabId: originalOrder[0],
            target: .after(originalOrder[2])
        )
        guard case .resolved(let appliedPlan) = appliedResult else {
            Issue.record("Expected applied reorder plan")
            return
        }
        #expect(appliedPlan == dryRunPlan)
        #expect(manager.tabs.map(\.id) == [originalOrder[1], originalOrder[2], originalOrder[0]])
        #expect(manager.reorderWorkspaceForAction(tabId: UUID(), target: .end) == .notFound)
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

        #expect(manager.closeWorkspaceForAction(tabId: first.id, allowPinned: true) == .protected)
        #expect(manager.tabs.map(\.id) == [first.id])
    }

    @Test func workspaceSurfaceCloseActionRecordsHistoryAndProtectsLastSurface() throws {
        ClosedItemHistoryStore.shared.removeAll()
        defer { ClosedItemHistoryStore.shared.removeAll() }

        let manager = TabManager()
        let workspace = try #require(manager.tabs.first)
        let firstSurfaceId = try #require(workspace.focusedPanelId)

        #expect(workspace.closeSurfaceForAction(surfaceId: UUID(), force: true) == .surfaceNotFound)
        #expect(workspace.closeSurfaceForAction(surfaceId: firstSurfaceId, force: true) == .lastSurface)

        let pane = try #require(workspace.bonsplitController.focusedPaneId)
        let panel = try #require(workspace.newTerminalSurface(inPane: pane, focus: true))
        workspace.setPanelCustomTitle(panelId: panel.id, title: "Surface Action Terminal")

        #expect(workspace.closeSurfaceForAction(surfaceId: panel.id, force: true) == .closed)
        #expect(workspace.panels[panel.id] == nil)
        #expect(ClosedItemHistoryStore.shared.menuSnapshot().items.map(\.title) == ["Surface Action Terminal"])
    }

    @Test func browserWebViewCloseActionPreservesLegacyBrowserRestorePolicy() throws {
        ClosedItemHistoryStore.shared.removeAll()
        defer { ClosedItemHistoryStore.shared.removeAll() }

        let manager = TabManager()
        let workspace = try #require(manager.tabs.first)
        let terminalSurfaceId = try #require(workspace.focusedPanelId)
        let pane = try #require(workspace.bonsplitController.focusedPaneId)
        let browser = try #require(workspace.newBrowserSurface(
            inPane: pane,
            url: URL(string: "https://example.com/self-close-action"),
            focus: true
        ))

        #expect(workspace.closeBrowserSurfaceFromWebViewForAction(surfaceId: UUID()) == .surfaceNotFound)
        #expect(workspace.closeBrowserSurfaceFromWebViewForAction(surfaceId: terminalSurfaceId) == .surfaceNotFound)
        #expect(workspace.closeBrowserSurfaceFromWebViewForAction(surfaceId: browser.id) == .closed)
        #expect(workspace.panels[browser.id] == nil)
        #expect(ClosedItemHistoryStore.shared.canReopen == false)
    }

    @Test func tabManagerCloseSurfaceAdapterUsesSurfaceCloseActionPath() throws {
        ClosedItemHistoryStore.shared.removeAll()
        defer { ClosedItemHistoryStore.shared.removeAll() }

        let manager = TabManager()
        let workspace = try #require(manager.tabs.first)
        let pane = try #require(workspace.bonsplitController.focusedPaneId)
        let panel = try #require(workspace.newTerminalSurface(inPane: pane, focus: true))
        workspace.setPanelCustomTitle(panelId: panel.id, title: "Adapter Close Terminal")

        #expect(manager.closeSurface(tabId: workspace.id, surfaceId: panel.id))
        #expect(workspace.panels[panel.id] == nil)
        #expect(ClosedItemHistoryStore.shared.menuSnapshot().items.map(\.title) == ["Adapter Close Terminal"])
    }

    @Test func workspaceSurfaceReorderActionResolvesTargetsInsidePane() throws {
        let manager = TabManager()
        let workspace = try #require(manager.tabs.first)
        let pane = try #require(workspace.bonsplitController.focusedPaneId)
        let firstPanelId = try #require(workspace.focusedPanelId)
        let secondPanel = try #require(
            workspace.createTerminalSurfaceForAction(inPane: pane, focus: false).panel
        )
        let thirdPanel = try #require(
            workspace.createTerminalSurfaceForAction(inPane: pane, focus: false).panel
        )

        #expect(
            workspace.reorderSurfaceForAction(
                panelId: thirdPanel.id,
                target: .before(secondPanel.id),
                focus: false
            ) == .reordered(paneId: pane)
        )
        #expect(panelOrder(in: workspace, pane: pane) == [firstPanelId, thirdPanel.id, secondPanel.id])

        #expect(
            workspace.reorderSurfaceForAction(
                panelId: firstPanelId,
                target: .after(secondPanel.id),
                focus: false
            ) == .reordered(paneId: pane)
        )
        #expect(panelOrder(in: workspace, pane: pane) == [thirdPanel.id, secondPanel.id, firstPanelId])

        #expect(
            workspace.reorderSurfaceForAction(
                panelId: firstPanelId,
                target: .index(0),
                focus: false
            ) == .reordered(paneId: pane)
        )
        #expect(panelOrder(in: workspace, pane: pane) == [firstPanelId, thirdPanel.id, secondPanel.id])
    }

    @Test func workspaceSurfaceReorderActionRejectsInvalidTargets() throws {
        let manager = TabManager()
        let workspace = try #require(manager.tabs.first)
        let pane = try #require(workspace.bonsplitController.focusedPaneId)
        let firstPanelId = try #require(workspace.focusedPanelId)
        let secondPanel = try #require(
            workspace.createTerminalSurfaceForAction(inPane: pane, focus: false).panel
        )
        let splitPanel = try #require(
            workspace.createTerminalSplitForAction(
                from: firstPanelId,
                orientation: .horizontal,
                focus: false
            ).panel
        )

        #expect(
            workspace.reorderSurfaceForAction(
                panelId: UUID(),
                target: .index(0),
                focus: false
            ) == .surfaceNotFound
        )
        #expect(
            workspace.reorderSurfaceForAction(
                panelId: secondPanel.id,
                target: .before(splitPanel.id),
                focus: false
            ) == .anchorNotInSamePane
        )
    }

    @Test func workspaceSurfaceMoveActionMovesBetweenPanes() throws {
        let manager = TabManager()
        let workspace = try #require(manager.tabs.first)
        let sourcePane = try #require(workspace.bonsplitController.focusedPaneId)
        let firstPanelId = try #require(workspace.focusedPanelId)
        let movedPanel = try #require(
            workspace.createTerminalSurfaceForAction(inPane: sourcePane, focus: false).panel
        )
        let targetPanel = try #require(
            workspace.createTerminalSplitForAction(
                from: firstPanelId,
                orientation: .horizontal,
                focus: false
            ).panel
        )
        let targetPane = try #require(workspace.paneId(forPanelId: targetPanel.id))

        #expect(
            workspace.moveSurfaceForAction(
                panelId: movedPanel.id,
                toPane: targetPane,
                atIndex: 0,
                focus: false
            ) == .moved(paneId: targetPane)
        )
        #expect(workspace.paneId(forPanelId: movedPanel.id) == targetPane)
        #expect(panelOrder(in: workspace, pane: targetPane) == [movedPanel.id, targetPanel.id])
        #expect(panelOrder(in: workspace, pane: sourcePane) == [firstPanelId])
    }

    @Test func workspaceSurfaceMoveActionRejectsInvalidTargets() throws {
        let manager = TabManager()
        let workspace = try #require(manager.tabs.first)
        let pane = try #require(workspace.bonsplitController.focusedPaneId)
        let panel = try #require(
            workspace.createTerminalSurfaceForAction(inPane: pane, focus: false).panel
        )

        #expect(
            workspace.moveSurfaceForAction(
                panelId: UUID(),
                toPane: pane,
                focus: false
            ) == .surfaceNotFound
        )
        #expect(
            workspace.moveSurfaceForAction(
                panelId: panel.id,
                toPane: PaneID(id: UUID()),
                focus: false
            ) == .targetPaneNotFound
        )
        #expect(workspace.paneId(forPanelId: panel.id) == pane)
    }

    @Test func workspaceSurfacePinActionRejectsMissingAndTogglesPinnedState() throws {
        let manager = TabManager()
        let workspace = try #require(manager.tabs.first)
        let pane = try #require(workspace.bonsplitController.focusedPaneId)
        let panel = try #require(workspace.newTerminalSurface(inPane: pane, focus: true))

        #expect(!workspace.setSurfacePinnedForAction(surfaceId: UUID(), pinned: true))
        #expect(!workspace.isPanelPinned(panel.id))

        #expect(workspace.setSurfacePinnedForAction(surfaceId: panel.id, pinned: true))
        #expect(workspace.isPanelPinned(panel.id))
        #expect(workspace.toggleSurfacePinnedForAction(surfaceId: panel.id) == false)
        #expect(!workspace.isPanelPinned(panel.id))
        #expect(workspace.toggleSurfacePinnedForAction(surfaceId: UUID()) == nil)
    }

    @Test func workspaceSurfaceUnreadActionRejectsMissingAndTogglesUnreadState() throws {
        let manager = TabManager()
        let workspace = try #require(manager.tabs.first)
        let pane = try #require(workspace.bonsplitController.focusedPaneId)
        let panel = try #require(workspace.newTerminalSurface(inPane: pane, focus: true))

        #expect(workspace.surfaceIsUnreadForAction(surfaceId: UUID()) == nil)
        #expect(!workspace.setSurfaceUnreadForAction(surfaceId: UUID(), unread: true))
        #expect(workspace.surfaceIsUnreadForAction(surfaceId: panel.id) == false)

        #expect(workspace.setSurfaceUnreadForAction(surfaceId: panel.id, unread: true))
        #expect(workspace.surfaceIsUnreadForAction(surfaceId: panel.id) == true)
        #expect(workspace.toggleSurfaceUnreadForAction(surfaceId: panel.id) == false)
        #expect(workspace.surfaceIsUnreadForAction(surfaceId: panel.id) == false)
        #expect(workspace.toggleSurfaceUnreadForAction(surfaceId: UUID()) == nil)
    }

    @Test func workspaceSurfaceLayoutActionsRejectMissingAndToggleState() throws {
        let manager = TabManager()
        let workspace = try #require(manager.tabs.first)
        let firstPanelId = try #require(workspace.focusedPanelId)
        let panel = try #require(workspace.newTerminalSplit(from: firstPanelId, orientation: .horizontal))
        let pane = try #require(workspace.paneId(forPanelId: panel.id))

        #expect(!workspace.toggleSurfaceSplitZoomForAction(surfaceId: UUID()))
        #expect(workspace.toggleSurfaceFullWidthTabForAction(surfaceId: UUID()) == nil)

        #expect(!workspace.bonsplitController.isSplitZoomed)
        #expect(workspace.toggleSurfaceSplitZoomForAction(surfaceId: panel.id))
        #expect(workspace.bonsplitController.isSplitZoomed)
        #expect(workspace.toggleSurfaceSplitZoomForAction(surfaceId: panel.id))
        #expect(!workspace.bonsplitController.isSplitZoomed)

        #expect(!workspace.bonsplitController.isFullWidthTabMode(inPane: pane))
        #expect(workspace.toggleSurfaceFullWidthTabForAction(surfaceId: panel.id) == true)
        #expect(workspace.bonsplitController.isFullWidthTabMode(inPane: pane))
        #expect(workspace.toggleSurfaceFullWidthTabForAction(surfaceId: panel.id) == false)
        #expect(!workspace.bonsplitController.isFullWidthTabMode(inPane: pane))
    }

    @Test func workspaceTerminalSurfaceCreationActionCreatesInPaneWithoutStealingFocus() throws {
        let manager = TabManager()
        let workspace = try #require(manager.tabs.first)
        let originalPanelId = try #require(workspace.focusedPanelId)
        let pane = try #require(workspace.bonsplitController.focusedPaneId)

        let result = workspace.createTerminalSurfaceForAction(
            inPane: pane,
            focus: false,
            initialInput: "echo action surface\n",
            autoRefreshMetadata: false,
            allowTextBoxFocusDefault: false
        )

        guard case .created(let panel) = result else {
            Issue.record("Expected terminal surface action to create a panel")
            return
        }
        #expect(panel.id != originalPanelId)
        #expect(workspace.panels[panel.id] != nil)
        #expect(workspace.focusedPanelId == originalPanelId)
        #expect(workspace.bonsplitController.selectedTab(inPane: pane)?.id == workspace.surfaceIdFromPanelId(originalPanelId))
    }

    @Test func workspaceTerminalSplitCreationActionCreatesSplitWithoutStealingFocus() throws {
        let manager = TabManager()
        let workspace = try #require(manager.tabs.first)
        let originalPanelId = try #require(workspace.focusedPanelId)
        let originalPane = try #require(workspace.paneId(forPanelId: originalPanelId))

        let result = workspace.createTerminalSplitForAction(
            from: originalPanelId,
            orientation: .horizontal,
            focus: false,
            initialInput: "echo action split\n",
            startupEnvironment: ["BMUX_AGENT_MANAGED_SUBAGENT": "1"],
            allowTextBoxFocusDefault: false
        )

        guard case .created(let panel) = result else {
            Issue.record("Expected terminal split action to create a panel")
            return
        }
        let splitPane = try #require(workspace.paneId(forPanelId: panel.id))

        #expect(panel.id != originalPanelId)
        #expect(panel.surface.initialInput == "echo action split\n")
        #expect(panel.surface.startupEnvironmentValue("BMUX_AGENT_MANAGED_SUBAGENT") == "1")
        #expect(splitPane != originalPane)
        #expect(workspace.focusedPanelId == originalPanelId)
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

    @Test func workspaceSelectionIndexActionRejectsInvalidIndexWithoutChangingSelection() throws {
        let manager = TabManager()
        _ = manager.addWorkspace()
        let targetWorkspace = try #require(manager.tabs.last)

        #expect(manager.selectWorkspaceIndexForAction(1))
        #expect(manager.selectedTabId == targetWorkspace.id)

        #expect(!manager.selectWorkspaceIndexForAction(-1))
        #expect(!manager.selectWorkspaceIndexForAction(manager.tabs.count))
        #expect(manager.selectedTabId == targetWorkspace.id)
    }

    @Test func adjacentWorkspaceSelectionActionCyclesAndCollapsesSidebarSelection() throws {
        let manager = TabManager()
        let firstWorkspace = try #require(manager.tabs.first)
        let secondWorkspace = manager.addWorkspace(select: false, placementOverride: .end)
        let thirdWorkspace = manager.addWorkspace(select: false, placementOverride: .end)
        manager.sidebarMultiSelection.replaceSelection(with: [firstWorkspace.id, thirdWorkspace.id])

        #expect(manager.selectWorkspaceIdForAction(firstWorkspace.id))
        #expect(manager.selectAdjacentWorkspaceForAction(.next) == secondWorkspace.id)
        #expect(manager.selectedTabId == secondWorkspace.id)
        #expect(manager.sidebarSelectedWorkspaceIds == [secondWorkspace.id])

        #expect(manager.selectAdjacentWorkspaceForAction(.previous) == firstWorkspace.id)
        #expect(manager.selectedTabId == firstWorkspace.id)
        #expect(manager.sidebarSelectedWorkspaceIds == [firstWorkspace.id])
    }

    @Test func workspaceCreationActionCreatesThroughWorkspaceModelPolicy() throws {
        let manager = TabManager()
        let originalWorkspace = try #require(manager.tabs.first)
        let browserURL = try #require(URL(string: "https://example.com/action-created"))

        let createdWorkspace = manager.createWorkspaceForAction(
            title: "Action Created",
            initialSurface: .browser,
            initialBrowserURL: browserURL,
            select: false,
            placementOverride: .end,
            autoRefreshMetadata: false
        )

        #expect(createdWorkspace.title == "Action Created")
        #expect(manager.tabs.map(\.id) == [originalWorkspace.id, createdWorkspace.id])
        #expect(manager.selectedTabId == originalWorkspace.id)
        let focusedPanelId = try #require(createdWorkspace.focusedPanelId)
        #expect(createdWorkspace.panels[focusedPanelId]?.panelType == .browser)
    }

    @Test func workspaceCreateSocketPathCreatesWithoutStealingSelectionWhenFocusIsFalse() throws {
        let manager = TabManager()
        let originalWorkspace = try #require(manager.tabs.first)

        let result = TerminalController.shared.v2WorkspaceCreate(
            params: [
                "title": "  Socket Created  ",
                "focus": false,
                "eager_load_terminal": true,
                "auto_refresh_metadata": false
            ],
            tabManager: manager
        )

        guard case .ok(let rawPayload) = result,
              let payload = rawPayload as? [String: Any],
              let workspaceIdString = payload["workspace_id"] as? String,
              let workspaceId = UUID(uuidString: workspaceIdString) else {
            Issue.record("Expected workspace.create to return created workspace payload")
            return
        }
        let createdWorkspace = try #require(manager.tabs.first { $0.id == workspaceId })

        #expect(createdWorkspace.title == "Socket Created")
        #expect(manager.tabs.count == 2)
        #expect(manager.selectedTabId == originalWorkspace.id)
        #expect(payload["workspace_ref"] as? String != nil)
        #expect(payload["surface_id"] as? String == createdWorkspace.focusedPanelId?.uuidString)
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

    @Test func workspacePanelFocusRequestRoutesThroughOwningManagerActionPath() throws {
        let manager = TabManager()
        let originalWorkspace = try #require(manager.tabs.first)
        let targetWorkspace = manager.addWorkspace(select: false)
        let targetSurfaceId = try #require(targetWorkspace.focusedPanelId)

        #expect(manager.selectedTabId == originalWorkspace.id)
        #expect(
            targetWorkspace.requestPanelFocusForAction(
                panelId: targetSurfaceId,
                in: nil
            ) == .focused(workspaceId: targetWorkspace.id, surfaceId: targetSurfaceId)
        )
        #expect(manager.selectedTabId == targetWorkspace.id)
        #expect(targetWorkspace.focusedPanelId == targetSurfaceId)

        let missingSurface = UUID()
        #expect(
            targetWorkspace.requestPanelFocusForAction(
                panelId: missingSurface,
                in: nil
            ) == .surfaceNotFound
        )
        #expect(manager.selectedTabId == targetWorkspace.id)
    }

    private func panelOrder(in workspace: Workspace, pane: PaneID) -> [UUID] {
        workspace.bonsplitController.tabs(inPane: pane).compactMap {
            workspace.panelIdFromSurfaceId($0.id)
        }
    }
}
