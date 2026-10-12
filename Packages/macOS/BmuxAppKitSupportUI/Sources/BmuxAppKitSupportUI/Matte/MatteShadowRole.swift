/// Reusable shadow layers in the matte elevation vocabulary.
public enum MatteShadowRole: CaseIterable, Sendable {
    /// Subtle outer contour.
    case hairline
    /// Top and left inner highlights.
    case lit
    /// Inner highlight tinted for selected cards.
    case selectedLit
    /// Selection contour.
    case ring
    /// Shallow contact shadow for base controls.
    case contactZero
    /// Resting contact shadow.
    case contactOne
    /// Raised contact shadow.
    case contactTwo
    /// Overlay contact shadow.
    case contactThree
    /// Resting broad ambient shadow.
    case ambientOne
    /// Raised broad ambient shadow.
    case ambientTwo
    /// Overlay broad ambient shadow.
    case ambientThree
    /// Pressed inset and edge highlights.
    case pressed
    /// Recessed terminal contact and edge highlights.
    case terminalInset
    /// Recessed search-field contact and edge highlights.
    case fieldInset
    /// Reference window-tooling shadow; never applied to app content.
    case window
}
