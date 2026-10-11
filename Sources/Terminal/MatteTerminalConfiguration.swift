import AppKit
import BmuxAppKitSupportUI

/// Supplies default terminal colors before user themes and color overrides are loaded.
struct MatteTerminalConfiguration {
    let colorScheme: GhosttyConfig.ColorSchemePreference

    var contents: String {
        let theme = MatteTheme(colorScheme: colorScheme == .dark ? .dark : .light)
        return "foreground = \(theme.color(.terminalText).hexString())\nbackground = \(theme.color(.inset).hexString())"
    }
}
