/// Canonical event for a provider session/thread identity link.
public struct ExecutionTelemetryProviderSessionLinkedEvent: Sendable, Equatable, Decodable {
    /// Provider-native session or thread id.
    public let providerSessionID: String

    private enum CodingKeys: String, CodingKey {
        case providerSessionID = "providerSessionId"
    }
}
