import Foundation

/// Internal persisted metadata for one applied SQLite schema migration.
struct ProvenanceSQLiteSchemaMigrationRecord: Equatable, Sendable {
    /// SQLite append sequence for the migration metadata row.
    var sequence: Int

    /// Target schema version applied by the migration.
    var version: Int32

    /// Time the migration was recorded as applied.
    var appliedAt: Date
}
