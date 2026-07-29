/// One bounded mismatch between live execution telemetry and Current State.
public struct ExecutionTelemetryObservationMismatch: Sendable, Equatable {
    /// Stable mismatch code for JSON and text renderers.
    public let code: String

    /// Bounded live projection value for the compared fact.
    public let live: String

    /// Bounded Current State value for the compared fact.
    public let currentState: String

    /// Creates a bounded diagnostic mismatch.
    ///
    /// - Parameters:
    ///   - code: Stable mismatch code for JSON and text renderers.
    ///   - live: Bounded live projection value for the compared fact.
    ///   - currentState: Bounded Current State value for the compared fact.
    public init(code: String, live: String, currentState: String) {
        self.code = code
        self.live = live
        self.currentState = currentState
    }
}
