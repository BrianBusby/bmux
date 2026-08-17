import Foundation

/// One SQLite schema migration step owned by the engine storage layer.
struct ProvenanceSQLiteMigration: Equatable, Sendable {
    /// Target `PRAGMA user_version` after this migration succeeds.
    let version: Int32

    /// SQL statements to execute for this migration.
    let statements: [String]

    /// Creates a migration step.
    ///
    /// - Parameters:
    ///   - version: Target `PRAGMA user_version` after this migration succeeds.
    ///   - statements: SQL statements to execute before setting `user_version`.
    init(version: Int32, statements: [String]) {
        self.version = version
        self.statements = statements
    }
}
