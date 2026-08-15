/// Canonical event for a completed provider turn.
public struct ExecutionTelemetryTurnCompletedEvent: Sendable, Equatable, Decodable {
    /// Provider-native turn id, when available.
    public let turnID: String?

    /// Turn duration in milliseconds, when available.
    public let durationMs: Int?

    private enum CodingKeys: String, CodingKey {
        case turnID = "turnId"
        case durationMs
    }
}
