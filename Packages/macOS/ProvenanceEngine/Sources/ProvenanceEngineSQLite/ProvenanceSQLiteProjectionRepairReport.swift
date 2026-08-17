/// Internal report for a projection-drift repair attempt.
struct ProvenanceSQLiteProjectionRepairReport: Equatable, Sendable {
    /// Projection-key validation result collected before any repair work.
    var validation: ProvenanceSQLiteProjectionKeyValidationReport

    /// Whether current-state projection tables were rebuilt from the event ledger.
    var repaired: Bool

    /// Number of event-ledger rows replayed when repair ran.
    var replayedEventCount: Int

    /// Projection-key validation result collected after repair, when repair ran.
    var postRepairValidation: ProvenanceSQLiteProjectionKeyValidationReport?
}
