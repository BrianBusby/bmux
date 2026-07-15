import Foundation

/// Resolved location of a Codex state SQLite database.
public struct CodexStateDatabaseLocation: Codable, Equatable, Sendable {
    /// SQLite database file that was selected.
    public var databasePath: String
    /// Codex home directory used for discovery, when discovery was used.
    public var codexHomePath: String?

    /// Creates a resolved Codex state database location.
    ///
    /// - Parameters:
    ///   - databasePath: SQLite database file that was selected.
    ///   - codexHomePath: Codex home directory used for discovery, if any.
    public init(databasePath: String, codexHomePath: String?) {
        self.databasePath = databasePath
        self.codexHomePath = codexHomePath
    }
}
