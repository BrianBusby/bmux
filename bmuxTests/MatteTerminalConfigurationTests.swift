import AppKit
import BmuxAppKitSupportUI
import BmuxTerminal
import BmuxTerminalCore
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

/// Exercises the renderer's native config loader without changing the user's files or environment.
@MainActor
@Suite(.serialized) struct MatteTerminalConfigurationTests {
    @Test(arguments: [false, true])
    func freshInstallUsesMatteDefaults(isDark: Bool) throws {
        let scheme: GhosttyConfig.ColorSchemePreference = isDark ? .dark : .light
        try withLoadedPreview(.freshInstall, scheme: scheme) { config in
            let theme = MatteTheme(colorScheme: isDark ? .dark : .light)
            #expect(color("background", in: config) == theme.color(.inset).hexString().lowercased())
            #expect(color("foreground", in: config) == theme.color(.terminalText).hexString().lowercased())
        }
    }

    @Test(arguments: [
        GhosttyStartupAppearancePreviewProfile.userExplicitColors,
        .userSingleTheme,
        .userThemePair,
    ], [false, true])
    func explicitPreviewAppearanceSurvivesTheCompleteLoader(
        profile: GhosttyStartupAppearancePreviewProfile, isDark: Bool
    ) throws {
        let scheme: GhosttyConfig.ColorSchemePreference = isDark ? .dark : .light
        let contents = try #require(profile.previewConfigContents(preferredColorScheme: scheme))
        try withNativeConfig { expected in
            try load(contents, into: expected)
            // The existing renderer loader reconciles foreground before Ghostty finalizes
            // theme files. Preserve that policy while checking that matte defaults do not
            // overwrite the user's appearance afterward.
            let background = try #require(NSColor(hex: color("background", in: expected)))
            let foreground = try #require(NSColor(hex: color("foreground", in: expected)))
            var opacity = 1.0
            #expect(ghostty_config_get(expected, &opacity, "background-opacity", 18))
            let readableForeground = bmuxReadableForegroundNSColor(
                preferred: foreground,
                on: GhosttyBackgroundTheme.color(backgroundColor: background, opacity: opacity)
            )
            try load("foreground = \(readableForeground.hexString())", into: expected)
            ghostty_config_finalize(expected)
            try withLoadedPreview(profile, scheme: scheme) { actual in
                #expect(color("background", in: actual) == color("background", in: expected))
                #expect(color("foreground", in: actual) == color("foreground", in: expected))
            }
        }
    }

    @Test(arguments: [false, true])
    func reassertingDefaultColorsPreservesExplicitOpacity(isDark: Bool) throws {
        try withNativeConfig { config in
            try load("background-opacity = 0.88", into: config)
            try load(MatteTerminalConfiguration(colorScheme: isDark ? .dark : .light).contents, into: config)
            ghostty_config_finalize(config)
            var opacity = 0.0
            #expect(ghostty_config_get(config, &opacity, "background-opacity", 18))
            #expect(abs(opacity - 0.88) < 0.0001)
        }
    }

    @Test(arguments: ["foreground", "background"])
    func explicitColorOverridesOnlyThatDefault(key: String) throws {
        try withNativeConfig { config in
            try load(MatteTerminalConfiguration(colorScheme: .dark).contents, into: config)
            try load("\(key) = #a1b2c3", into: config)
            ghostty_config_finalize(config)
            #expect(color(key, in: config) == "#a1b2c3")
            let unchanged = key == "foreground" ? "background" : "foreground"
            let theme = MatteTheme(colorScheme: .dark)
            let expected = theme.color(key == "foreground" ? .inset : .terminalText).hexString().lowercased()
            #expect(color(unchanged, in: config) == expected)
        }
    }

    private func withLoadedPreview(
        _ profile: GhosttyStartupAppearancePreviewProfile,
        scheme: GhosttyConfig.ColorSchemePreference,
        body: (ghostty_config_t) throws -> Void
    ) throws {
        // This existing preview override is process-wide. Stay synchronous on the main actor,
        // and restore both values without publishing a config reload or touching live surfaces.
        let app = GhosttyApp.shared
        try #require(app.usesHostLayerBackground)
        let previousShellIntegration = app.userGhosttyShellIntegrationMode
        let previousProfile = GhosttyStartupAppearancePreviewState.profile
        let previousOverride = TerminalStartupAppearancePreviewOverride.installed
        defer {
            GhosttyStartupAppearancePreviewState.profile = previousProfile
            TerminalStartupAppearancePreviewOverride.installed = previousOverride
        }
        GhosttyStartupAppearancePreviewState.profile = profile
        try withNativeConfig { config in
            try load("shell-integration = \(previousShellIntegration)", into: config)
            _ = app.loadDefaultConfigFilesWithLegacyFallback(config, preferredColorScheme: scheme)
            #expect(app.userGhosttyShellIntegrationMode == previousShellIntegration)
            #expect(app.usesHostLayerBackground)
            try body(config)
        }
    }

    private func withNativeConfig(body: (ghostty_config_t) throws -> Void) throws {
        _ = GhosttyApp.shared
        let config = try #require(ghostty_config_new())
        defer { ghostty_config_free(config) }
        try body(config)
    }

    private func load(_ contents: String, into config: ghostty_config_t) throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("matte-terminal-\(UUID()).conf")
        try contents.write(to: file, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: file) }
        file.path.withCString { ghostty_config_load_file(config, $0) }
    }

    private func color(_ key: String, in config: ghostty_config_t) -> String {
        var value = ghostty_config_color_s()
        #expect(ghostty_config_get(config, &value, key, UInt(key.utf8.count)))
        return String(format: "#%02x%02x%02x", value.r, value.g, value.b)
    }
}
