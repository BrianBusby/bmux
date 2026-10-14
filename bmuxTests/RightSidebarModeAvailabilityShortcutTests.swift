import AppKit
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@MainActor
@Suite
struct RightSidebarModeAvailabilityShortcutTests {
    @Test(arguments: [false, true], [false, true])
    func modeShortcutsUsePrivateControlDigitDefaults(feedEnabled: Bool, dockEnabled: Bool) throws {
        try withSettings(feedEnabled: feedEnabled, dockEnabled: dockEnabled) { _ in
            let event1 = try event("1", keyCode: 18)
            #expect(RightSidebarMode.modeShortcut(for: event1) == .files)
            let event2 = try event("2", keyCode: 19)
            #expect(RightSidebarMode.modeShortcut(for: event2) == .find)
            let event3 = try event("3", keyCode: 20)
            #expect(RightSidebarMode.modeShortcut(for: event3) == .sessions)
            let event4 = try event("4", keyCode: 21)
            #expect(RightSidebarMode.modeShortcut(for: event4) == (feedEnabled ? .feed : nil))
            let event5 = try event("5", keyCode: 23)
            #expect(RightSidebarMode.modeShortcut(for: event5) == (dockEnabled ? .dock : nil))
        }
    }

    @Test(arguments: [false, true], [false, true])
    func modeShortcutHonorsActionGate(feedEnabled: Bool, dockEnabled: Bool) throws {
        try withSettings(feedEnabled: feedEnabled, dockEnabled: dockEnabled) { _ in
            let feedEvent = try event("4", keyCode: 21)
            #expect(RightSidebarMode.modeShortcut(for: feedEvent) { $0 != .switchRightSidebarToFeed } == nil)
            #expect(RightSidebarMode.modeShortcut(for: feedEvent) {
                $0 == .switchRightSidebarToFeed
            } == (feedEnabled ? .feed : nil))

