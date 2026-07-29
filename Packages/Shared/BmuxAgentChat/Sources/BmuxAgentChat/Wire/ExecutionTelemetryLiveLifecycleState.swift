/// The sidecar's bounded lifecycle projection for one live execution session.
public enum ExecutionTelemetryLiveLifecycleState: String, Sendable, Equatable, Codable {
    /// No canonical execution telemetry has established lifecycle state yet.
    case unknown
    /// The session is not currently running a turn.
    case idle
    /// The session is actively running a turn.
    case running
    /// The most recent projected turn failed.
    case failed
}
