public import Foundation

/// Snapshot of compact Codex state metadata read from a copied SQLite database.
public struct CodexStateMetadataSnapshot: Codable, Equatable, Sendable {
    /// Source database location that was snapshotted.
    public var location: CodexStateDatabaseLocation
    /// Time the metadata snapshot was read.
    public var readAt: Date
    /// Compact thread metadata rows.
    public var threads: [CodexStateThreadMetadata]

    /// Number of thread rows in the snapshot.
    public var threadCount: Int {
        threads.count
    }

    /// Creates a Codex state metadata snapshot.
    ///
    /// - Parameters:
    ///   - location: Source database location that was snapshotted.
    ///   - readAt: Time the metadata snapshot was read.
    ///   - threads: Compact thread metadata rows.
    public init(
        location: CodexStateDatabaseLocation,
        readAt: Date,
        threads: [CodexStateThreadMetadata]
    ) {
        self.location = location
        self.readAt = readAt
        self.threads = threads
    }
}
