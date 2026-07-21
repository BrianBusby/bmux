import Foundation

/// Errors produced by engine-owned SQLite storage support.
enum ProvenanceSQLiteError: Error, Equatable, Sendable {
    /// SQLite returned an error message.
    case sqlite(message: String)

    /// The database schema is newer than this package supports.
    case unsupportedSchema(found: Int32, supported: Int32)

    /// The declared migration sequence cannot be applied safely.
    case invalidMigrationPlan(message: String)
}
