import SwiftUI

/// Paints native surface ingredients behind content without affecting layout or input.
struct MatteSurfaceDecoration: View {
    let role: MatteSurfaceRole
    let theme: MatteTheme
    let state: MatteSurfaceState

    var body: some View {
        let appearance = MatteSurfaceAppearance(role: role, state: state)
        let shape = RoundedRectangle(cornerRadius: appearance.radius(in: theme, role: role), style: .circular)
        ZStack {
            castShadow(appearance.ambient, shape: shape, fill: appearance.fill)
            castShadow(appearance.contact, shape: shape, fill: appearance.fill)
            shape.fill(Color(nsColor: theme.color(appearance.fill)))
            if let contour = appearance.contour {
                ForEach(Array(theme.shadows(contour).enumerated()), id: \.offset) { _, shadow in
                    shape.inset(by: -shadow.spread)
                        .strokeBorder(Color(nsColor: shadow.color), lineWidth: shadow.spread)
                }
            }
            if let edge = appearance.innerEdge {
                MatteSurfaceInnerEdge(shape: shape, shadows: theme.shadows(edge), isRecessed: role == .inset)
            }
            if state.isFocused && state.isEnabled && role != .base {
                shape.inset(by: -(theme.layout.focusOutlineOffset + theme.layout.focusOutlineWidth))
                    .strokeBorder(Color(nsColor: theme.color(.focus)), lineWidth: theme.layout.focusOutlineWidth)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func castShadow(_ role: MatteShadowRole?, shape: RoundedRectangle, fill: MatteColorRole) -> some View {
        if let role {
            ForEach(Array(theme.shadows(role).enumerated()), id: \.offset) { _, shadow in
                shape.inset(by: -shadow.spread)
                    .fill(Color(nsColor: theme.color(fill)))
                    .shadow(color: Color(nsColor: shadow.color), radius: shadow.blur / 2,
                            x: shadow.offsetX, y: shadow.offsetY)
            }
        }
    }
}
