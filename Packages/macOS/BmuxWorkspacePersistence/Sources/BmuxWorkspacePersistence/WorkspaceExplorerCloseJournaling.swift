public import Foundation

/// Durable close identities consumed by Explorer archive recovery.
public protocol WorkspaceExplorerCloseJournaling: Sendable {
    /// Records a close before workspace removal returns.
    /// - Parameter candidate: The close identity to retain.
    /// - Throws: A filesystem or encoding error if the write fails.
    nonisolated func record(_ candidate: WorkspaceExplorerCloseRecord) throws

    /// Returns the latest retained close for each logical workspace.
    /// - Returns: Retained close identities in unspecified order.
    /// - Throws: A filesystem or decoding error if the journal cannot be read.
    func candidates() async throws -> [WorkspaceExplorerCloseRecord]

    /// Discards identities at or before the archive's clear timestamp.
    /// - Parameter timestamp: The clear time already accepted by the archive.
    /// - Throws: A filesystem error if the clear marker or cleanup cannot finish.
    func clear(through timestamp: Date) async throws
}
