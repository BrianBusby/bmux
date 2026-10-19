import AppKit
import SwiftUI
import BmuxAppKitSupportUI
import BmuxTerminal
import BmuxFoundation

/// Shared appearance settings for panels
struct PanelAppearance {
    let backgroundColor: NSColor
    let foregroundColor: NSColor
    let dividerColor: Color
    let unfocusedOverlayNSColor: NSColor
    let unfocusedOverlayOpacity: Double
    let usesClearContentBackground: Bool

    var contentBackgroundColor: NSColor {
        usesClearContentBackground ? .clear : backgroundColor
    }

    var drawsContentBackground: Bool {
        !usesClearContentBackground
    }

    static func fromConfig(_ config: GhosttyConfig) -> PanelAppearance {
        fromConfig(
            config,
            usesTransparentWindow: WindowBackgroundComposition.policy
                .shouldUseTransparentBackgroundWindow(glassEffectAvailable: false)
        )
    }

    static func fromConfig(_ config: GhosttyConfig, usesTransparentWindow: Bool) -> PanelAppearance {
        let backgroundColor = GhosttyBackgroundTheme.color(
            backgroundColor: config.backgroundColor,
            opacity: config.backgroundOpacity
        )
        return PanelAppearance(
            backgroundColor: backgroundColor,
            foregroundColor: bmuxReadableForegroundNSColor(
                preferred: config.foregroundColor,
                on: backgroundColor
            ),
            dividerColor: Color(nsColor: config.resolvedSplitDividerColor),
            unfocusedOverlayNSColor: config.unfocusedSplitOverlayFill,
            unfocusedOverlayOpacity: config.unfocusedSplitOverlayOpacity,
            usesClearContentBackground: shouldUseClearContentBackground(
                opacity: config.backgroundOpacity,
                usesGhosttyGlassStyle: config.backgroundBlur.isMacOSGlassStyle,
                usesTransparentWindow: usesTransparentWindow
            )
        )
    }

    static func shouldUseClearContentBackground(
        opacity: Double,
        usesGhosttyGlassStyle: Bool,
        usesTransparentWindow: Bool
    ) -> Bool {
        usesTransparentWindow || usesGhosttyGlassStyle || opacity < 0.999
    }
}
