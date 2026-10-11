import AppKit
import BmuxAppKitSupportUI
import BmuxTerminalCore
import SwiftUI
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@MainActor
@Suite(.serialized) struct MatteChromePreferenceTests {
    @Test func configReloadKeepsResolvedTabSizeIncludingClampingAndMagnification() {
        let workspace = Workspace()
        defer { for panel in workspace.panels.values { panel.close() } }
        for (text, magnification) in [("12.5", 100), ("17", 150)] {
            var parsed = GhosttyConfig()
            parsed.parse("surface-tab-bar-font-size = \(text)")
            let config = GhosttyConfig.load(useCache: false, globalFontMagnificationPercent: magnification,
                                           loadFromDisk: { _ in parsed })
            workspace.applyGhosttyChrome(from: config)
            #expect(workspace.bonsplitController.configuration.appearance.tabTitleFontSize == config.surfaceTabBarFontSize)
            workspace.applyGhosttyChrome(backgroundColor: .black, backgroundOpacity: 0.8)
            #expect(workspace.bonsplitController.configuration.appearance.tabTitleFontSize == config.surfaceTabBarFontSize)
        }
    }

    @Test(arguments: [false, true])
    func paneOverrideSurvivesCreationReloadAndAppearanceChange(isDark: Bool) {
        withPaneBorderOverride("#345678") {
            let workspace = Workspace()
            defer { for panel in workspace.panels.values { panel.close() } }
            #expect(workspace.bonsplitController.configuration.appearance.chromeColors.borderHex == "#345678")
            withPaneBorderOverride("#789abc") {
                workspace.applyGhosttyChrome(from: GhosttyConfig())
                #expect(workspace.bonsplitController.configuration.appearance.chromeColors.borderHex == "#789ABC")
                MatteBonsplitAppearance(theme: MatteTheme(colorScheme: isDark ? .dark : .light))
                    .apply(to: &workspace.bonsplitController.configuration.appearance)
                #expect(workspace.bonsplitController.configuration.appearance.chromeColors.borderHex == "#789ABC")
            }
            workspace.applyGhosttyChrome(backgroundColor: .white, backgroundOpacity: 1)
            #expect(workspace.bonsplitController.configuration.appearance.chromeColors.borderHex == "#345678")
        }
    }

    @Test(arguments: [false, true])
    func clearingPaneOverrideRestoresMatteEdge(isDark: Bool) {
        withPaneBorderOverride("#345678") {
            let workspace = Workspace()
            defer { for panel in workspace.panels.values { panel.close() } }
            withPaneBorderOverride("") {
                let theme = MatteTheme(colorScheme: isDark ? .dark : .light)
                MatteBonsplitAppearance(theme: theme).apply(to: &workspace.bonsplitController.configuration.appearance)
                #expect(workspace.bonsplitController.configuration.appearance.chromeColors.borderHex
                        == theme.color(.edge).hexString(includeAlpha: true))
            }
        }
    }

    private func withPaneBorderOverride(_ value: String, body: () -> Void) {
        // Exercise the existing app settings owner without writing persistent
        // preferences. MainActor execution has no suspension and restores nesting.
        let defaults = UserDefaults.standard
        let previous = defaults.volatileDomain(forName: UserDefaults.argumentDomain)
        var overridden = previous
        overridden[PaneChromeSettings.paneBorderColorKey] = value
        defaults.setVolatileDomain(overridden, forName: UserDefaults.argumentDomain)
        defer { defaults.setVolatileDomain(previous, forName: UserDefaults.argumentDomain) }
        body()
    }
}
