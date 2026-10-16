/// Semantic colors shared by native matte surfaces.
public enum MatteColorRole: CaseIterable, Sendable {
    /// Continuous canvas behind the sidebar and panel.
    case base
    /// Main workspace panel.
    case panel
    /// Resting workspace card and menu surfaces.
    case card
    /// Hovered workspace card.
    case cardHover
    /// Selected workspace card.
    case cardSelected
    /// Hovered selected workspace card.
    case cardSelectedHover
    /// Recessed terminal and terminal tab surface.
    case inset
    /// Search field and segmented control track.
    case field
    /// Raised icon button.
    case button
    /// Hovered raised icon button.
    case buttonHover
    /// Avatar, count pill, and idle chip.
    case chip
    /// Primary text.
    case textPrimary
    /// Secondary text and icons.
    case textSecondary
    /// Placeholder and tertiary text.
    case textTertiary
    /// Reference terminal text; does not override terminal preferences.
    case terminalText
    /// Translucent hairline rules.
    case edge
    /// Translucent flat-control hover treatment.
    case hoverWash
    /// Translucent flat-control press treatment.
    case pressWash
    /// Selection ring, active tab mark, and selected-card label mark.
    case selectionRing
    /// Keyboard focus outline.
    case focus
    /// Links.
    case link
    /// Hovered links, paired with an underline.
    case linkHover
    /// Repository label and brand mark.
    case sage
    /// Success status foreground.
    case success
    /// Warning status foreground.
    case warning
    /// Error status foreground.
    case danger
    /// Information status foreground.
    case information
}
