import Foundation

/// Resolves conventional on-disk locations for work provenance storage.
///
/// The standard location mirrors bmux runtime state under `~/.local/state/bmux`
/// so both the GUI app and standalone CLI can read it without touching
/// macOS-protected Application Support app data.
struct WorkProvenanceStorageLocation: Equatable, Hashable, Sendable {
    /// The root directory for provenance state.
    let directoryURL: URL

    /// The SQLite database file URL.
    let databaseURL: URL

    /// Creates a storage location rooted in the given directory.
    ///
    /// - Parameter directoryURL: Directory that will contain the SQLite file.
    init(directoryURL: URL) {
        self.directoryURL = directoryURL
        self.databaseURL = directoryURL.appendingPathComponent("bmux-work-provenance.sqlite", isDirectory: false)
    }

    /// Creates the standard per-user storage location.
    ///
    /// - Parameter homeDirectory: The user's home directory.
    init(homeDirectory: URL) {
        self.init(
            directoryURL: homeDirectory
                .appendingPathComponent(".local", isDirectory: true)
                .appendingPathComponent("state", isDirectory: true)
                .appendingPathComponent("bmux", isDirectory: true)
                .appendingPathComponent("work-provenance", isDirectory: true)
        )
    }
}
