/// Resolves semantic ingredients without owning interaction state or design values.
struct MatteSurfaceAppearance: Equatable {
    let fill: MatteColorRole
    let contour: MatteShadowRole?
    let innerEdge: MatteShadowRole?
    let contact: MatteShadowRole?
    let ambient: MatteShadowRole?

    init(role: MatteSurfaceRole, state: MatteSurfaceState) {
        switch role {
        case .base:
            fill = .base
            contour = nil
            innerEdge = nil
            contact = nil
            ambient = nil
        case .inset:
            fill = .inset
            contour = nil
            innerEdge = .terminalInset
            contact = nil
            ambient = nil
        case .panel, .overlay:
            fill = role == .panel ? .panel : .card
            contour = .hairline
            innerEdge = .lit
            contact = role == .panel ? .contactOne : .contactThree
            ambient = role == .panel ? .ambientOne : .ambientThree
        case .card:
            let hovered = state.isEnabled && state.isHovered && !state.isPressed
            let pressed = state.isEnabled && state.isPressed
            let raised = state.isEnabled && (state.isSelected || hovered) && !pressed
            fill = state.isSelected ? (hovered ? .cardSelectedHover : .cardSelected) : (hovered ? .cardHover : .card)
            contour = state.isSelected ? .ring : .hairline
            innerEdge = state.isSelected ? .selectedLit : .lit
            contact = raised ? .contactTwo : .contactOne
            ambient = pressed ? nil : (raised ? .ambientTwo : .ambientOne)
        }
    }

    func radius(in theme: MatteTheme, role: MatteSurfaceRole) -> Double {
        switch role {
        case .base: 0
        case .card, .overlay: theme.layout.cardRadius
        case .panel: theme.layout.panelRadius
        case .inset: theme.layout.terminalRadius
        }
    }
}
