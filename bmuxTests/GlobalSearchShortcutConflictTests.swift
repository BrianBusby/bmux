import AppKit
import CoreFoundation
import Testing
#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@MainActor
@Suite(.serialized)
struct GlobalSearchShortcutConflictTests {
    @Test
    func configuredShowHideConflictIdentifiesTheAction() throws {
        let shortcut = StoredShortcut(key: "g", command: true, shift: false, option: true, control: true)
        try withShowHideShortcut(shortcut) {
            #expect(KeyboardShortcutSettings.shortcut(for: .globalSearch) == .unbound)
            #expect(KeyboardShortcutSettings.shortcut(for: .showHideAllWindows) == shortcut)
            #expect(KeyboardShortcutSettings.Action.globalSearch.normalizedRecordedShortcutResult(shortcut)
                == .rejected(.conflictsWithAction(.showHideAllWindows)))
            #expect(KeyboardShortcutSettings.Action.globalSearch.normalizedRecordedShortcut(shortcut) == nil)
        }
    }

    @Test(arguments: [false, true])
    func nonconflictingShortcutRemainsAvailable(showHideIsBound: Bool) throws {
        let shortcut = StoredShortcut(key: "g", command: true, shift: false, option: true, control: true)
        let other = StoredShortcut(key: "h", command: true, shift: false, option: true, control: true)
        try withShowHideShortcut(showHideIsBound ? other : .unbound) {
            #expect(KeyboardShortcutSettings.Action.globalSearch.normalizedRecordedShortcutResult(shortcut)
                == .accepted(shortcut))
            #expect(KeyboardShortcutSettings.Action.globalSearch.normalizedRecordedShortcutResult(.unbound)
                == .accepted(.unbound))
        }
    }

    @Test
    func systemReservationRemainsDistinctFromConfiguredConflict() throws {
        let shortcut = StoredShortcut(key: ".", command: true, shift: false, option: false, control: false)
        try withShowHideShortcut(.unbound) {
            #expect(KeyboardShortcutSettings.Action.globalSearch.normalizedRecordedShortcutResult(shortcut)
                == .rejected(.reservedBySystem))
        }
    }

    @Test(arguments: [false, true])
    func configuredConflictPrecedesSystemWideChordRejection(showHideIsBound: Bool) throws {
        let shortcut = StoredShortcut(key: "g", command: true, shift: false, option: true, control: true)
        let chord = StoredShortcut(first: shortcut.firstStroke, second: shortcut.firstStroke)
        try withShowHideShortcut(showHideIsBound ? shortcut : .unbound) {
            let expected: KeyboardShortcutSettings.RecordedShortcutResolution = showHideIsBound
                ? .rejected(.conflictsWithAction(.showHideAllWindows)) : .rejected(.reservedBySystem)
            #expect(KeyboardShortcutSettings.Action.globalSearch.normalizedRecordedShortcutResult(chord) == expected)
        }
    }

    // The retained legacy owner is process-wide. Never suspend while this scoped store is installed.
    private func withShowHideShortcut(_ shortcut: StoredShortcut, body: () throws -> Void) throws {
        let defaults = UserDefaults.standard
        let originalStore = KeyboardShortcutSettings.settingsFileStore
        let keys = [
            "bmux.settingsFile.backups.v1",
            "bmux.settingsFile.importedManagedDefaults.v1",
            SidebarMatchTerminalBackgroundSettings.legacyAppliedSettingsFileDefaultKey,
            SystemWideHotkeySettings.legacyShortcutKey,
        ]
        let saved = keys.map {
            CFPreferencesCopyValue($0 as CFString, kCFPreferencesCurrentApplication,
                                   kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        }
        let domains = [UserDefaults.argumentDomain, UserDefaults.registrationDomain]
        let savedDomains = domains.map { defaults.volatileDomain(forName: $0) }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer {
            for (key, value) in zip(keys, saved) {
                if let value { defaults.set(value, forKey: key) }
                else { defaults.removeObject(forKey: key) }
            }
            for (name, values) in zip(domains, savedDomains) {
                defaults.setVolatileDomain(values, forName: name)
            }
            KeyboardShortcutSettings.settingsFileStore = originalStore
            do { try FileManager.default.removeItem(at: root) }
            catch { Issue.record(error, "Could not remove owned shortcut fixture directory") }
        }
        for (name, values) in zip(domains, savedDomains) {
            defaults.setVolatileDomain(values.filter { !keys.contains($0.key) }, forName: name)
        }
        keys.forEach { defaults.removeObject(forKey: $0) }
        var bindings: [String: Any] = Dictionary(uniqueKeysWithValues:
            KeyboardShortcutSettings.Action.allCases.map { ($0.rawValue, NSNull()) }
        )
        bindings[KeyboardShortcutSettings.Action.showHideAllWindows.rawValue] = ["first": [
            "key": shortcut.key, "command": shortcut.command, "shift": shortcut.shift,
            "option": shortcut.option, "control": shortcut.control,
        ]]
        let file = root.appendingPathComponent("bmux.json")
        try JSONSerialization.data(withJSONObject: ["shortcuts": ["bindings": bindings]]).write(to: file)
        KeyboardShortcutSettings.settingsFileStore = KeyboardShortcutSettingsFileStore(
            primaryPath: file.path, fallbackPath: nil, additionalFallbackPaths: [],
            notificationCenter: NotificationCenter(), startWatching: false
        )
        try body()
    }
}
