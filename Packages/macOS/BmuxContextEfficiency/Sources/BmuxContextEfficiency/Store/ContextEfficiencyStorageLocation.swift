public import Foundation

/// Resolves conventional on-disk locations for context-efficiency telemetry.
///
/// The standard location mirrors other bmux local state under
/// `~/.local/state/bmux` so the app and standalone CLI can share read-only
/// diagnostics without relying on app-container storage.
public struct ContextEfficiencyStorageLocation: Equatable, Hashable, Sendable {
    /// Directory that contains the SQLite database.
    public var directoryURL: URL
    /// SQLite database file URL.
    public var databaseURL: URL

    /// Creates a storage location rooted in the given directory.
    ///
    /// - Parameter directoryURL: Directory that will contain the SQLite file.
    public init(directoryURL: URL) {
        self.directoryURL = directoryURL
        self.databaseURL = directoryURL
            .appendingPathComponent("bmux-context-efficiency.sqlite", isDirectory: false)
    }

    /// Creates the standard per-user storage location.
    ///
    /// - Parameter homeDirectory: User home directory used as the base path.
    public init(homeDirectory: URL) {
        self.init(
            directoryURL: homeDirectory
                .appendingPathComponent(".local", isDirectory: true)
                .appendingPathComponent("state", isDirectory: true)
                .appendingPathComponent("bmux", isDirectory: true)
                .appendingPathComponent("context-efficiency", isDirectory: true)
        )
    }
}
