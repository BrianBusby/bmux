import Foundation

/// Response for a successful provenance event append.
public struct ProvenanceAppendEventResponse: Codable, Equatable, Sendable {
    /// Schema version for this response shape.
    public let schemaVersion: Int

    /// Identifier of the event accepted into the authoritative ledger.
    public let eventID: String

    /// Event type accepted into the authoritative ledger.
    public let eventType: String

    /// Creates an append response.
    public init(schemaVersion: Int = 1, eventID: String, eventType: String) {
        self.schemaVersion = schemaVersion
        self.eventID = eventID
        self.eventType = eventType
    }
}
