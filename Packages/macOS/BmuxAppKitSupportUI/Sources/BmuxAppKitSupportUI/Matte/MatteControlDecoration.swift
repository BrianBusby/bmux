import SwiftUI

/// Draws control chrome without owning events, focus, or content.
struct MatteControlDecoration: View {
    let role: MatteControlRole
    let theme: MatteTheme
    let state: MatteSurfaceState

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: role == .flat || role == .link
            ? theme.layout.compactControlRadius : theme.layout.controlRadius)
        let pressed = state.isPressed && state.isEnabled
        let hovered = state.isHovered && state.isEnabled && !pressed
        ZStack {
            if role == .raised || role == .field {
                if role == .raised && !pressed {
                    ForEach(Array(theme.shadows(.contactZero).enumerated()), id: \.offset) { _, shadow in
                        shape.fill(color(.button))
                            .shadow(color: Color(nsColor: shadow.color), radius: shadow.blur / 2,
                                    x: shadow.offsetX, y: shadow.offsetY)
                    }
                }
                shape.fill(color(role == .field ? .field : state.isSelected
                    ? (hovered ? .cardSelectedHover : .cardSelected) : (hovered ? .buttonHover : .button)))
                MatteSurfaceInnerEdge(shape: shape, shadows: theme.shadows(
                    role == .field ? .fieldInset : pressed ? .pressed
                        : state.isSelected ? .selectedLit : .lit
                ), isRecessed: role == .field || pressed)
                if role == .raised && (!pressed || state.isSelected) {
                    ForEach(Array(theme.shadows(state.isSelected ? .ring : .hairline).enumerated()), id: \.offset) { _, shadow in
                        shape.inset(by: -shadow.spread)
                            .strokeBorder(Color(nsColor: shadow.color), lineWidth: shadow.spread)
                    }
                }
            } else if state.isEnabled && (pressed || hovered) {
                shape.fill(color(pressed ? .pressWash : .hoverWash))
            }
            if state.isFocused && state.isEnabled {
                shape.inset(by: -(theme.layout.focusOutlineOffset + theme.layout.focusOutlineWidth))
                    .strokeBorder(color(.focus), lineWidth: theme.layout.focusOutlineWidth)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func color(_ role: MatteColorRole) -> Color { Color(nsColor: theme.color(role)) }
}
