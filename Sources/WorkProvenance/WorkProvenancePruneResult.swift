import Foundation

/// Summary of one provenance pruning pass.
struct WorkProvenancePruneResult: Equatable, Sendable {
    /// Raw observed events deleted from the ledger.
    let eventsDeleted: Int

    /// Stale unattributed file-change projection rows deleted.
    let fileChangesDeleted: Int

    /// Unreferenced observed change-set projection rows deleted.
    let changeSetsDeleted: Int

    /// Total rows deleted by this pruning pass.
    var totalRowsDeleted: Int {
        eventsDeleted + fileChangesDeleted + changeSetsDeleted
    }

    /// Creates a pruning summary.
    init(eventsDeleted: Int, fileChangesDeleted: Int, changeSetsDeleted: Int) {
        self.eventsDeleted = eventsDeleted
        self.fileChangesDeleted = fileChangesDeleted
        self.changeSetsDeleted = changeSetsDeleted
    }
}
