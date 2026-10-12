import Foundation
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@MainActor
@Suite(.serialized)
struct BrowserThemeSettingsTests {
    @Test func defaultsMatchConfiguredFallbacks() throws {
        try withDefaults { defaults, _ in
            #expect(BrowserThemeSettings.mode(defaults: defaults) == BrowserThemeSettings.defaultMode)
        }
    }

    @Test func modeReadsPersistedValue() throws {
        try withDefaults { defaults, _ in
            defaults.set("dark", forKey: BrowserThemeSettings.modeKey)
            #expect(BrowserThemeSettings.mode(defaults: defaults) == .dark)
            defaults.set("light", forKey: BrowserThemeSettings.modeKey)
            #expect(BrowserThemeSettings.mode(defaults: defaults) == .light)
        }
    }

    @Test(arguments: [true, false])
    func modeMigratesLegacyForcedDarkModeFlag(enabled: Bool) throws {
        try withDefaults { defaults, name in
            defaults.set(enabled, forKey: BrowserThemeSettings.legacyForcedDarkModeEnabledKey)
            let expected = enabled ? "dark" : "system"
            #expect(BrowserThemeSettings.mode(defaults: defaults).rawValue == expected)
            #expect(defaults.persistentDomain(forName: name)?[BrowserThemeSettings.modeKey] as? String == expected)
        }
    }

    @Test func startupNormalizationKeepsImplicitDefault() throws {
        try withDefaults { defaults, name in
            BrowserPanel.normalizeBrowserDefaults(defaults: defaults)
            #expect(BrowserThemeSettings.mode(defaults: defaults) == .system)
            #expect(defaults.persistentDomain(forName: name)?[BrowserThemeSettings.modeKey] == nil)
        }
    }

    @Test(arguments: [true, false])
    func startupNormalizationMigratesLegacyPreference(enabled: Bool) throws {
        try withDefaults { defaults, name in
            defaults.set(enabled, forKey: BrowserThemeSettings.legacyForcedDarkModeEnabledKey)
            let expected = enabled ? "dark" : "system"
            BrowserPanel.normalizeBrowserDefaults(defaults: defaults)
            #expect(BrowserThemeSettings.mode(defaults: defaults).rawValue == expected)
            #expect(defaults.persistentDomain(forName: name)?[BrowserThemeSettings.modeKey] as? String == expected)
            BrowserPanel.normalizeBrowserDefaults(defaults: defaults)
            #expect(BrowserThemeSettings.mode(defaults: defaults).rawValue == expected)
        }
    }

    @Test(arguments: ["system", "light", "dark"])
    func startupNormalizationPreservesExplicitMode(mode: String) throws {
        try withDefaults { defaults, name in
            defaults.set(true, forKey: BrowserThemeSettings.legacyForcedDarkModeEnabledKey)
            defaults.set(mode, forKey: BrowserThemeSettings.modeKey)
            BrowserPanel.normalizeBrowserDefaults(defaults: defaults)
            #expect(BrowserThemeSettings.mode(defaults: defaults).rawValue == mode)
            #expect(defaults.persistentDomain(forName: name)?[BrowserThemeSettings.modeKey] as? String == mode)
        }
    }

    private func withDefaults(_ body: (UserDefaults, String) throws -> Void) throws {
        let name = "bmux.browserThemeSettingsTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        try body(defaults, name)
    }
}
