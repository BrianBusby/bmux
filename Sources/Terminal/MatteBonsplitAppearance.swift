import AppKit
import Bonsplit
import BmuxAppKitSupportUI

/// Applies matte colors through Bonsplit's existing appearance configuration.
struct MatteBonsplitAppearance {
    let theme: MatteTheme
    let paneBorderColorHex: String?

    init(
        theme: MatteTheme = MatteTheme(colorScheme: GhosttyConfig.currentColorSchemePreference() == .dark ? .dark : .light),
        paneBorderColorHex: String? = PaneChromeSettings.paneBorderColorHex()
    ) {
        self.theme = theme
        self.paneBorderColorHex = paneBorderColorHex
    }

    func apply(to appearance: inout BonsplitConfiguration.Appearance) {
        let panel = theme.color(.panel).hexString()
        let edge = theme.color(.edge).hexString(includeAlpha: true)
        let metrics = theme.layout
        let nextColors = BonsplitConfiguration.Appearance.ChromeColors(
            backgroundHex: panel, tabBarBackgroundHex: panel,
            splitButtonBackdropHex: panel, paneBackgroundHex: NSColor.clear.hexString(includeAlpha: true),
            borderHex: PaneChromeSettings.resolvedPaneBorderHex(configuredHex: paneBorderColorHex, fallback: edge))
        let nextBackdrop = BonsplitConfiguration.Appearance.SplitButtonBackdropEffect(
            style: .opaqueBarBackground, fadeWidth: 0, contentFadeWidth: 0, masksTabContent: false)
        let current = appearance.chromeColors
        let backdrop = appearance.splitButtonBackdropEffect
        guard current.backgroundHex != nextColors.backgroundHex ||
                current.tabBarBackgroundHex != nextColors.tabBarBackgroundHex ||
                current.splitButtonBackdropHex != nextColors.splitButtonBackdropHex ||
                current.paneBackgroundHex != nextColors.paneBackgroundHex ||
                current.borderHex != nextColors.borderHex ||
                appearance.usesSharedBackdrop ||
                appearance.tabBarHeight != metrics.terminalTabBarHeight ||
                backdrop?.style != nextBackdrop.style || backdrop?.fadeWidth != nextBackdrop.fadeWidth ||
                backdrop?.contentFadeWidth != nextBackdrop.contentFadeWidth ||
                backdrop?.masksTabContent != nextBackdrop.masksTabContent ||
                backdrop?.solidWidth != nextBackdrop.solidWidth ||
                backdrop?.solidSurfaceWidthAdjustment != nextBackdrop.solidSurfaceWidthAdjustment ||
                backdrop?.separatorFadeWidth != nextBackdrop.separatorFadeWidth ||
                backdrop?.fadeRampStartFraction != nextBackdrop.fadeRampStartFraction ||
                backdrop?.leadingOpacity != nextBackdrop.leadingOpacity ||
                backdrop?.trailingOpacity != nextBackdrop.trailingOpacity ||
                backdrop?.contentOcclusionFraction != nextBackdrop.contentOcclusionFraction else { return }
        appearance.chromeColors = nextColors
        appearance.usesSharedBackdrop = false
        appearance.tabBarHeight = metrics.terminalTabBarHeight
        appearance.splitButtonBackdropEffect = nextBackdrop
    }
}
