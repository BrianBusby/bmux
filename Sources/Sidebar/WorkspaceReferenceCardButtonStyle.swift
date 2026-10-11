import BmuxAppKitSupportUI
import SwiftUI

/// Native selection feedback; the card keeps its independent controls as siblings.
struct WorkspaceReferenceCardButtonStyle: ButtonStyle {
    let theme: MatteTheme
    let isSelected: Bool
    let isHovered: Bool
    let isFocused: Bool
    let isEnabled: Bool
    @Binding var isPressed: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .matteSurface(.card, theme: theme, state: .init(
                isSelected: isSelected, isHovered: isHovered, isPressed: configuration.isPressed,
                isFocused: isFocused, isEnabled: isEnabled))
            .onChange(of: configuration.isPressed) { _, value in isPressed = value }
    }
}
