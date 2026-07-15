public import Foundation

/// Reads compact Codex thread metadata from a snapshot copy of Codex state.
///
/// The reader never opens the selected Codex state database in place. Each read
/// copies the database and SQLite sidecars to a temporary directory, then opens
/// that copy read-only so live Codex writes are not blocked by bmux diagnostics.
public actor CodexStateMetadataReader {
    private let explicitDatabaseURL: URL?
    private let codexHomeURL: URL?
    private let temporaryDirectoryURL: URL
    private let fileManager: FileManager
    private let idFactory = ContextEfficiencyStableIDFactory()

    /// Creates a Codex state metadata reader.
    ///
    /// - Parameters:
    ///   - databaseURL: Explicit Codex state SQLite database, if known.
    ///   - codexHomeURL: Codex home directory used to discover `state_*.sqlite`.
    ///   - fileManager: Filesystem dependency used for discovery and snapshots.
    ///   - temporaryDirectoryURL: Directory where snapshot copies are created.
    public init(
        databaseURL: URL? = nil,
        codexHomeURL: URL? = nil,
        fileManager: FileManager = .default,
        temporaryDirectoryURL: URL? = nil
    ) {
        self.explicitDatabaseURL = databaseURL
        self.codexHomeURL = codexHomeURL
        self.fileManager = fileManager
        self.temporaryDirectoryURL = temporaryDirectoryURL ?? fileManager.temporaryDirectory
    }

    /// Reads all compact thread metadata rows from a snapshot copy.
    ///
    /// - Parameter readAt: Timestamp to record on the returned snapshot.
    /// - Returns: Compact Codex metadata rows.
    /// - Throws: ``CodexStateMetadataReaderError`` or filesystem errors.
    public func readSnapshot(readAt: Date = Date()) throws -> CodexStateMetadataSnapshot {
        let location = try resolveDatabaseLocation()
        let sourceURL = URL(fileURLWithPath: location.databasePath)
        let snapshotDirectory = temporaryDirectoryURL
            .appendingPathComponent("bmux-codex-state-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: snapshotDirectory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: snapshotDirectory) }

        let snapshotURL = snapshotDirectory.appendingPathComponent("state.sqlite", isDirectory: false)
        try copyDatabaseSnapshot(from: sourceURL, to: snapshotURL)
        let reader = try CodexStateSQLiteReader(databaseURL: snapshotURL, idFactory: idFactory)
        return CodexStateMetadataSnapshot(
            location: location,
            readAt: readAt,
            threads: try reader.readThreads()
        )
    }

    /// Finds compact metadata for the thread that owns a rollout path.
    ///
    /// - Parameter rolloutURL: Rollout JSONL path to match against Codex state.
    /// - Returns: Matching thread metadata, or `nil` when Codex state has no row.
    /// - Throws: ``CodexStateMetadataReaderError`` or filesystem errors.
    public func threadMetadata(forRollout rolloutURL: URL) throws -> CodexStateThreadMetadata? {
        let targetPath = standardizedPath(rolloutURL.path)
        return try readSnapshot().threads.first { thread in
            guard let rolloutPath = thread.rolloutPath else { return false }
            return standardizedPath(rolloutPath) == targetPath
        }
    }

    private func resolveDatabaseLocation() throws -> CodexStateDatabaseLocation {
        if let explicitDatabaseURL {
            let path = standardizedPath(explicitDatabaseURL.path)
            guard fileManager.fileExists(atPath: path) else {
                throw CodexStateMetadataReaderError.databaseNotFound(path)
            }
            return CodexStateDatabaseLocation(databasePath: path, codexHomePath: nil)
        }

        let homeURL = codexHomeURL ?? fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex", isDirectory: true)
        let standardizedHomePath = standardizedPath(homeURL.path)
        let standardizedHomeURL = URL(fileURLWithPath: standardizedHomePath, isDirectory: true)
        let selectedURL = highestStateDatabase(in: standardizedHomeURL)
            ?? standardizedHomeURL.appendingPathComponent("state_5.sqlite", isDirectory: false)
        let selectedPath = standardizedPath(selectedURL.path)
        guard fileManager.fileExists(atPath: selectedPath) else {
            throw CodexStateMetadataReaderError.databaseNotFound(selectedPath)
        }
        return CodexStateDatabaseLocation(
            databasePath: selectedPath,
            codexHomePath: standardizedHomePath
        )
    }

    private func highestStateDatabase(in directoryURL: URL) -> URL? {
        let contents = (try? fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []
        return contents.compactMap { url -> (version: Int, url: URL)? in
            let name = url.lastPathComponent
            guard name.hasPrefix("state_"), name.hasSuffix(".sqlite") else {
                return nil
            }
            let versionText = name
                .dropFirst("state_".count)
                .dropLast(".sqlite".count)
            guard let version = Int(versionText) else {
                return nil
            }
            return (version, url)
        }
        .sorted { $0.version > $1.version }
        .first?
        .url
    }

    private func copyDatabaseSnapshot(from sourceURL: URL, to snapshotURL: URL) throws {
        try fileManager.copyItem(at: sourceURL, to: snapshotURL)
        for suffix in ["-wal", "-shm"] {
            let sidecarSource = URL(fileURLWithPath: sourceURL.path + suffix, isDirectory: false)
            guard fileManager.fileExists(atPath: sidecarSource.path) else { continue }
            let sidecarDestination = URL(fileURLWithPath: snapshotURL.path + suffix, isDirectory: false)
            try? fileManager.copyItem(at: sidecarSource, to: sidecarDestination)
        }
    }

    private func standardizedPath(_ path: String) -> String {
        ((path as NSString).expandingTildeInPath as NSString).standardizingPath
    }
}
