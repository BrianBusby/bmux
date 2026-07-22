import Foundation
import ProvenanceEngineContracts

/// Creates SQLite-backed engine clients for higher-level SDK composition.
public struct ProvenanceSQLiteClientFactory: Sendable {
    /// Creates a SQLite client factory.
    public init() {}

    /// Opens a SQLite-backed ``ProvenanceEngineClient`` at a specific database URL.
    ///
    /// - Parameter databaseURL: SQLite database file URL to open or create.
    /// - Returns: An in-process client backed by engine-owned SQLite storage.
    /// - Throws: ``ProvenanceSQLiteError`` or filesystem errors when opening or migrating fails.
    public func client(databaseURL: URL) throws -> any ProvenanceEngineClient {
        try ProvenanceSQLiteRepository(url: databaseURL)
    }

    /// Opens a SQLite-backed ``ProvenanceEngineClient`` at the default engine storage path.
    ///
    /// - Parameter homeDirectory: User home directory used to resolve the engine-owned default state path.
    /// - Returns: An in-process client backed by engine-owned SQLite storage.
    /// - Throws: ``ProvenanceSQLiteError`` or filesystem errors when opening or migrating fails.
    public func client(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) throws -> any ProvenanceEngineClient {
        try ProvenanceSQLiteRepository(
            storageLocation: ProvenanceSQLiteStorageLocation(homeDirectory: homeDirectory)
        )
    }
}
