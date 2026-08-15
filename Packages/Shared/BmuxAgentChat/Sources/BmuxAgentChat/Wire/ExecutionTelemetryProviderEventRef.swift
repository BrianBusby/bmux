/// Provider-side identity fields preserved on a canonical telemetry envelope.
public struct ExecutionTelemetryProviderEventRef: Sendable, Equatable, Decodable {
    /// Provider method or notification name, when available.
    public let method: String?

    /// Provider request id, when available.
    public let requestID: String?

    /// Provider item id, when available.
    public let itemID: String?

    /// Provider turn id, when available.
    public let turnID: String?

    /// Provider event sequence, when available.
    public let sequence: String?

    private enum CodingKeys: String, CodingKey {
        case method
        case requestID = "requestId"
        case itemID = "itemId"
        case turnID = "turnId"
        case sequence
    }

    /// Creates a provider event reference, accepting string or numeric provider ids.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.method = try container.decodeLooseStringIfPresent(forKey: .method)
        self.requestID = try container.decodeLooseStringIfPresent(forKey: .requestID)
        self.itemID = try container.decodeLooseStringIfPresent(forKey: .itemID)
        self.turnID = try container.decodeLooseStringIfPresent(forKey: .turnID)
        self.sequence = try container.decodeLooseStringIfPresent(forKey: .sequence)
    }
}

private extension KeyedDecodingContainer {
    func decodeLooseStringIfPresent(forKey key: Key) throws -> String? {
        if let string = try? decodeIfPresent(String.self, forKey: key) {
            return string
        }
        if let int = try? decodeIfPresent(Int.self, forKey: key) {
            return String(int)
        }
        if let double = try? decodeIfPresent(Double.self, forKey: key) {
            return String(double)
        }
        return nil
    }
}
