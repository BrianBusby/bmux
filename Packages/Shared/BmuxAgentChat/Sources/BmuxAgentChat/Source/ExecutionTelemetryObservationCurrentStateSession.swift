/// Bounded Current State session facts used by the execution telemetry observation diagnostic.
public struct ExecutionTelemetryObservationCurrentStateSession: Sendable, Equatable {
    /// Session identifier from the Current State source.
    public let sessionID: String

    /// Provider or agent kind, when Current State already exposes it.
    public let provider: String

    /// Broad lifecycle status from Current State.
    public let lifecycleStatus: String

    /// Creates a bounded Current State session snapshot for diagnostic comparison.
    ///
    /// - Parameters:
    ///   - sessionID: Session identifier from the Current State source.
    ///   - provider: Provider or agent kind, when Current State already exposes it.
    ///   - lifecycleStatus: Broad lifecycle status from Current State.
    public init(sessionID: String, provider: String, lifecycleStatus: String) {
        self.sessionID = sessionID
        self.provider = provider
        self.lifecycleStatus = lifecycleStatus
    }
}
