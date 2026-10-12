/// Font metrics preserving the reference numeric weight and tracking.
public struct MatteTypographyMetrics: Sendable {
    /// Font size in points.
    public let pointSize: Double

    /// Reference numeric font weight on the CSS 100–900 scale.
    public let weight: Double

    /// Additional letter spacing in em units.
    public let trackingEm: Double

    /// Optional explicit line-height multiplier.
    public let lineHeightMultiple: Double?

    /// Whether the role uses the system monospace family.
    public let usesMonospacedFont: Bool

    /// Whether the role calls for uppercase section-label presentation.
    public let usesUppercase: Bool
}
