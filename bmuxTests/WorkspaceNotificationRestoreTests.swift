import AppKit
import Testing
#if canImport(bmux_DEV)
@testable import bmux_DEV
#else
@testable import bmux
#endif

@MainActor
struct WorkspaceNotificationRestoreTests {
    @Test func sessionRestorePreservesNotificationUnreadIndicator() throws {
        try withFixture { workspace, restored, store in
            let panelId = try #require(workspace.focusedPanelId)
            store.restoreSessionNotifications([
                TerminalNotification(
                    id: UUID(),
                    tabId: workspace.id,
                    surfaceId: panelId,
                    title: "Unread",
                    subtitle: "",
                    body: "",
                    createdAt: Date(),
                    isRead: false
                ),
            ], forTabId: workspace.id)

            #expect(store.hasVisibleNotificationIndicator(forTabId: workspace.id, surfaceId: panelId))

            let snapshot = workspace.sessionSnapshot(includeScrollback: false)
            store.clearNotifications(forTabId: workspace.id)

            restored.restoreSessionSnapshot(snapshot)

            let restoredPanelId = try #require(restored.focusedPanelId)
            let restoredTabId = try #require(restored.surfaceIdFromPanelId(restoredPanelId))
            #expect(!restored.manualUnreadPanelIds.contains(restoredPanelId))
            #expect(!restored.hasRestoredUnreadIndicator(panelId: restoredPanelId))
            #expect(store.hasUnreadNotification(forTabId: restored.id, surfaceId: restoredPanelId))
            #expect(store.notifications.filter { $0.tabId == restored.id }.count == 1)
            #expect(restored.bonsplitController.tab(restoredTabId)?.showsNotificationBadge ?? false)
            #expect(!store.hasManualUnread(forTabId: restored.id))
            #expect(store.unreadCount(forTabId: restored.id) == 1)

            restored.markPanelRead(restoredPanelId)

            #expect(!restored.hasRestoredUnreadIndicator(panelId: restoredPanelId))
            #expect(restored.bonsplitController.tab(restoredTabId)?.showsNotificationBadge == false)
            #expect(!store.hasManualUnread(forTabId: restored.id))
            #expect(store.unreadCount(forTabId: restored.id) == 0)
        }
    }

    @Test func sessionRestorePreservesManualAndNotificationPanelUnreadIndependently() throws {
        try withFixture { workspace, restored, store in
            let panelId = try #require(workspace.focusedPanelId)
            workspace.markPanelUnread(panelId)
            store.restoreSessionNotifications([
                TerminalNotification(
                    id: UUID(),
                    tabId: workspace.id,
                    surfaceId: panelId,
                    title: "Unread",
                    subtitle: "",
                    body: "",
                    createdAt: Date(),
                    isRead: false
                ),
            ], forTabId: workspace.id)

            let snapshot = workspace.sessionSnapshot(includeScrollback: false)
            store.clearNotifications(forTabId: workspace.id)

            restored.restoreSessionSnapshot(snapshot)

            let restoredPanelId = try #require(restored.focusedPanelId)
            #expect(restored.manualUnreadPanelIds.contains(restoredPanelId))
            #expect(!restored.hasRestoredUnreadIndicator(panelId: restoredPanelId))
            #expect(store.hasUnreadNotification(forTabId: restored.id, surfaceId: restoredPanelId))
            #expect(store.notifications.filter { $0.tabId == restored.id }.count == 1)

            restored.markPanelRead(restoredPanelId)

            #expect(!restored.manualUnreadPanelIds.contains(restoredPanelId))
            #expect(!restored.hasRestoredUnreadIndicator(panelId: restoredPanelId))
            #expect(!store.hasUnreadNotification(forTabId: restored.id, surfaceId: restoredPanelId))
            #expect(store.unreadCount(forTabId: restored.id) == 0)
        }
    }