            let dockEvent = try event("5", keyCode: 23)
            #expect(RightSidebarMode.modeShortcut(for: dockEvent) { $0 != .switchRightSidebarToDock } == nil)
            #expect(RightSidebarMode.modeShortcut(for: dockEvent) {
                $0 == .switchRightSidebarToDock
            } == (dockEnabled ? .dock : nil))
        }
    }

    @Test(arguments: [false, true], [false, true])
    func modeShortcutUsesSettingsFileBindings(feedEnabled: Bool, dockEnabled: Bool) throws {
        try withSettings(feedEnabled: feedEnabled, dockEnabled: dockEnabled) { settingsFileURL in
            try """
            {
              "shortcuts": {
                "switchRightSidebarToFiles": "ctrl+8"
              }
            }
            """.write(to: settingsFileURL, atomically: true, encoding: .utf8)
            KeyboardShortcutSettings.settingsFileStore.reload()
            KeyboardShortcutSettings.notifySettingsFileDidChange()

            let event8 = try event("8", keyCode: 28)

            #expect(RightSidebarMode.modeShortcut(for: event8) == .files)
            let event1 = try event("1", keyCode: 18)
            #expect(RightSidebarMode.modeShortcut(for: event1) == nil)
            let event2 = try event("2", keyCode: 19)
            #expect(RightSidebarMode.modeShortcut(for: event2) == .find)
            let event3 = try event("3", keyCode: 20)
            #expect(RightSidebarMode.modeShortcut(for: event3) == .sessions)
            let event4 = try event("4", keyCode: 21)
            #expect(RightSidebarMode.modeShortcut(for: event4) == (feedEnabled ? .feed : nil))
            let event5 = try event("5", keyCode: 23)
            #expect(RightSidebarMode.modeShortcut(for: event5) == (dockEnabled ? .dock : nil))
        }
    }

    @Test
    func unsetBetaFlagsKeepFeedAndDockUnavailable() throws {
        try withSettings(feedEnabled: nil, dockEnabled: nil) { _ in
            let event1 = try event("1", keyCode: 18)
            #expect(RightSidebarMode.modeShortcut(for: event1) == .files)
            let event2 = try event("2", keyCode: 19)
            #expect(RightSidebarMode.modeShortcut(for: event2) == .find)
            let event3 = try event("3", keyCode: 20)
            #expect(RightSidebarMode.modeShortcut(for: event3) == .sessions)
            let event4 = try event("4", keyCode: 21)
            #expect(RightSidebarMode.modeShortcut(for: event4) == nil)
            let event5 = try event("5", keyCode: 23)
            #expect(RightSidebarMode.modeShortcut(for: event5) == nil)
        }
    }

    // The legacy shortcut owner reads process-wide settings. Keep setup, assertions,
    // and restoration in one synchronous MainActor turn; never suspend with overrides installed.
    private func withSettings(
        feedEnabled: Bool?,
        dockEnabled: Bool?,
        body: (URL) throws -> Void
    ) throws {
        let originalStore = KeyboardShortcutSettings.settingsFileStore
        let defaults = UserDefaults.standard
        let actions: [KeyboardShortcutSettings.Action] = [
            .switchRightSidebarToFiles, .switchRightSidebarToFind, .switchRightSidebarToSessions,
            .switchRightSidebarToFeed, .switchRightSidebarToDock,
        ]
        let keys = actions.map(\.defaultsKey) + [
            RightSidebarBetaFeatureSettings.feedEnabledKey,
            RightSidebarBetaFeatureSettings.dockEnabledKey,
            "bmux.settingsFile.backups.v1",
            "bmux.settingsFile.importedManagedDefaults.v1",
            SidebarMatchTerminalBackgroundSettings.legacyAppliedSettingsFileDefaultKey,
        ]
        let domain = try #require(Bundle.main.bundleIdentifier)
        let persistedValues = defaults.persistentDomain(forName: domain) ?? [:]
        let savedValues = keys.map { ($0, persistedValues[$0]) }
        let registeredValues = defaults.volatileDomain(forName: UserDefaults.registrationDomain)
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("right-sidebar-shortcuts-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            KeyboardShortcutSettings.settingsFileStore = originalStore
            for (key, value) in savedValues {
                if let value { defaults.set(value, forKey: key) }
                else { defaults.removeObject(forKey: key) }
            }
            defaults.setVolatileDomain(registeredValues, forName: UserDefaults.registrationDomain)
            KeyboardShortcutSettings.notifySettingsFileDidChange()
            do { try FileManager.default.removeItem(at: directory) }
            catch { Issue.record(error, "Could not remove owned shortcut fixture directory") }
        }
        // Clear managed-setting bookkeeping before constructing the isolated store so
        // its reload cannot restore unrelated settings from the previous store's backups.
        defaults.setVolatileDomain(
            registeredValues.filter { !keys.contains($0.key) },
            forName: UserDefaults.registrationDomain
        )
        for key in keys { defaults.removeObject(forKey: key) }
        if let feedEnabled { defaults.set(feedEnabled, forKey: RightSidebarBetaFeatureSettings.feedEnabledKey) }
        if let dockEnabled { defaults.set(dockEnabled, forKey: RightSidebarBetaFeatureSettings.dockEnabledKey) }
        let settingsFileURL = directory.appendingPathComponent("bmux.json", isDirectory: false)
        try "{}".write(to: settingsFileURL, atomically: true, encoding: .utf8)
        KeyboardShortcutSettings.settingsFileStore = KeyboardShortcutSettingsFileStore(
            primaryPath: settingsFileURL.path,
            fallbackPath: nil,
            additionalFallbackPaths: [],
            startWatching: false
        )
        try body(settingsFileURL)
    }

    private func event(_ key: String, keyCode: UInt16) throws -> NSEvent {
        try #require(NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.control],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: 0,
            context: nil,
            characters: key,
            charactersIgnoringModifiers: key,
            isARepeat: false,
            keyCode: keyCode
        ))
    }
}
