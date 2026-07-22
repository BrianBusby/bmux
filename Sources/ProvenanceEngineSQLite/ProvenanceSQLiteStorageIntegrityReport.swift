/// Internal bounded integrity report for SQLite ledger and projection state.
struct ProvenanceSQLiteStorageIntegrityReport: Equatable, Sendable {
    /// Overall bounded status: `healthy`, `ledger_invalid`, `projection_drift`, or `validation_truncated`.
    var status: String

    /// Whether projection repair is safe to attempt from the current validation pass.
    var repairRecommended: Bool

    /// Current internal ledger and projection row counts.
    var storageSummary: ProvenanceSQLiteStorageSummary

    /// Bounded event-ledger validation result.
    var ledgerValidation: ProvenanceSQLiteLedgerValidationReport

    /// Projection count comparison when the ledger validation is usable.
    var projectionCountValidation: ProvenanceSQLiteProjectionValidationReport?

    /// Projection key comparison when the ledger validation is usable.
    var projectionKeyValidation: ProvenanceSQLiteProjectionKeyValidationReport?
}
