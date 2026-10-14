import AppKit
import Testing
#if canImport(bmux_DEV)
@testable import bmux_DEV
#else
@testable import bmux
#endif

/// The focus action and its existing deferred broadcaster share one synchronous fixture scope.
@MainActor
struct NotificationFocusEventTests {
    @Test func focusedPanelDismissesUnreadAfterFocusBroadcast() throws {
        // Deliver prior work against its original composition before installing owned state.
        FocusSurfaceBroadcaster.shared.flush()
        let previousDelegate = AppDelegate.shared
        let appDelegate = previousDelegate ?? AppDelegate()
        let manager = TabManager()
        let store = TerminalNotificationStore.shared
        let previousManager = appDelegate.tabManager
        let previousStore = appDelegate.notificationStore
        let previousFocus = AppFocusState.overrideIsFocused
        let defaults = UserDefaults.standard
        let keys = [TmuxOverlayExperimentSettings.enabledKey, TmuxOverlayExperimentSettings.targetKey]
        let persisted = keys.map {
            CFPreferencesCopyValue($0 as CFString, kCFPreferencesCurrentApplication,
                                   kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        }
        appDelegate.tabManager = manager
        appDelegate.notificationStore = store
        AppFocusState.overrideIsFocused = true
        defaults.set(true, forKey: keys[0])
        defaults.set(TmuxOverlayExperimentTarget.bonsplitPane.rawValue, forKey: keys[1])
        defer {
            for workspace in manager.tabs {
                store.clearNotifications(forTabId: workspace.id)
                workspace.teardownRemoteConnection()
                workspace.teardownAllPanels()
            }
            FocusSurfaceBroadcaster.shared.flush()
            appDelegate.tabManager = previousManager
            appDelegate.notificationStore = previousStore
            AppDelegate.shared = previousDelegate
            AppFocusState.overrideIsFocused = previousFocus
            for (key, value) in zip(keys, persisted) {
                if let value { defaults.set(value, forKey: key) }
                else { defaults.removeObject(forKey: key) }
            }
        }
        let workspace = try #require(manager.selectedWorkspace)
        let leftPanelId = try #require(workspace.focusedPanelId)
        let rightPanel = try #require(workspace.newTerminalSplit(from: leftPanelId, orientation: .horizontal))
        store.restoreSessionNotifications([
            TerminalNotification(id: UUID(), tabId: workspace.id, surfaceId: leftPanelId,
                title: "Unread", subtitle: "", body: "Left pane should dismiss attention when focused",
                createdAt: Date(), isRead: false)
        ], forTabId: workspace.id)

        #expect(store.hasUnreadNotification(forTabId: workspace.id, surfaceId: leftPanelId))
        #expect(store.hasVisibleNotificationIndicator(forTabId: workspace.id, surfaceId: leftPanelId))
        #expect(workspace.focusedPanelId == rightPanel.id)
        #expect(workspace.tmuxWorkspaceFlashToken == 0)

        workspace.focusPanel(leftPanelId)
        #expect(workspace.focusedPanelId == leftPanelId)
        #expect(store.hasUnreadNotification(forTabId: workspace.id, surfaceId: leftPanelId),
                "The shared focus broadcaster defers delivery until its scheduled flush")
        FocusSurfaceBroadcaster.shared.flush()

        #expect(!store.hasUnreadNotification(forTabId: workspace.id, surfaceId: leftPanelId))
        #expect(!store.hasVisibleNotificationIndicator(forTabId: workspace.id, surfaceId: leftPanelId))
        #expect(workspace.tmuxWorkspaceFlashToken == 1)
        #expect(workspace.tmuxWorkspaceFlashPanelId == leftPanelId)
        #expect(workspace.tmuxWorkspaceFlashReason == .notificationDismiss)
    }
}
