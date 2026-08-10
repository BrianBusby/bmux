import XCTest

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@MainActor
final class FocusedNotificationStoreFallbackTests: XCTestCase {
    func testFocusedNotificationStoreMarksUseActiveTabManagerFallback() throws {
        let appDelegate = AppDelegate.shared ?? AppDelegate()
        let manager = TabManager()
        let store = TerminalNotificationStore.shared

        let originalTabManager = appDelegate.tabManager
        let originalNotificationStore = appDelegate.notificationStore

        store.replaceNotificationsForTesting([])
        appDelegate.tabManager = manager
        appDelegate.notificationStore = store

        defer {
            store.replaceNotificationsForTesting([])
            appDelegate.tabManager = originalTabManager
            appDelegate.notificationStore = originalNotificationStore
        }

        let workspace = try XCTUnwrap(manager.selectedWorkspace)

        appDelegate.storeMarkUnread(forTabId: workspace.id)
        XCTAssertTrue(store.workspaceIsUnread(forTabId: workspace.id))

        appDelegate.storeMarkRead(forTabId: workspace.id)
        XCTAssertFalse(store.workspaceIsUnread(forTabId: workspace.id))
    }
}
