import Foundation

/// Errors produced by engine-owned SQLite storage support.
enum ProvenanceSQLiteError: Error, Equatable, Sendable {
    /// SQLite returned an error message.
    case sqlite(message: String)

    /// The database schema is newer than this package supports.
    case unsupportedSchema(found: Int32, supported: Int32)

    /// The opened SQLite file is not a compatible Provenance Engine store.
    case incompatibleDatabase(path: String, message: String)

    /// The declared migration sequence cannot be applied safely.
    case invalidMigrationPlan(message: String)
}

extension ProvenanceSQLiteError: CustomStringConvertible {
    var description: String {
        switch self {
        case .sqlite(let message):
            "sqlite(message: \"\(message)\")"
        case .unsupportedSchema(let found, let supported):
            "unsupportedSchema(found: \(found), supported: \(supported))"
        case .incompatibleDatabase(let path, let message):
            """
            provenance database compatibility error at \(path): \(message). This database is not a compatible Provenance Engine store. Automatic conversion was not performed. Use the canonical engine-owned store path or move this file aside after backing it up.
            """
        case .invalidMigrationPlan(let message):
            "invalidMigrationPlan(message: \"\(message)\")"
        }
    }
}
