import AppKit
import CoreFoundation
import Testing
#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@MainActor
@Suite
struct ShortcutSettingsParsingContractTests {
    @Test(arguments: [false, true])
    func legacyBindingsNormalizeWithoutRuntimeConflictLookup(runtimeSubscriber: Bool) throws {
        try withOwnedSettings { directory in
            let live = directory.appendingPathComponent("live-bmux.json")
            try #"{"shortcuts":{"openBrowser":"cmd+2","globalSearch":"cmd+alt+f"}}"#
                .write(to: live, atomically: true, encoding: .utf8)
            KeyboardShortcutSettings.settingsFileStore = KeyboardShortcutSettingsFileStore(
                primaryPath: live.path, fallbackPath: nil, additionalFallbackPaths: [],
                notificationCenter: NotificationCenter(), startWatching: false
            )
            let commandTwo = StoredShortcut(key: "2", command: true, shift: false, option: false, control: false)
            let commandOne = StoredShortcut(key: "1", command: true, shift: false, option: false, control: false)
            #expect(KeyboardShortcutSettings.shortcut(for: .openBrowser) == commandTwo)
            assertPureNormalization(commandTwo, expected: commandOne)

            let legacy = directory.appendingPathComponent("fallback/settings.json")
            try FileManager.default.createDirectory(at: legacy.deletingLastPathComponent(), withIntermediateDirectories: true)
            try #"{"shortcuts":{"bindings":{"selectWorkspaceByNumber":"cmd+2"}}}"#
                .write(to: legacy, atomically: true, encoding: .utf8)
            let center = NotificationCenter()
            let counts = NotificationCounts()
            let defaultToken = NotificationCenter.default.addObserver(
                forName: KeyboardShortcutSettings.didChangeNotification, object: nil, queue: .main
            ) { _ in
                MainActor.assumeIsolated { counts.standard += 1 }
            }
            let parsingToken = center.addObserver(
                forName: KeyboardShortcutSettings.didChangeNotification, object: nil, queue: .main
            ) { _ in
                MainActor.assumeIsolated { counts.parsing += 1 }
            }
            // Match the runtime subscriber's validation without registering a system hotkey.
            // Store bookkeeping can legitimately invoke this independently of parser policy.
            let runtimeToken = NotificationCenter.default.addObserver(
                forName: UserDefaults.didChangeNotification, object: nil, queue: .main
            ) { _ in
                guard runtimeSubscriber else { return }
                MainActor.assumeIsolated {
                    counts.runtime += 1
                    let shortcut = KeyboardShortcutSettings.shortcut(for: .globalSearch)
                    _ = KeyboardShortcutSettings.Action.globalSearch.normalizedRecordedShortcut(shortcut)
                }
            }
            defer {
                NotificationCenter.default.removeObserver(runtimeToken)
                center.removeObserver(parsingToken)
                NotificationCenter.default.removeObserver(defaultToken)
            }
            let primary = directory.appendingPathComponent("primary/bmux.json")
            let store = KeyboardShortcutSettingsFileStore(
                primaryPath: primary.path, fallbackPath: legacy.path, additionalFallbackPaths: [],
                notificationCenter: center, startWatching: false
            )
            #expect(counts.standard == 0)
            #expect(counts.parsing == 1)
            #expect(store.override(for: .selectWorkspaceByNumber) == commandOne)
            #expect(runtimeSubscriber ? counts.runtime > 0 : counts.runtime == 0)
        }
    }

    private func assertPureNormalization(_ shortcut: StoredShortcut, expected: StoredShortcut) {
        var actions: [String] = []
        let originalObserver = KeyboardShortcutSettings.shortcutLookupObserver
        defer { KeyboardShortcutSettings.shortcutLookupObserver = originalObserver }
        KeyboardShortcutSettings.shortcutLookupObserver = { actions.append($0.rawValue) }
        let normalized = KeyboardShortcutSettings.Action.selectWorkspaceByNumber.normalizedSettingsFileShortcut(shortcut)
        #expect(actions.isEmpty)
        #expect(normalized == expected)
    }

    private func withOwnedSettings(_ body: (URL) throws -> Void) throws {
        let defaults = UserDefaults.standard
        let originalStore = KeyboardShortcutSettings.settingsFileStore
        let keys = [
            "bmux.settingsFile.backups.v1", "bmux.settingsFile.importedManagedDefaults.v1",
            SidebarMatchTerminalBackgroundSettings.legacyAppliedSettingsFileDefaultKey,
        ]
        let saved = keys.map {
            CFPreferencesCopyValue($0 as CFString, kCFPreferencesCurrentApplication,
                                   kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        }
        let domains = [UserDefaults.argumentDomain, UserDefaults.registrationDomain]
        let savedDomains = domains.map { defaults.volatileDomain(forName: $0) }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("shortcut-parser-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            for (key, value) in zip(keys, saved) {
                if let value { defaults.set(value, forKey: key) }
                else { defaults.removeObject(forKey: key) }
            }
            for (name, values) in zip(domains, savedDomains) {
                defaults.setVolatileDomain(values, forName: name)
            }
            KeyboardShortcutSettings.settingsFileStore = originalStore
            do { try FileManager.default.removeItem(at: directory) }
            catch { Issue.record(error, "Could not remove owned parser settings") }
        }
        for (name, values) in zip(domains, savedDomains) {
            defaults.setVolatileDomain(values.filter { !keys.contains($0.key) }, forName: name)
        }
        keys.forEach { defaults.removeObject(forKey: $0) }
        try body(directory)
    }

    // All notifications above are delivered on the main queue; no shared-state suspension occurs.
    @MainActor
    private final class NotificationCounts {
        var standard = 0
        var parsing = 0
        var runtime = 0
    }
}
