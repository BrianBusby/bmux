/// Internal report for a storage-integrity repair attempt.
struct ProvenanceSQLiteStorageRepairReport: Equatable, Sendable {
    /// Integrity report collected before any repair work.
    var initialIntegrityReport: ProvenanceSQLiteStorageIntegrityReport

    /// Whether the integrity repair path attempted a projection repair.
    var repairAttempted: Bool

    /// Projection repair result when the initial integrity report made repair safe.
    var projectionRepairReport: ProvenanceSQLiteProjectionRepairReport?

    /// Integrity report collected after repair, when repair ran.
    var postRepairIntegrityReport: ProvenanceSQLiteStorageIntegrityReport?
}
