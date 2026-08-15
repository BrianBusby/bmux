/// Canonical event for a started provider turn.
public struct ExecutionTelemetryTurnStartedEvent: Sendable, Equatable, Decodable {
    /// Provider-native turn id, when available.
    public let turnID: String?

    /// Selected provider model, when known.
    public let model: String?

    /// Selected provider effort setting, when known.
    public let effort: String?

    private enum CodingKeys: String, CodingKey {
        case turnID = "turnId"
        case model
        case effort
    }
}
