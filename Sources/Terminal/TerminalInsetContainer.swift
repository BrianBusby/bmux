import SwiftUI
import BmuxAppKitSupportUI

/// Keeps the native portal inside the matte inset's clear interior, without changing its rendering.
struct TerminalInsetContainer: ViewModifier {
    let isEnabled: Bool
    let theme: MatteTheme
    let backgroundColor: NSColor

    func body(content: Content) -> some View {
        if isEnabled {
            content
                .padding(theme.layout.terminalContentPadding)
                .matteSurface(.inset, theme: theme, fill: Color(nsColor: backgroundColor))
        } else {
            content
        }
    }
}
