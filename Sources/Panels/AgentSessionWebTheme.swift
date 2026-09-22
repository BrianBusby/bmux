import AppKit
import BmuxFoundation

struct AgentSessionWebTheme: Equatable {
    let isDark: Bool
    let pageBackground: String
    let surfaceBackground: String
    let surfaceElevatedBackground: String
    let inputBackground: String
    let border: String
    let borderStrong: String
    let text: String
    let mutedText: String
    let softText: String
    let accent: String
    let accentSoft: String
    let danger: String
    let shadow: String

    var dictionary: [String: Any] {
        [
            "isDark": isDark,
            "pageBackground": pageBackground,
            "surfaceBackground": surfaceBackground,
            "surfaceElevatedBackground": surfaceElevatedBackground,
            "inputBackground": inputBackground,
            "border": border,
            "borderStrong": borderStrong,
            "text": text,
            "mutedText": mutedText,
            "softText": softText,
            "accent": accent,
            "accentSoft": accentSoft,
            "danger": danger,
            "shadow": shadow
        ]
    }

    static func resolve(appearance: PanelAppearance) -> AgentSessionWebTheme {
        let base = appearance.backgroundColor.markdownOpaqueSRGB
        let isDark = !base.isLightColor
        let overlay: NSColor = isDark ? .white : .black
        let inverseOverlay: NSColor = isDark ? .black : .white
        let contentBackground = appearance.contentBackgroundColor
        let transparentContent = contentBackground.alphaComponent < 0.001
        let baseSurfaceAlpha: CGFloat = appearance.drawsContentBackground ? 0.72 : 0.34
        let elevatedSurfaceAlpha: CGFloat = appearance.drawsContentBackground ? 0.84 : 0.48
        let inputAlpha: CGFloat = appearance.drawsContentBackground ? 0.60 : 0.36
        let border = base.markdownThemeOverlay(
            targetContrast: isDark ? 1.62 : 1.34,
            of: overlay
        )
        let borderStrong = base.markdownThemeOverlay(
            targetContrast: isDark ? 2.12 : 1.64,
            of: overlay
        )
        let surface = base
            .blended(withFraction: isDark ? 0.05 : 0.03, of: overlay)?
            .withAlphaComponent(baseSurfaceAlpha)
            ?? base.withAlphaComponent(baseSurfaceAlpha)
        let surfaceElevated = base
            .blended(withFraction: isDark ? 0.08 : 0.05, of: overlay)?
            .withAlphaComponent(elevatedSurfaceAlpha)
            ?? base.withAlphaComponent(elevatedSurfaceAlpha)
        let input = base
            .blended(withFraction: isDark ? 0.18 : 0.10, of: inverseOverlay)?
            .withAlphaComponent(inputAlpha)
            ?? base.withAlphaComponent(inputAlpha)
        let foreground = appearance.foregroundColor
        let accent = bmuxAccentNSColor()
        let danger = (NSColor(hex: isDark ? "#FF8D7E" : "#B3261E") ?? .systemRed)
        return AgentSessionWebTheme(
            isDark: isDark,
            pageBackground: transparentContent ? "transparent" : contentBackground.markdownCSSColor,
            surfaceBackground: surface.markdownCSSColor,
            surfaceElevatedBackground: surfaceElevated.markdownCSSColor,
            inputBackground: input.markdownCSSColor,
            border: border.withAlphaComponent(border.alphaComponent * 0.72).markdownCSSColor,
            borderStrong: borderStrong.markdownCSSColor,
            text: foreground.markdownCSSColor,
            mutedText: foreground.withAlphaComponent(0.58).markdownCSSColor,
            softText: foreground.withAlphaComponent(0.78).markdownCSSColor,
            accent: accent.markdownCSSColor,
            accentSoft: accent.withAlphaComponent(isDark ? 0.20 : 0.16).markdownCSSColor,
            danger: danger.markdownCSSColor,
            shadow: isDark ? "rgba(0, 0, 0, 0.20)" : "rgba(0, 0, 0, 0.10)"
        )
    }

#if DEBUG
    /// Acceptance-only dark payload used to exercise the real bridge/theme
    /// path. The web surface receives explicit tokens, so a native view
    /// appearance alone cannot override a light payload from terminal config.
    var acceptanceDarkened: AgentSessionWebTheme {
        AgentSessionWebTheme(
            isDark: true,
            // A transparent page inherits the native light panel. The
            // acceptance override must provide its own dark backing so the
            // explicit dark text/tokens remain legible in an otherwise-light
            // disposable window.
            pageBackground: "#11130f",
            surfaceBackground: "rgba(28, 31, 27, 0.34)",
            surfaceElevatedBackground: "rgba(28, 31, 27, 0.48)",
            inputBackground: "rgba(8, 10, 8, 0.36)",
            border: "rgba(233, 231, 216, 0.12)",
            borderStrong: "rgba(233, 231, 216, 0.22)",
            text: "#f1f0e8",
            mutedText: "rgba(241, 240, 232, 0.58)",
            softText: "rgba(241, 240, 232, 0.78)",
            accent: accent,
            accentSoft: "rgba(138, 180, 248, 0.2)",
            danger: "#ff8d7e",
            shadow: "rgba(0, 0, 0, 0.2)"
        )
    }
#endif

    static func figmaShell() -> AgentSessionWebTheme {
        AgentSessionWebTheme(
            isDark: true,
            pageBackground: "#1B1C20",
            surfaceBackground: "rgba(37, 38, 43, 0.92)",
            surfaceElevatedBackground: "rgba(48, 49, 56, 0.96)",
            inputBackground: "rgba(20, 21, 24, 0.92)",
            border: "rgba(255, 255, 255, 0.10)",
            borderStrong: "rgba(255, 255, 255, 0.18)",
            text: "#F4F2F8",
            mutedText: "rgba(244, 242, 248, 0.62)",
            softText: "rgba(244, 242, 248, 0.80)",
            accent: "#B9A3FF",
            accentSoft: "rgba(185, 163, 255, 0.20)",
            danger: "#FF8D7E",
            shadow: "rgba(0, 0, 0, 0.20)"
        )
    }
}
