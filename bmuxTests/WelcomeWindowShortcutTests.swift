import AppKit
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@MainActor
@Suite
struct WelcomeWindowShortcutTests {
    @Test
    func sidebarShortcutsUseSharedToggleCommands() async throws {
        let appDelegate = try #require(AppDelegate.shared)
        #expect(
            KeyboardShortcutSettings.Action.toggleSidebar.label ==
                String(localized: "shortcut.toggleLeftSidebar.label", defaultValue: "Toggle Left Sidebar"),
            "Welcome should expose the shared left-sidebar toggle command"
        )
        #expect(
            KeyboardShortcutSettings.Action.toggleSidebar.defaultShortcut ==
                StoredShortcut(key: "b", command: true, shift: false, option: false, control: false)
        )
        #expect(
            KeyboardShortcutSettings.Action.toggleRightSidebar.label ==
                String(localized: "shortcut.toggleRightSidebar.label", defaultValue: "Toggle Right Sidebar"),
            "Welcome should expose the shared right-sidebar toggle command, not a File Explorer-only action"
        )
        #expect(
            KeyboardShortcutSettings.Action.toggleRightSidebar.defaultShortcut ==
                StoredShortcut(key: "b", command: true, shift: false, option: true, control: false)
        )

        let fixture = WelcomeShortcutWindowFixture(appDelegate: appDelegate)
        defer { fixture.close() }
        let completion = try fixture.routeShortcuts { leftHandled, leftVisible, rightHandled in
            #expect(leftHandled)
            #expect(!leftVisible, "Cmd+B should toggle the Welcome window left sidebar")
            #expect(rightHandled)
        }
        let rightVisible = try await fixture.awaitRightSidebarToggle(completion)
        #expect(rightVisible, "Cmd+Option+B should toggle the Welcome window right sidebar")
    }
}
