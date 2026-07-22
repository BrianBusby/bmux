import Foundation
import ProvenanceEngineContracts
import ProvenanceEngineSQLite

/// Public factory for creating in-process Provenance Engine clients.
public struct ProvenanceEngineClientFactory: Sendable {
    private let sqliteFactory: ProvenanceSQLiteClientFactory

    /// Creates a client factory for the public in-process SDK.
    public init() {
        self.sqliteFactory = ProvenanceSQLiteClientFactory()
    }

    /// Opens an in-process SQLite-backed client at a specific database URL.
    ///
    /// - Parameter databaseURL: SQLite database file URL to open or create.
    /// - Returns: A client backed by engine-owned SQLite storage.
    /// - Throws: Filesystem or storage errors when opening or migrating fails.
    public func sqliteClient(databaseURL: URL) throws -> any ProvenanceEngineClient {
        try sqliteFactory.client(databaseURL: databaseURL)
    }

    /// Opens an in-process SQLite-backed client at the default engine storage path.
    ///
    /// - Parameter homeDirectory: User home directory used to resolve the default state path.
    /// - Returns: A client backed by engine-owned SQLite storage.
    /// - Throws: Filesystem or storage errors when opening or migrating fails.
    public func defaultSQLiteClient(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) throws -> any ProvenanceEngineClient {
        try sqliteFactory.client(homeDirectory: homeDirectory)
    }
}
