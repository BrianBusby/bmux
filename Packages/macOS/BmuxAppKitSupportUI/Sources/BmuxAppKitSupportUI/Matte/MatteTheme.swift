public import AppKit
public import SwiftUI

/// Immutable graphite or porcelain tokens resolved from an explicit native appearance.
///
/// This is the only source of matte design values. Pass SwiftUI's effective color
/// scheme, or AppKit's effective appearance, after existing app overrides resolve.
/// It never changes appearance settings or terminal rendering preferences.
///
/// ```swift
/// let theme = MatteTheme(colorScheme: .dark)
/// let background = Color(nsColor: theme.color(.panel))
/// let motion = theme.motion(reduceMotion: true)
/// ```
public struct MatteTheme: Sendable {
    /// Effective scheme supplied by the caller; dark resolves graphite, light porcelain.
    public let colorScheme: ColorScheme

    /// Creates tokens from an already-resolved SwiftUI color scheme.
    /// - Parameter colorScheme: Effective scheme, including the existing app override.
    public init(colorScheme: ColorScheme) {
        self.colorScheme = colorScheme
    }

    /// Creates tokens from an AppKit view or window's effective appearance.
    /// - Parameter appearance: Effective appearance, including any app override.
    public init(appearance: NSAppearance) {
        self.init(colorScheme: appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? .dark : .light)
    }

    /// Returns an opaque sRGB color except for the explicitly translucent wash and edge roles.
    /// - Parameter role: Semantic use of the color.
    /// - Returns: The resolved color for this theme.
    public func color(_ role: MatteColorRole) -> NSColor {
        switch role {
        case .base: pair(0x1c1b19, 0xdedbd3)
        case .panel: pair(0x282724, 0xf8f6f1)
        case .card: pair(0x2a2926, 0xfaf9f5)
        case .cardHover: pair(0x302f2b, 0xfffefb)
        case .cardSelected: pair(0x292e35, 0xeaeff5)
        case .cardSelectedHover: pair(0x2d333b, 0xe4eaf2)
        case .inset: pair(0x191816, 0xebe9e2)
        case .field: pair(0x222120, 0xeeece6)
        case .button: pair(0x2f2e2b, 0xf6f4ef)
        case .buttonHover: pair(0x363531, 0xfffefb)
        case .chip: pair(0x34332f, 0xe5e2da)
        case .textPrimary: pair(0xece8e1, 0x1f1e1c)
        case .textSecondary: pair(0xb6b1a8, 0x4e4b45)
        case .textTertiary: pair(0x9a958c, 0x66625b)
        case .terminalText: pair(0xd8d4cc, 0x2a2925)
        case .edge: pair(0xffffff, 0x463a26, darkAlpha: 0.08, lightAlpha: 0.12)
        case .hoverWash: pair(0xffffff, 0x3c301c, darkAlpha: 0.07, lightAlpha: 0.07)
        case .pressWash: pair(0xffffff, 0x3c301c, darkAlpha: 0.12, lightAlpha: 0.12)
        case .selectionRing: pair(0x6f8fb8, 0x4c6c94)
        case .focus: pair(0xa9c4e6, 0x2f5686)
        case .link: pair(0x93b2d8, 0x2b5385)
        case .linkHover: pair(0xb9d0ec, 0x1b3d66)
        case .sage: pair(0xa3bd9f, 0x4a6847)
        case .success: pair(0x8cc596, 0x2f6a40)
        case .warning: pair(0xdcb067, 0x7a5208)
        case .danger: pair(0xe69a8e, 0xa23a2d)
        case .information: pair(0x9db8da, 0x34567f)
        }
    }

    /// Creates a color that follows AppKit's effective drawing appearance.
    ///
    /// Reuse the returned color across appearance changes. For SwiftUI, construct
    /// a theme from the effective environment scheme and use ``color(_:)``.
    /// - Parameter role: Semantic use of the color.
    /// - Returns: A dynamic color resolving both system appearance and window overrides.
    public static func dynamicColor(_ role: MatteColorRole) -> NSColor {
        NSColor(name: nil) { appearance in
            MatteTheme(appearance: appearance).color(role)
        }
    }

