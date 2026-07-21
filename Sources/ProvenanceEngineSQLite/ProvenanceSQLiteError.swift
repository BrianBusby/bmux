import Foundation

/// Errors produced by engine-owned SQLite storage support.
enum ProvenanceSQLiteError: Error, Equatable, Sendable {
    /// SQLite returned an error message.
    case sqlite(message: String)
}
