import AppKit
#if canImport(bmux_DEV)
@testable import bmux_DEV
#else
@testable import bmux
#endif

/// Scopes the legacy shared-store seam to a synchronous MainActor operation and owned workspaces.
@MainActor
struct NotificationRestoreFixture {
    let appDelegate: AppDelegate
    let store: TerminalNotificationStore

    func withWorkspaces(
        _ body: (Workspace, Workspace, TerminalNotificationStore) throws -> Void
    ) rethrows {
        let originalStore = appDelegate.notificationStore
        appDelegate.notificationStore = store
        let workspace = Workspace()
        let restored = Workspace()
        defer {
            for owned in [restored, workspace] {
                store.clearNotifications(forTabId: owned.id)
                owned.teardownRemoteConnection()
                owned.teardownAllPanels()
            }
            appDelegate.notificationStore = originalStore
        }
        // No suspension: unrelated MainActor tests cannot interleave the shared-store swap.
        try body(workspace, restored, store)
    }
}
