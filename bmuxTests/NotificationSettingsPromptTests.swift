import AppKit
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@MainActor
struct NotificationSettingsPromptTests {
    @Test func promptRetriesUntilWindowExists() throws {
        let store = TerminalNotificationStore.shared
        let alert = NotificationSettingsPromptAlertProbe()
        var queuedRetries: [() -> Void] = []
        var promptWindow: NSWindow?
        var openedURLs: [URL] = []
        store.configureNotificationSettingsPromptHooksForTesting(
            windowProvider: { promptWindow },
            alertFactory: { alert },
            scheduler: { _, block in queuedRetries.append(block) },
            urlOpener: { openedURLs.append($0) }
        )
        defer {
            store.resetNotificationSettingsPromptHooksForTesting()
            queuedRetries.removeAll()
            promptWindow?.close()
        }

        store.promptToEnableNotificationsForTesting()
        #expect(alert.beginSheetModalCallCount == 0)
        #expect(alert.runModalCallCount == 0)
        #expect(queuedRetries.count == 1)
        try #require(!queuedRetries.isEmpty)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 320),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        // Swift retains this never-presented window through explicit close and scope exit.
        window.isReleasedWhenClosed = false
        promptWindow = window
        queuedRetries.removeFirst()()

        #expect(alert.beginSheetModalCallCount == 1)
        #expect(alert.runModalCallCount == 0)
        #expect(openedURLs.isEmpty, "Not Now must not open notification settings")
    }

    @Test func promptUsesSheetAndNeverRunsModal() throws {
        let store = TerminalNotificationStore.shared
        let alert = NotificationSettingsPromptAlertProbe()
        alert.response = .alertFirstButtonReturn
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 320),
            styleMask: [.titled], backing: .buffered, defer: false
        )
        // Swift owns this never-presented window through close and scope exit.
        window.isReleasedWhenClosed = false
        var openedURL: URL?
        store.configureNotificationSettingsPromptHooksForTesting(
            windowProvider: { window },
            alertFactory: { alert },
            scheduler: { _, block in block() },
            urlOpener: { openedURL = $0 }
        )
        defer {
            store.resetNotificationSettingsPromptHooksForTesting()
            window.close()
        }

        store.promptToEnableNotificationsForTesting()
        #expect(alert.beginSheetModalCallCount == 1)
        #expect(alert.runModalCallCount == 0)
        let encodedBundleIdentifier = try #require(Bundle.main.bundleIdentifier?
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed))
        #expect(openedURL?.absoluteString ==
            "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=\(encodedBundleIdentifier)")
    }

}
