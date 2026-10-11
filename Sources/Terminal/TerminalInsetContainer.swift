import SwiftUI
import BmuxAppKitSupportUI

/// Keeps the native portal inside the matte inset's clear interior, without changing its rendering.
struct TerminalInsetContainer: ViewModifier {
    let isEnabled: Bool
    let theme: MatteTheme

    func body(content: Content) -> some View {
        if isEnabled {
            content
                .padding(theme.layout.terminalContentPadding)
                .matteSurface(.inset, theme: theme)
        } else {
            content
        }
    }
}
