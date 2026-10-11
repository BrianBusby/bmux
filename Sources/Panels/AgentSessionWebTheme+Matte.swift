import BmuxAppKitSupportUI

extension AgentSessionWebTheme {
    /// Adapts the shared palette to the existing web renderer's theme contract.
    static func matte(_ theme: MatteTheme) -> AgentSessionWebTheme {
        AgentSessionWebTheme(
            isDark: theme.colorScheme == .dark,
            pageBackground: theme.color(.panel).markdownCSSColor,
            surfaceBackground: theme.color(.card).markdownCSSColor,
            surfaceElevatedBackground: theme.color(.cardHover).markdownCSSColor,
            inputBackground: theme.color(.inset).markdownCSSColor,
            border: theme.color(.edge).markdownCSSColor,
            borderStrong: theme.color(.edge).markdownCSSColor,
            text: theme.color(.textPrimary).markdownCSSColor,
            mutedText: theme.color(.textSecondary).markdownCSSColor,
            softText: theme.color(.textTertiary).markdownCSSColor,
            accent: theme.color(.link).markdownCSSColor,
            accentSoft: theme.color(.pressWash).markdownCSSColor,
            danger: theme.color(.danger).markdownCSSColor,
            shadow: (theme.shadows(.contactOne).first?.color ?? theme.color(.edge)).markdownCSSColor
        )
    }
}
