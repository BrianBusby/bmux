/// REST payload returned by the sidecar bounded execution telemetry event endpoint.
public struct ExecutionTelemetryEventReadPayload: Sendable, Equatable, Decodable {
    /// bmux sidecar session id requested by the caller.
    public let sessionID: String

    /// Latest retained canonical telemetry sequence for the session.
    public let latestSequence: Int

    /// Canonical telemetry envelopes after the requested sequence cursor.
    public let events: [ExecutionTelemetryEventEnvelope]

    private enum CodingKeys: String, CodingKey {
        case sessionID = "sessionId"
        case latestSequence
        case events
    }
}
