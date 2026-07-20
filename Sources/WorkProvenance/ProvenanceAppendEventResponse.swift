import Foundation

/// Response for a successful provenance event append.
struct ProvenanceAppendEventResponse: Codable, Equatable, Sendable {
    /// Schema version for this response shape.
    let schemaVersion: Int

    /// Identifier of the event accepted into the authoritative ledger.
    let eventID: String

    /// Event type accepted into the authoritative ledger.
    let eventType: String

    /// Creates an append response.
    init(schemaVersion: Int = 1, eventID: String, eventType: String) {
        self.schemaVersion = schemaVersion
        self.eventID = eventID
        self.eventType = eventType
    }
}
