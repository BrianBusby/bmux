/// Internal counts for the SQLite event ledger and current-state projection tables.
struct ProvenanceSQLiteStorageSummary: Equatable, Sendable {
    /// Current migrated schema version recorded in SQLite.
    var schemaVersion: Int32

    /// Number of immutable event-ledger rows.
    var eventCount: Int

    /// Latest SQLite append sequence in the event ledger.
    var latestEventSequence: Int?

    /// Number of repository projection rows.
    var repositoryCount: Int

    /// Number of worktree projection rows.
    var worktreeCount: Int

    /// Number of session projection rows.
    var sessionCount: Int

    /// Number of session relationship projection rows.
    var sessionRelationshipCount: Int

    /// Number of external identity projection rows.
    var externalIdentityCount: Int

    /// Number of work-item projection rows.
    var workItemCount: Int

    /// Number of contribution projection rows.
    var contributionCount: Int

    /// Number of checkpoint projection rows.
    var checkpointCount: Int

    /// Number of change-set projection rows.
    var changeSetCount: Int

    /// Number of file-change projection rows.
    var fileChangeCount: Int

    /// Number of validation-run projection rows.
    var validationRunCount: Int
}
