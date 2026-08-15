/// Canonical event for a failed provider turn.
public struct ExecutionTelemetryTurnFailedEvent: Sendable, Equatable, Decodable {
    /// Provider-native turn id, when available.
    public let turnID: String?

    /// Turn duration in milliseconds, when available.
    public let durationMs: Int?

    /// Bounded failure details.
    public let error: ExecutionTelemetryErrorInfo

    private enum CodingKeys: String, CodingKey {
        case turnID = "turnId"
        case durationMs
        case error
    }
}
