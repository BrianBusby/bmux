import AppKit
import CoreFoundation
import Testing
#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

/// Installs owned Find bindings without importing or changing the user's settings file.
@MainActor
struct BrowserFindShortcutSettingsFixture {
    func withCommandF<T>(_ body: () throws -> T) throws -> T {
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
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("find-shortcuts-\(UUID())")
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
            catch { Issue.record(error, "Could not remove owned Find shortcut settings") }
        }
        for (name, values) in zip(domains, savedDomains) {
            defaults.setVolatileDomain(values.filter { !keys.contains($0.key) }, forName: name)
        }
        keys.forEach { defaults.removeObject(forKey: $0) }
        let bindings: [String: Any] = [
            KeyboardShortcutSettings.Action.find.rawValue: ["first": [
                "key": "f", "command": true, "shift": false, "option": false, "control": false,
            ]],
            KeyboardShortcutSettings.Action.findInDirectory.rawValue: NSNull(),
        ]
        let file = directory.appendingPathComponent("bmux.json")
        try JSONSerialization.data(withJSONObject: ["shortcuts": ["bindings": bindings]]).write(to: file)
        KeyboardShortcutSettings.settingsFileStore = KeyboardShortcutSettingsFileStore(
            primaryPath: file.path, fallbackPath: nil, additionalFallbackPaths: [],
            notificationCenter: NotificationCenter(), startWatching: false
        )
        return try body()
    }
}
