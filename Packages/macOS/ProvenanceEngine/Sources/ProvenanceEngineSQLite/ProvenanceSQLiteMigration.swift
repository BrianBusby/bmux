import Foundation

/// One SQLite schema migration step owned by the engine storage layer.
struct ProvenanceSQLiteMigration: Equatable, Sendable {
    /// Adds a column only when it is absent in an older schema lineage.
    struct ConditionalColumnAddition: Equatable, Sendable {
        let table: String
        let column: String
        let statement: String
    }

    /// Target `PRAGMA user_version` after this migration succeeds.
    let version: Int32

    /// SQL statements to execute for this migration.
    let statements: [String]

    /// Optional column addition for schema versions used by older builds.
    let conditionalColumnAddition: ConditionalColumnAddition?

    /// Creates a migration step.
    ///
    /// - Parameters:
    ///   - version: Target `PRAGMA user_version` after this migration succeeds.
    ///   - statements: SQL statements to execute before setting `user_version`.
    ///   - conditionalColumnAddition: Column to add when a prior schema lineage lacks it.
    init(
        version: Int32,
        statements: [String],
        conditionalColumnAddition: ConditionalColumnAddition? = nil
    ) {
        self.version = version
        self.statements = statements
        self.conditionalColumnAddition = conditionalColumnAddition
    }
}
