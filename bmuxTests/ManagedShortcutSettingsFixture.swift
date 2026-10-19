import AppKit
import CoreFoundation
import Testing
#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

/// Owns file-managed New Tab settings and restores only the affected defaults and provenance.
@MainActor
struct ManagedShortcutSettingsFixture {
    func withStores<T>(_ body: (KeyboardShortcutSettingsFileStore, KeyboardShortcutSettingsFileStore) throws -> T) throws -> T {
        let defaults = UserDefaults.standard
        let originalStore = KeyboardShortcutSettings.settingsFileStore
        let keys = [
            "bmux.settingsFile.backups.v1", "bmux.settingsFile.importedManagedDefaults.v1",
            SidebarMatchTerminalBackgroundSettings.legacyAppliedSettingsFileDefaultKey,
            KeyboardShortcutSettings.Action.newTab.defaultsKey,
        ]
        let saved = keys.map {
            CFPreferencesCopyValue($0 as CFString, kCFPreferencesCurrentApplication,
                                   kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        }
        let domains = [UserDefaults.argumentDomain, UserDefaults.registrationDomain]
        let savedDomains = domains.map { defaults.volatileDomain(forName: $0) }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("managed-shortcuts-\(UUID())")
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
            catch { Issue.record(error, "Could not remove owned managed shortcut settings") }
        }
        for (name, values) in zip(domains, savedDomains) {
            defaults.setVolatileDomain(values.filter { !keys.contains($0.key) }, forName: name)
        }
        keys.forEach { defaults.removeObject(forKey: $0) }
        let emptyFile = directory.appendingPathComponent("empty.json")
        let managedFile = directory.appendingPathComponent("managed.json")
        try Data(#"{"shortcuts":{}}"#.utf8).write(to: emptyFile)
        try Data(#"{"shortcuts":{"newTab":["ctrl+b","c"]}}"#.utf8).write(to: managedFile)
        let emptyStore = makeStore(at: emptyFile)
        let managedStore = makeStore(at: managedFile)
        KeyboardShortcutSettings.settingsFileStore = emptyStore
        return try body(emptyStore, managedStore)
    }

    private func makeStore(at file: URL) -> KeyboardShortcutSettingsFileStore {
        KeyboardShortcutSettingsFileStore(
            primaryPath: file.path, fallbackPath: nil, additionalFallbackPaths: [],
            notificationCenter: NotificationCenter(), startWatching: false
        )
    }
}
