import Foundation

/// Internal persisted metadata for one storage-integrity repair wrapper call.
struct ProvenanceSQLiteStorageRepairAttempt: Equatable, Sendable {
    /// SQLite append sequence for the repair-attempt metadata row.
    var sequence: Int

    /// Time the repair wrapper call started.
    var attemptedAt: Date

    /// Initial bounded storage-integrity status.
    var initialStatus: String

    /// Whether the initial report recommended projection repair.
    var repairRecommended: Bool

    /// Whether the wrapper attempted projection repair.
    var repairAttempted: Bool

    /// Whether projection repair rebuilt current-state projection tables.
    var repaired: Bool

    /// Number of immutable ledger events replayed during repair.
    var replayedEventCount: Int

    /// Post-repair bounded storage-integrity status when repair ran.
    var postRepairStatus: String?
}
