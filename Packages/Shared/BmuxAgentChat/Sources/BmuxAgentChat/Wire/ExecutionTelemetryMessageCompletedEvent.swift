/// Canonical event for a completed provider message item.
public struct ExecutionTelemetryMessageCompletedEvent: Sendable, Equatable, Decodable {
    /// Message stream name, such as `assistant` or `reasoning`.
    public let stream: String

    /// Provider item id, when available.
    public let itemID: String?

    /// Completed visible text, when the provider exposes a completed item.
    public let text: String?

    private enum CodingKeys: String, CodingKey {
        case stream
        case itemID = "itemId"
        case text
    }
}
