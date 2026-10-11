import AppKit
import BmuxAppKitSupportUI

/// Supplies only the matte terminal container colors to the existing config loader.
struct MatteTerminalConfiguration {
    let colorScheme: GhosttyConfig.ColorSchemePreference

    var contents: String {
        let theme = MatteTheme(colorScheme: colorScheme == .dark ? .dark : .light)
        return "foreground = \(theme.color(.terminalText).hexString())\nbackground = \(theme.color(.inset).hexString())\nbackground-opacity = 1"
    }
}
