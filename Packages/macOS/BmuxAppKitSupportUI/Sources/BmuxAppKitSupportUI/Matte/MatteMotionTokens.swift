/// Motion values resolved for the caller’s Reduce Motion preference.
public struct MatteMotionTokens: Sendable {
    /// Control transition duration in seconds; zero with Reduce Motion.
    public let controlDuration: Double

    /// Card transition duration in seconds; zero with Reduce Motion.
    public let cardDuration: Double

    /// Shared transition easing.
    public let curve: MatteTimingCurve

    /// Upward card-hover lift in points; zero with Reduce Motion.
    public let hoverLift: Double

    /// Lift for resting, selected, and pressed cards.
    public let stationaryLift: Double
}
