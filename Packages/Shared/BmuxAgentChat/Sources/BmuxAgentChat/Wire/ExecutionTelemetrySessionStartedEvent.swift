/// Canonical event for sidecar session start metadata.
public struct ExecutionTelemetrySessionStartedEvent: Sendable, Equatable, Decodable {
    /// Working directory associated with the session.
    public let cwd: String

    /// Initial session title, when available.
    public let title: String?
}
