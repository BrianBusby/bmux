/// One invalid event-ledger row found during internal SQLite validation.
struct ProvenanceSQLiteLedgerValidationIssue: Equatable, Sendable {
    /// SQLite append sequence for the invalid row.
    var sequence: Int

    /// Stable event identifier for the invalid row when readable.
    var eventID: String?

    /// Bounded error summary describing why the row failed validation.
    var errorDescription: String
}
