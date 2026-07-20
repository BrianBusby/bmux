import Foundation

/// Request to append one immutable provenance event.
struct ProvenanceAppendEventRequest: Codable, Equatable, Sendable {
    /// Event to persist in the authoritative ledger.
    let event: WorkProvenanceEvent

    /// Creates an event append request.
    init(event: WorkProvenanceEvent) {
        self.event = event
    }
}
