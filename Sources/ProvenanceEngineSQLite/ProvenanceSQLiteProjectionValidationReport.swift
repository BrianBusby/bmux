/// Bounded validation summary for internal SQLite projection row counts.
struct ProvenanceSQLiteProjectionValidationReport: Equatable, Sendable {
    /// Number of event-ledger rows decoded into expected projection counts.
    var checkedEventCount: Int

    /// Latest SQLite append sequence checked by this validation pass.
    var latestCheckedSequence: Int?

    /// Whether more ledger rows exist beyond the requested validation limit.
    var truncated: Bool

    /// Whether current projection counts were compared to ledger-derived counts.
    var comparedProjectionCounts: Bool

    /// Projection table count mismatches found when comparison was possible.
    var mismatches: [ProvenanceSQLiteProjectionValidationMismatch]
}
