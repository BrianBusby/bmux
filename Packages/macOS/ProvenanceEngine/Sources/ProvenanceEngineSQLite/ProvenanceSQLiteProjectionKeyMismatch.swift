/// One projection key whose current SQLite presence differs from ledger-derived expectation.
struct ProvenanceSQLiteProjectionKeyMismatch: Equatable, Sendable {
    /// SQLite projection table name.
    var tableName: String

    /// Stable projection key derived from the table's conflict identity.
    var key: String

    /// Mismatch kind: `missing` for expected keys absent from SQLite, `unexpected` for stale SQLite keys.
    var kind: String
}
