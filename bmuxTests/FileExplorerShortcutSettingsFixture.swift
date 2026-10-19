import AppKit
import CoreFoundation
import Testing
#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

/// Scopes file-explorer shortcut setters to an owned empty file and restores persisted provenance.
@MainActor
struct FileExplorerShortcutSettingsFixture {
    func withEmptySettings<T>(_ body: () throws -> T) throws -> T {
        let defaults = UserDefaults.standard
        let originalStore = KeyboardShortcutSettings.settingsFileStore
        let keys = [
            "bmux.settingsFile.backups.v1", "bmux.settingsFile.importedManagedDefaults.v1",
            SidebarMatchTerminalBackgroundSettings.legacyAppliedSettingsFileDefaultKey,
            KeyboardShortcutSettings.Action.fileExplorerOpenSelection.defaultsKey,
            KeyboardShortcutSettings.Action.fileExplorerOpenSelectionFinderAlias.defaultsKey,
            KeyboardShortcutSettings.Action.renameTab.defaultsKey,
        ]
        let saved = keys.map {
            CFPreferencesCopyValue($0 as CFString, kCFPreferencesCurrentApplication,
                                   kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        }
        let domains = [UserDefaults.argumentDomain, UserDefaults.registrationDomain]
        let savedDomains = domains.map { defaults.volatileDomain(forName: $0) }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("file-explorer-shortcuts-\(UUID())")
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
            catch { Issue.record(error, "Could not remove owned file-explorer shortcut settings") }
        }
        for (name, values) in zip(domains, savedDomains) {
            defaults.setVolatileDomain(values.filter { !keys.contains($0.key) }, forName: name)
        }
        keys.forEach { defaults.removeObject(forKey: $0) }
        let file = directory.appendingPathComponent("bmux.json")
        try JSONSerialization.data(withJSONObject: ["shortcuts": ["bindings": [String: Any]()]])
            .write(to: file)
        KeyboardShortcutSettings.settingsFileStore = KeyboardShortcutSettingsFileStore(
            primaryPath: file.path, fallbackPath: nil, additionalFallbackPaths: [],
            notificationCenter: NotificationCenter(), startWatching: false
        )
        return try body()
    }
}
