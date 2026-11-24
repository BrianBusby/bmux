import Foundation

/// An opt-in ledger insertion operation that reports an existing event ID.
///
/// An existing ID is only a collision candidate: it does not establish that
/// the incoming and retained evidence are equivalent or safe to acknowledge.
public protocol ProvenanceLedgerIDCandidateClient: Sendable {
    /// Attempts one ledger insertion without changing the v1 append contract.
    ///
    /// - Parameter request: The event to insert.
    /// - Returns: Whether the insertion committed or the ID was already present.
    /// - Throws: A storage or projection failure other than an ID conflict.
    func appendLedgerIDCandidate(_ request: ProvenanceAppendEventRequest) async throws -> ProvenanceLedgerIDCandidateResult
}

/// The narrowly scoped result of an opt-in ledger insertion attempt.
public enum ProvenanceLedgerIDCandidateResult: String, Codable, Equatable, Sendable {
    /// The event and its projections committed atomically.
    case inserted
    /// The event ID was already present; its evidence has not been compared.
    case idAlreadyPresent
}
