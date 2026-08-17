import Foundation
import ProvenanceEngineContracts

/// Internal append-order event ledger row returned by SQLite cursor reads.
struct ProvenanceEventLedgerEntry: Equatable, Sendable {
    /// SQLite append sequence for the event.
    let sequence: Int

    /// Persisted provenance event at this sequence.
    let event: ProvenanceEvent
}
