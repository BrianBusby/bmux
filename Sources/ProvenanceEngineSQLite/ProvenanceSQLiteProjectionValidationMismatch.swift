/// One projection table whose current row count differs from ledger-derived expectation.
struct ProvenanceSQLiteProjectionValidationMismatch: Equatable, Sendable {
    /// SQLite projection table name.
    var tableName: String

    /// Number of rows expected after replaying the checked ledger prefix.
    var expectedCount: Int

    /// Number of rows currently stored in the projection table.
    var actualCount: Int
}
