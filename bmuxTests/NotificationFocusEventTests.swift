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
    @Test(arguments: [false, true])
    func focusedPanelDismissesUnreadAfterFocusBroadcast(fromNotification: Bool) throws {
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
        let targetPanelID = fromNotification ? rightPanel.id : leftPanelId
        if fromNotification {
            workspace.focusPanel(leftPanelId)
            FocusSurfaceBroadcaster.shared.flush()
        }
        store.restoreSessionNotifications([
            TerminalNotification(id: UUID(), tabId: workspace.id, surfaceId: targetPanelID,
                title: "Unread", subtitle: "", body: "Left pane should dismiss attention when focused",
                createdAt: Date(), isRead: false)
        ], forTabId: workspace.id)

        #expect(store.hasUnreadNotification(forTabId: workspace.id, surfaceId: targetPanelID))
        #expect(store.hasVisibleNotificationIndicator(forTabId: workspace.id, surfaceId: targetPanelID))
        #expect(workspace.focusedPanelId == (fromNotification ? leftPanelId : rightPanel.id))
        #expect(workspace.tmuxWorkspaceFlashToken == 0)

        if fromNotification {
            #expect(manager.focusTabFromNotification(workspace.id, surfaceId: targetPanelID))
        } else {
            workspace.focusPanel(targetPanelID)
            #expect(store.hasUnreadNotification(forTabId: workspace.id, surfaceId: targetPanelID),
                    "The shared focus broadcaster defers delivery until its scheduled flush")
        }
        #expect(workspace.focusedPanelId == targetPanelID)
        FocusSurfaceBroadcaster.shared.flush()

        #expect(!store.hasUnreadNotification(forTabId: workspace.id, surfaceId: targetPanelID))
        #expect(!store.hasVisibleNotificationIndicator(forTabId: workspace.id, surfaceId: targetPanelID))
        #expect(workspace.tmuxWorkspaceFlashToken == 1)
        #expect(workspace.tmuxWorkspaceFlashPanelId == targetPanelID)
        #expect(workspace.tmuxWorkspaceFlashReason == .notificationDismiss)
    }
}