    @Test func sessionRestorePreservesManualAndNotificationWorkspaceUnreadIndependently() throws {
        try withFixture { workspace, restored, store in
            store.restoreSessionNotifications([
                TerminalNotification(
                    id: UUID(),
                    tabId: workspace.id,
                    surfaceId: nil,
                    title: "Workspace unread",
                    subtitle: "",
                    body: "",
                    createdAt: Date(),
                    isRead: false
                ),
            ], forTabId: workspace.id)
            store.markUnread(forTabId: workspace.id)

            let snapshot = workspace.sessionSnapshot(includeScrollback: false)
            store.clearNotifications(forTabId: workspace.id)

            restored.restoreSessionSnapshot(snapshot)

            #expect(store.hasManualUnread(forTabId: restored.id))
            #expect(!store.hasRestoredUnreadIndicator(forTabId: restored.id))
            #expect(store.hasUnreadNotification(forTabId: restored.id, surfaceId: nil))
            #expect(store.unreadCount(forTabId: restored.id) == 2)

            store.clearManualUnread(forTabId: restored.id)

            #expect(!store.hasManualUnread(forTabId: restored.id))
            #expect(!store.hasRestoredUnreadIndicator(forTabId: restored.id))
            #expect(store.hasUnreadNotification(forTabId: restored.id, surfaceId: nil))
            #expect(store.unreadCount(forTabId: restored.id) == 1)

            store.markRead(forTabId: restored.id)

            #expect(!store.hasRestoredUnreadIndicator(forTabId: restored.id))
            #expect(store.unreadCount(forTabId: restored.id) == 0)
        }
    }

    @Test func sessionRestorePreservesWorkspaceNotificationUnreadIndicatorWithoutManualState() throws {
        try withFixture { workspace, restored, store in
            store.restoreSessionNotifications([
                TerminalNotification(
                    id: UUID(),
                    tabId: workspace.id,
                    surfaceId: nil,
                    title: "Workspace unread",
                    subtitle: "",
                    body: "",
                    createdAt: Date(),
                    isRead: false
                ),
            ], forTabId: workspace.id)

            let snapshot = workspace.sessionSnapshot(includeScrollback: false)
            store.clearNotifications(forTabId: workspace.id)

            restored.restoreSessionSnapshot(snapshot)

            #expect(!store.hasManualUnread(forTabId: restored.id))
            #expect(!store.hasRestoredUnreadIndicator(forTabId: restored.id))
            #expect(store.hasUnreadNotification(forTabId: restored.id, surfaceId: nil))
            #expect(store.unreadCount(forTabId: restored.id) == 1)

            store.markRead(forTabId: restored.id)

            #expect(!store.hasRestoredUnreadIndicator(forTabId: restored.id))
            #expect(store.unreadCount(forTabId: restored.id) == 0)
        }
    }

    @Test func legacyPanelIndicatorWithoutNotificationRecordsStillRestores() throws {
        try withFixture { workspace, restored, store in
            let panelId = try #require(workspace.focusedPanelId)
            store.setFocusedReadIndicator(forTabId: workspace.id, surfaceId: panelId)
            let snapshot = workspace.sessionSnapshot(includeScrollback: false)
            #expect(store.notifications(forTabId: workspace.id, surfaceId: panelId).isEmpty)

            restored.restoreSessionSnapshot(snapshot)
            let restoredPanelId = try #require(restored.focusedPanelId)
            let restoredTabId = try #require(restored.surfaceIdFromPanelId(restoredPanelId))
            #expect(restored.hasRestoredUnreadIndicator(panelId: restoredPanelId))
            #expect(restored.bonsplitController.tab(restoredTabId)?.showsNotificationBadge == true)
            #expect(!store.hasUnreadNotification(forTabId: restored.id, surfaceId: restoredPanelId))
            #expect(store.unreadCount(forTabId: restored.id) == 0)

            restored.markPanelRead(restoredPanelId)
            #expect(!restored.hasRestoredUnreadIndicator(panelId: restoredPanelId))
            #expect(restored.bonsplitController.tab(restoredTabId)?.showsNotificationBadge == false)
            #expect(store.unreadCount(forTabId: restored.id) == 0)
        }
    }

    private func withFixture(
        _ body: (Workspace, Workspace, TerminalNotificationStore) throws -> Void
    ) throws {
        let appDelegate = try #require(AppDelegate.shared)
        let fixture = NotificationRestoreFixture(appDelegate: appDelegate, store: .shared)
        try fixture.withWorkspaces(body)
    }
}