    /// Shared radii, spacing, and hit-target sizes, in points.
    public var layout: MatteLayoutMetrics {
        MatteLayoutMetrics(
            cardRadius: 12, panelRadius: 14, terminalRadius: 8,
            controlRadius: 10, compactControlRadius: 8,
            controlHeight: 36, compactControlHeight: 28,
            windowGutter: 14,
            sidebarMinimumWidth: 260, sidebarPreferredFraction: 0.27, sidebarMaximumWidth: 320,
            cardPadding: EdgeInsets(top: 13, leading: 16, bottom: 14, trailing: 16),
            cardContentGap: 7, cardGap: 12,
            panelPadding: EdgeInsets(top: 20, leading: 24, bottom: 24, trailing: 24),
            iconSize: 16, smallIconSize: 14, iconStroke: 1.7,
            minimumHitSize: 28, raisedHitSize: 36, invisibleHitExpansion: 4,
            focusOutlineWidth: 2, focusOutlineOffset: 2, linkUnderlineWidth: 2, selectedMarkerSize: 4, disabledOpacity: 0.5
        )
    }

    /// Returns font metrics without changing user-configured terminal typography.
    /// - Parameter role: Semantic text role.
    /// - Returns: Reference metrics; numeric weights are retained for native font mapping.
    public func typography(_ role: MatteTypographyRole) -> MatteTypographyMetrics {
        switch role {
        case .wordmark: font(22, weight: 750, tracking: -0.025)
        case .workspaceHeading: font(26, weight: 650, tracking: -0.015)
        case .cardTitle: font(15, weight: 600, lineHeight: 1.32)
        case .repositoryLabel: font(11.5, weight: 600)
        case .sectionLabel: font(11, weight: 600, tracking: 0.07, uppercase: true)
        case .tab: font(14, weight: 500)
        case .body: font(13, weight: 400)
        case .previewLine: font(12.5, weight: 400)
        case .terminal: font(13, weight: 400, lineHeight: 1.65, monospace: true)
        }
    }

    /// Returns transition tokens honoring the caller's accessibility preference.
    /// - Parameter reduceMotion: Whether the system or app requests no animation.
    /// - Returns: Zero-duration, zero-lift tokens when Reduce Motion is enabled.
    public func motion(reduceMotion: Bool) -> MatteMotionTokens {
        MatteMotionTokens(
            controlDuration: reduceMotion ? 0 : 0.12,
            cardDuration: reduceMotion ? 0 : 0.18,
            curve: MatteTimingCurve(x1: 0.2, y1: 0.7, x2: 0.2, y2: 1),
            hoverLift: reduceMotion ? 0 : 1,
            stationaryLift: 0
        )
    }

    /// Returns the upward lift eligible for the current workspace-card interaction.
    /// - Parameters:
    ///   - isHovered: Whether the pointer is inside the card.
    ///   - isSelected: Whether this is the selected card, which always stays still.
    ///   - isPressed: Whether the card is pressed, which removes hover lift.
    ///   - isEnabled: Whether the card can respond to interaction.
    ///   - reduceMotion: Whether all movement must be suppressed.
    /// - Returns: Upward lift in points; callers translate this into their coordinate system.
    public func cardLift(
        isHovered: Bool, isSelected: Bool, isPressed: Bool, isEnabled: Bool, reduceMotion: Bool
    ) -> Double {
        let values = motion(reduceMotion: reduceMotion)
        return isEnabled && isHovered && !isSelected && !isPressed ? values.hoverLift : values.stationaryLift
    }

    /// Stationary texture parameters; no texture is applied by the token layer.
    public var texture: MatteTextureTokens {
        MatteTextureTokens(
            tileSize: 128, assetScales: [1, 2], bitDepth: 8,
            baseOpacity: isDark ? 0.07 : 0.06, panelOpacity: 0.035,
            cardOpacity: isDark ? 0.03 : 0.028, isWhiteNoise: isDark,
            baseFrequency: 0.9, octaveCount: 2, seed: 7, alphaMultiplier: 4, alphaOffset: -1.6
        )
    }

    /// Opacity of the success-status background wash.
    public var successWashOpacity: Double { isDark ? 0.14 : 0.10 }

    /// Opacity of the success-status border.
    public var successBorderOpacity: Double { isDark ? 0.35 : 0.30 }

