import Foundation

/// Request to append one immutable provenance event.
public struct ProvenanceAppendEventRequest: Codable, Equatable, Sendable {
    /// Event to persist in the authoritative ledger.
    public let event: ProvenanceEvent

    /// Creates an event append request.
    public init(event: ProvenanceEvent) {
        self.event = event
    }
}
