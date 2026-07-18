import Foundation

/// Errors produced by the context-efficiency telemetry store.
public enum ContextEfficiencyStoreError: Error, Equatable, Sendable {
    /// SQLite returned an error message.
    case sqlite(message: String)
    /// The database schema is newer than this package supports.
    case unsupportedSchema(found: Int32, supported: Int32)
    /// A required row could not be decoded from SQLite.
    case invalidRow(String)
}
