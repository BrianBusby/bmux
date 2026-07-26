import Foundation


/// Resolves conventional on-disk locations for provenance storage.
struct WorkProvenanceStorageLocation: Equatable, Hashable, Sendable {
    /// The root directory for engine-owned V1 provenance state.
    let directoryURL: URL

    /// The canonical engine-owned V1 SQLite database file URL.
    let databaseURL: URL

    /// The retired bmux-local SQLite database file URL.
    let legacyDatabaseURL: URL

    /// The operational observability SQLite database file URL.
    let observabilityDatabaseURL: URL

    /// Creates a storage location rooted in the given engine directory.
    ///
    /// - Parameter directoryURL: Directory that will contain the engine SQLite file.
    init(directoryURL: URL) {
        self.directoryURL = directoryURL
        self.databaseURL = directoryURL.appendingPathComponent("provenance.sqlite", isDirectory: false)
        self.legacyDatabaseURL = directoryURL.appendingPathComponent(
            "bmux-work-provenance.sqlite",
            isDirectory: false
        )
        self.observabilityDatabaseURL = directoryURL.appendingPathComponent(
            "ProvenanceObservability.sqlite",
            isDirectory: false
        )
    }

    /// Resolves the home directory used for default engine-owned storage.
    ///
    /// `BMUX_PROVENANCE_HOME` is an explicit development/test override. Normal
    /// production launches leave it unset and use the OS user home directory.
    static func defaultHomeDirectory(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default
    ) -> URL {
        if let override = environment["BMUX_PROVENANCE_HOME"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !override.isEmpty {
            return URL(fileURLWithPath: NSString(string: override).expandingTildeInPath, isDirectory: true)
        }
        return fileManager.homeDirectoryForCurrentUser
    }

    /// Creates the standard per-user storage location.
    ///
    /// - Parameter homeDirectory: The user's home directory.
    init(homeDirectory: URL) {
        let stateDirectory = homeDirectory
            .appendingPathComponent(".local", isDirectory: true)
            .appendingPathComponent("state", isDirectory: true)
        let engineDirectory = stateDirectory
            .appendingPathComponent("provenance-engine", isDirectory: true)
        let bmuxLegacyDirectory = stateDirectory
            .appendingPathComponent("bmux", isDirectory: true)
            .appendingPathComponent("work-provenance", isDirectory: true)
        self.directoryURL = engineDirectory
        self.databaseURL = engineDirectory.appendingPathComponent("provenance.sqlite", isDirectory: false)
        self.legacyDatabaseURL = bmuxLegacyDirectory.appendingPathComponent(
            "bmux-work-provenance.sqlite",
            isDirectory: false
        )
        self.observabilityDatabaseURL = bmuxLegacyDirectory.appendingPathComponent(
            "ProvenanceObservability.sqlite",
            isDirectory: false
        )
    }
}
