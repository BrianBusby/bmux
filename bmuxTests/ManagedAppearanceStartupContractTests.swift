import AppKit
import CoreFoundation
import Foundation
import Testing
@testable import bmux_DEV

@MainActor
@Suite(.serialized)
struct ManagedAppearanceStartupContractTests {
    @Test(arguments: ["dark", "light", "system"])
    func launchDefersTerminalSynchronizationUntilChangedReload(initialMode: String) throws {
        let defaults = UserDefaults.standard
        let keys = [
            AppearanceSettings.appearanceModeKey,
            SidebarMatchTerminalBackgroundSettings.legacyAppliedSettingsFileDefaultKey,
            "bmux.settingsFile.backups.v1",
            "bmux.settingsFile.importedManagedDefaults.v1",
        ]
        // Snapshot only persisted application values, not registered/global fallbacks.
        let originalValues = keys.map {
            CFPreferencesCopyValue(
                $0 as CFString,
                kCFPreferencesCurrentApplication,
                kCFPreferencesCurrentUser,
                kCFPreferencesAnyHost
            )
        }
        keys.forEach { defaults.removeObject(forKey: $0) }
        defer {
            for (key, value) in zip(keys, originalValues) {
                if let value { defaults.set(value, forKey: key) }
                else { defaults.removeObject(forKey: key) }
            }
        }

        // Force an import in every case even if the host registers a system default.
        defaults.set(AppearanceMode.auto.rawValue, forKey: AppearanceSettings.appearanceModeKey)

        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("bmux.json")
        try write(mode: initialMode, to: file)

        var applicationAppearances: [NSAppearance.Name?] = []
        var terminalAppearances: [NSAppearance.Name?] = []
        var terminalSources: [String] = []
        let environment = AppearanceSettings.LiveApplyEnvironment(
            setApplicationAppearance: {
                applicationAppearances.append($0?.bestMatch(from: [.aqua, .darkAqua]))
            },
            synchronizeTerminalThemeWithAppearance: { appearance, source in
                terminalAppearances.append(appearance?.bestMatch(from: [.aqua, .darkAqua]))
                terminalSources.append(source)
            },
            systemAppearance: { NSAppearance(named: .aqua) }
        )
        let store = KeyboardShortcutSettingsFileStore(
            primaryPath: file.path,
            fallbackPath: nil,
            additionalFallbackPaths: [],
            notificationCenter: NotificationCenter(),
            appearanceEnvironment: environment,
            startWatching: false
        )
        let initialAppearance: NSAppearance.Name = initialMode == "dark" ? .darkAqua : .aqua
        #expect(defaults.string(forKey: AppearanceSettings.appearanceModeKey) == initialMode)
        #expect(applicationAppearances == [initialAppearance])
        #expect(terminalAppearances.isEmpty)
        #expect(terminalSources.isEmpty)

        store.applyDeferredManagedDefaultSideEffects()
        store.reload()
        #expect(applicationAppearances == [initialAppearance])
        #expect(terminalAppearances.isEmpty)
        #expect(terminalSources.isEmpty)

        let nextMode = initialMode == "light" ? "system" : "light"
        let nextAppearance: NSAppearance.Name? = nextMode == "system" ? nil : .aqua
        try write(mode: nextMode, to: file)
        store.reload()
        #expect(defaults.string(forKey: AppearanceSettings.appearanceModeKey) == nextMode)
        #expect(applicationAppearances == [initialAppearance, nextAppearance])
        #expect(terminalAppearances == [nextAppearance])
        #expect(terminalSources == ["bmuxConfig.applyManagedDefault"])

        store.applyDeferredManagedDefaultSideEffects()
        store.reload()
        #expect(applicationAppearances == [initialAppearance, nextAppearance])
        #expect(terminalAppearances == [nextAppearance])
        #expect(terminalSources == ["bmuxConfig.applyManagedDefault"])
    }

    private func write(mode: String, to file: URL) throws {
        let data = try JSONSerialization.data(withJSONObject: ["app": ["appearance": mode]])
        try data.write(to: file, options: .atomic)
    }
}
