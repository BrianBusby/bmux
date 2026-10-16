/// Cubic Bézier control points for native matte transitions.
public struct MatteTimingCurve: Sendable {
    /// First control point x coordinate.
    public let x1: Double

    /// First control point y coordinate.
    public let y1: Double

    /// Second control point x coordinate.
    public let x2: Double

    /// Second control point y coordinate.
    public let y2: Double
}
