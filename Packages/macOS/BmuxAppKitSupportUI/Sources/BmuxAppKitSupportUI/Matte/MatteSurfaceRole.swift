/// Semantic surfaces in the native matte elevation hierarchy.
public enum MatteSurfaceRole: CaseIterable, Sendable {
    /// Flat continuous canvas behind sidebar and workspace content.
    case base
    /// Raised workspace card whose decoration follows immutable interaction values.
    case card
    /// Resting main workspace panel.
    case panel
    /// Recessed terminal surface with no outward cast shadow.
    case inset
    /// Floating menu or popover surface at the highest content elevation.
    case overlay
}