    /// Returns shadow layers in front-to-back reference box-shadow order.
    /// - Parameter role: Reusable elevation ingredient or inset treatment.
    /// - Returns: Resolved layers retaining blur, spread, and inset for native surface styles.
    public func shadows(_ role: MatteShadowRole) -> [MatteShadow] {
        switch role {
        case .hairline:
            [shadow(pair(0xffffff, 0x463a26, darkAlpha: 0.055, lightAlpha: 0.13), spread: 1)]
        case .lit:
            [shadow(pair(0xffffff, 0xffffff, darkAlpha: 0.075, lightAlpha: 0.95), x: 1, y: 1, inset: true),
             shadow(pair(0x000000, 0x463a26, darkAlpha: 0.32, lightAlpha: 0.07), x: -1, y: -1, inset: true)]
        case .selectedLit:
            shadows(.lit) + [shadow(pair(0x8fabce, 0x4c6c94, darkAlpha: 0.22, lightAlpha: 0.20), spread: 1, inset: true)]
        case .ring:
            [shadow(color(.selectionRing), spread: 1)]
        case .contactZero:
            [shadow(shade(0.4, 0.12), y: 1, blur: 1)]
        case .contactOne:
            [shadow(shade(0.5, 0.14), x: 1, y: 1, blur: 2)]
        case .contactTwo:
            [shadow(shade(0.55, 0.16), x: 1, y: 2, blur: 3)]
        case .contactThree:
            [shadow(shade(0.55, 0.16), x: 1, y: 3, blur: 6)]
        case .ambientOne:
            [shadow(shade(0.6, 0.28), x: 5, y: 12, blur: isDark ? 24 : 22, spread: -10)]
        case .ambientTwo:
            [shadow(shade(0.7, 0.34), x: 8, y: 18, blur: isDark ? 32 : 30, spread: -10)]
        case .ambientThree:
            [shadow(shade(0.75, 0.38), x: 12, y: 28, blur: isDark ? 48 : 46, spread: -12)]
        case .pressed:
            [shadow(shade(0.45, 0.22), x: 1, y: 2, blur: 3, inset: true),
             shadow(pair(0xffffff, 0x463a26, darkAlpha: 0.05, lightAlpha: 0.12), spread: 1)]
        case .terminalInset:
            [shadow(shade(0.5, 0.16), y: 2, blur: 4, inset: true),
             shadow(pair(0xffffff, 0x463a26, darkAlpha: 0.04, lightAlpha: 0.10), spread: 1, inset: true),
             shadow(pair(0xffffff, 0xffffff, darkAlpha: 0.03, lightAlpha: 0.7), x: -1, y: -1, inset: true)]
        case .fieldInset:
            [shadow(shade(0.4, 0.14), y: 1, blur: 2, inset: true),
             shadow(pair(0xffffff, 0x463a26, darkAlpha: 0.06, lightAlpha: 0.14), spread: 1, inset: true)]
        case .window:
            [shadow(shade(0.6, 0.45), y: 30, blur: 60, spread: isDark ? -20 : -22),
             shadow(pair(0xffffff, 0x463a26, darkAlpha: 0.06, lightAlpha: 0.12), spread: 1)]
        }
    }

    private var isDark: Bool { colorScheme == .dark }

    private func pair(_ dark: UInt32, _ light: UInt32, darkAlpha: Double = 1, lightAlpha: Double = 1) -> NSColor {
        let rgb = isDark ? dark : light
        return NSColor(
            srgbRed: Double((rgb >> 16) & 0xff) / 255,
            green: Double((rgb >> 8) & 0xff) / 255,
            blue: Double(rgb & 0xff) / 255,
            alpha: isDark ? darkAlpha : lightAlpha
        )
    }

    private func shade(_ darkAlpha: Double, _ lightAlpha: Double) -> NSColor {
        pair(0x000000, 0x3c301c, darkAlpha: darkAlpha, lightAlpha: lightAlpha)
    }

    private func shadow(
        _ color: NSColor, x: Double = 0, y: Double = 0, blur: Double = 0,
        spread: Double = 0, inset: Bool = false
    ) -> MatteShadow {
        MatteShadow(color: color, offsetX: x, offsetY: y, blur: blur, spread: spread, isInset: inset)
    }

    private func font(
        _ size: Double, weight: Double, tracking: Double = 0, lineHeight: Double? = nil,
        monospace: Bool = false, uppercase: Bool = false
    ) -> MatteTypographyMetrics {
        MatteTypographyMetrics(
            pointSize: size, weight: weight, trackingEm: tracking,
            lineHeightMultiple: lineHeight, usesMonospacedFont: monospace, usesUppercase: uppercase
        )
    }
}
