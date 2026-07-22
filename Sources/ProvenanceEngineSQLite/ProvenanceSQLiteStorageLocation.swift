import Foundation

/// Internal engine-owned location for the SQLite provenance database.
struct ProvenanceSQLiteStorageLocation: Equatable, Sendable {
    /// User home directory used to resolve the default state path.
    let homeDirectory: URL

    /// Creates a storage location rooted at a user home directory.
    ///
    /// - Parameter homeDirectory: User home directory used for default engine-owned state.
    init(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.homeDirectory = homeDirectory
    }

    /// Engine-owned SQLite database URL for new provenance data.
    var databaseURL: URL {
        homeDirectory
            .appendingPathComponent(".local", isDirectory: true)
            .appendingPathComponent("state", isDirectory: true)
            .appendingPathComponent("provenance-engine", isDirectory: true)
            .appendingPathComponent("provenance.sqlite")
    }
}
