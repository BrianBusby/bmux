import Testing
import AppKit
import BmuxUpdater
import CoreGraphics
import SwiftUI
import Bonsplit

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@Suite(.serialized)
final class WorkspaceContentViewVisibilityTests {
    @Test
    @MainActor
    func testMinimalModeToggleDoesNotReevaluateChromeHeavyBodies() async throws {
        let fixture = try MinimalModeBodyFixture(eventTimeout: .seconds(1))
        defer { fixture.close() }
        try await fixture.mount()
        #expect(fixture.contentViewBody > 0)
        #expect(fixture.workspaceContentBody > 0)
        #expect(fixture.workspaceRailBody > 0)

        fixture.resetCounts()
        try await fixture.switchToMinimalMode()
        #expect(fixture.contentViewBody == 0, "Minimal-mode toggles must not re-evaluate the whole ContentView body.")
        #expect(fixture.workspaceContentBody == 0, "Minimal-mode toggles must not re-evaluate WorkspaceContentView/Bonsplit content.")
        #expect(fixture.workspaceRailBody == 0, "Minimal-mode toggles must not rebuild the workspace rail body.")
    }

    @Test
    func testNonSelectedNonRetiringWorkspaceIsFullyHidden() {
        #expect(
            MountedWorkspacePresentation.resolve(
                isSelectedWorkspace: false,
                isRetiringWorkspace: false
            ) ==
            MountedWorkspacePresentation(
                isRenderedVisible: false,
                isPanelVisible: false,
                renderOpacity: 0
            )
        )
    }

    @Test
    func testRetiringWorkspaceStaysPanelVisibleDuringHandoff() {
        #expect(
            MountedWorkspacePresentation.resolve(
                isSelectedWorkspace: false,
                isRetiringWorkspace: true
            ) ==
            MountedWorkspacePresentation(
                isRenderedVisible: true,
                isPanelVisible: true,
                renderOpacity: 1
            )
        )
    }

    @Test
    func testPanelVisibleInUIReturnsFalseWhenWorkspaceHidden() {
        #expect(
            !WorkspaceContentView.panelVisibleInUI(
                isWorkspaceVisible: false,
                isSelectedInPane: true,
                isFocused: true
            )
        )
    }

    @Test
    func testPanelVisibleInUIReturnsTrueForSelectedPanel() {
        #expect(
            WorkspaceContentView.panelVisibleInUI(
                isWorkspaceVisible: true,
                isSelectedInPane: true,
                isFocused: false
            )
        )
    }

    @Test
    func testPanelVisibleInUIReturnsTrueForFocusedPanelDuringTransientSelectionGap() {
        #expect(
            WorkspaceContentView.panelVisibleInUI(
                isWorkspaceVisible: true,
                isSelectedInPane: false,
                isFocused: true
            )
        )
    }

    @Test
    func testPanelVisibleInUIReturnsFalseWhenNeitherSelectedNorFocused() {
        #expect(
            !WorkspaceContentView.panelVisibleInUI(
                isWorkspaceVisible: true,
                isSelectedInPane: false,
                isFocused: false
            )
        )
    }

    @Test
    func testTmuxWorkspacePaneOverlayRectReturnsMatchingPaneFrame() {
        let paneID = PaneID(id: UUID())
        let snapshot = LayoutSnapshot(
            containerFrame: PixelRect(x: 200, y: 32, width: 1200, height: 800),
            panes: [
                PaneGeometry(
                    paneId: paneID.id.uuidString,
                    frame: PixelRect(x: 877.5, y: 32, width: 500, height: 320),
                    selectedTabId: nil,
                    tabIds: []
                )
            ],
            focusedPaneId: paneID.id.uuidString,
            timestamp: 0
        )

        #expect(
            WorkspaceContentView.tmuxWorkspacePaneOverlayRect(
                layoutSnapshot: snapshot,
                paneId: paneID
            ) ==
            CGRect(x: 677.5, y: 28, width: 500, height: 292)
        )
    }

    @Test
    @MainActor
    func testTmuxWorkspacePaneUnreadRectsIncludeFocusedReadIndicator() throws {
        let appDelegate = AppDelegate.shared ?? AppDelegate()
        let manager = TabManager()
        let store = TerminalNotificationStore.shared

        let originalTabManager = appDelegate.tabManager
        let originalNotificationStore = appDelegate.notificationStore

        store.replaceNotificationsForTesting([])
        store.configureNotificationDeliveryHandlerForTesting { _, _ in }
        appDelegate.tabManager = manager
        appDelegate.notificationStore = store

        defer {
            store.replaceNotificationsForTesting([])
            store.resetNotificationDeliveryHandlerForTesting()
            appDelegate.tabManager = originalTabManager
            appDelegate.notificationStore = originalNotificationStore
        }

        let workspace = try #require(manager.selectedWorkspace, "Expected selected workspace geometry")
        let panelId = try #require(workspace.focusedPanelId, "Expected selected workspace geometry")
        let surfaceId = try #require(workspace.surfaceIdFromPanelId(panelId), "Expected selected workspace geometry")
        let paneId = try #require(workspace.paneId(forPanelId: panelId), "Expected selected workspace geometry")

        store.setFocusedReadIndicator(forTabId: workspace.id, surfaceId: panelId)

        let snapshot = LayoutSnapshot(
            containerFrame: PixelRect(x: 200, y: 32, width: 1200, height: 800),
            panes: [
                PaneGeometry(
                    paneId: paneId.id.uuidString,
                    frame: PixelRect(x: 877.5, y: 32, width: 500, height: 320),
                    selectedTabId: surfaceId.uuid.uuidString,
                    tabIds: [surfaceId.uuid.uuidString]
                )
            ],
            focusedPaneId: paneId.id.uuidString,
            timestamp: 0
        )

        #expect(
            WorkspaceContentView.tmuxWorkspacePaneUnreadRects(
                workspace: workspace,
                notificationStore: store,
                layoutSnapshot: snapshot
            ) ==
            [CGRect(x: 677.5, y: 28, width: 500, height: 292)]
        )
    }
}
