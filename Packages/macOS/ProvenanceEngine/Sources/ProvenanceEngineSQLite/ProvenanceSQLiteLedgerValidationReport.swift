/// Bounded validation summary for internal SQLite event-ledger rows.
struct ProvenanceSQLiteLedgerValidationReport: Equatable, Sendable {
    /// Number of ledger rows decoded or attempted within the requested bound.
    var checkedEventCount: Int

    /// Number of checked ledger rows that failed decoding or compatibility validation.
    var invalidEventCount: Int

    /// Latest SQLite append sequence checked by this validation pass.
    var latestCheckedSequence: Int?

    /// First invalid row, if any, with a bounded error summary.
    var firstInvalidIssue: ProvenanceSQLiteLedgerValidationIssue?

    /// Whether more ledger rows exist beyond the requested validation limit.
    var truncated: Bool
}
