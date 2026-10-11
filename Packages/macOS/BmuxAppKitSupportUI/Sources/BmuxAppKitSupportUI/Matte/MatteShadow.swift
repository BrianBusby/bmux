public import AppKit

/// One immutable shadow layer, retaining spread and inset semantics.
public struct MatteShadow: Sendable {
    /// Resolved sRGB shadow color, including its opacity.
    public let color: NSColor

    /// Horizontal offset in points; positive means right.
    public let offsetX: Double

    /// Vertical offset in points; positive means down.
    public let offsetY: Double

    /// Reference box-shadow blur in points, before native renderer conversion.
    public let blur: Double

    /// Spread in points; negative values contract the shadow shape.
    public let spread: Double

    /// Whether the layer is clipped inside its surface.
    public let isInset: Bool
}
