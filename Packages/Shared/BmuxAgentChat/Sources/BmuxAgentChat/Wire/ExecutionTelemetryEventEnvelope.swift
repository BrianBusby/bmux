/// One sidecar-assigned canonical execution telemetry envelope.
public struct ExecutionTelemetryEventEnvelope: Sendable, Equatable, Decodable {
    /// Wire schema identifier.
    public let schema: String

    /// Sidecar-assigned stable event id.
    public let eventID: String

    /// bmux sidecar session id that owns the event.
    public let sessionID: String

    /// Sidecar-assigned monotonic sequence within the session.
    public let sequence: Int

    /// Sidecar capture timestamp in Unix epoch milliseconds.
    public let capturedAtMs: Int

    /// Source that produced the telemetry fact.
    public let source: String

    /// Agent provider id, such as `codex`.
    public let provider: String

    /// Provider-native session or thread id, when known.
    public let providerSessionID: String?

    /// Provider-native turn id, when known.
    public let providerTurnID: String?

    /// Provider event identity fields, when available.
    public let providerEvent: ExecutionTelemetryProviderEventRef?

    /// Canonical event payload.
    public let event: ExecutionTelemetryEvent

    private enum CodingKeys: String, CodingKey {
        case schema
        case eventID = "eventId"
        case sessionID = "sessionId"
        case sequence
        case capturedAtMs
        case source
        case provider
        case providerSessionID = "providerSessionId"
        case providerTurnID = "providerTurnId"
        case providerEvent
        case event
    }
}
