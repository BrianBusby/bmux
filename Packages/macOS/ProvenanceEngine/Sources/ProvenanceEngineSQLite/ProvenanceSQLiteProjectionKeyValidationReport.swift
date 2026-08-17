/// Bounded validation summary for internal SQLite projection table keys.
struct ProvenanceSQLiteProjectionKeyValidationReport: Equatable, Sendable {
    /// Number of event-ledger rows decoded into expected projection keys.
    var checkedEventCount: Int

    /// Latest SQLite append sequence checked by this validation pass.
    var latestCheckedSequence: Int?

    /// Whether more ledger rows exist beyond the requested validation limit.
    var truncated: Bool

    /// Whether current projection keys were compared to ledger-derived keys.
    var comparedProjectionKeys: Bool

    /// Maximum number of projection key mismatches included in the report.
    var mismatchLimit: Int

    /// Whether more mismatches exist beyond `mismatchLimit`.
    var truncatedMismatches: Bool

    /// Projection table key mismatches found when comparison was possible.
    var mismatches: [ProvenanceSQLiteProjectionKeyMismatch]
}
