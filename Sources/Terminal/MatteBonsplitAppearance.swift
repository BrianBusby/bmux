import AppKit
import SwiftUI
import Bonsplit
import BmuxAppKitSupportUI

/// Maps shared theme values onto Bonsplit's optional presentation seam.
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
        let motion = theme.motion(reduceMotion: false)
        let nextPresentation = TabChromePresentation(
            selectedBackground: color(.inset), hoverBackground: color(.hoverWash),
            primaryText: color(.textPrimary), secondaryText: color(.textSecondary),
            indicator: color(.selectionRing), edge: color(.edge), hoverWash: color(.hoverWash),
            pressWash: color(.pressWash), focus: color(.focus), hintBackground: color(.panel),
            cornerRadius: metrics.terminalRadius, controlRadius: metrics.compactControlRadius,
            minimumHitSize: metrics.minimumHitSize, indicatorWidth: metrics.hairlineWidth,
            focusWidth: metrics.focusOutlineWidth, focusOffset: metrics.focusOutlineOffset,
            disabledOpacity: metrics.disabledOpacity, duration: motion.controlDuration,
            timingCurve: UnitCurve.bezier(startControlPoint: UnitPoint(x: motion.curve.x1, y: motion.curve.y1),
                                          endControlPoint: UnitPoint(x: motion.curve.x2, y: motion.curve.y2))
        )
        let nextColors = BonsplitConfiguration.Appearance.ChromeColors(
            backgroundHex: panel, tabBarBackgroundHex: panel,
            splitButtonBackdropHex: panel, paneBackgroundHex: panel,
            borderHex: PaneChromeSettings.resolvedPaneBorderHex(configuredHex: paneBorderColorHex, fallback: edge))
        let nextBackdrop = BonsplitConfiguration.Appearance.SplitButtonBackdropEffect(
            style: .opaqueBarBackground, fadeWidth: 0, contentFadeWidth: 0, masksTabContent: false)
        let nextFontSize = theme.typography(.body).pointSize
        guard appearance.tabChromePresentation != nextPresentation || appearance.chromeColors != nextColors ||
                appearance.usesSharedBackdrop || appearance.tabTitleFontSize != nextFontSize ||
                appearance.tabBarHeight != metrics.terminalTabBarHeight ||
                appearance.splitButtonBackdropEffect != nextBackdrop else { return }
        appearance.chromeColors = nextColors
        appearance.usesSharedBackdrop = false
        appearance.tabTitleFontSize = nextFontSize
        appearance.tabBarHeight = metrics.terminalTabBarHeight
        appearance.splitButtonBackdropEffect = nextBackdrop
        appearance.tabChromePresentation = nextPresentation
    }

    private func color(_ role: MatteColorRole) -> Color { Color(nsColor: theme.color(role)) }
}
