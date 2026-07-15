import Foundation

/// Errors produced by ``WorkProvenanceStore``.
enum WorkProvenanceStoreError: Error, Equatable, Sendable {
    /// SQLite returned an error message.
    case sqlite(message: String)

    /// The database schema is newer than this package can read.
    case unsupportedSchema(found: Int32, supported: Int32)

    /// A persisted JSON payload could not be decoded.
    case invalidPayload(eventID: String)
}
