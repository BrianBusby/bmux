import Foundation

/// Persists complete raw terminal outputs under local reference keys.
public actor ChatRawTerminalOutputFileStore {
    private let rootDirectory: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    /// Creates a raw terminal output file store.
    ///
    /// - Parameters:
    ///   - rootDirectory: Directory where raw-output records are written.
    ///   - fileManager: File manager used for filesystem access.
    public init(
        rootDirectory: URL,
        fileManager: FileManager = .default
    ) {
        self.rootDirectory = rootDirectory
        self.fileManager = fileManager
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder
        self.decoder = JSONDecoder()
    }

    /// Writes raw terminal output records.
    ///
    /// Records without a `rawOutputRef` are ignored because they cannot be
    /// resolved later.
    ///
    /// - Parameter records: Raw terminal output records to persist.
    /// - Throws: Filesystem or encoding errors.
    public func write(_ records: [ChatRawTerminalOutputRecord]) throws {
        guard !records.isEmpty else { return }
        try fileManager.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
        for record in records {
            guard let rawOutputRef = record.metadata.rawOutputRef,
                  let url = fileURL(rawOutputRef: rawOutputRef) else { continue }
            let data = try encoder.encode(record)
            try data.write(to: url, options: [.atomic])
        }
    }

    /// Reads a raw terminal output record by local reference.
    ///
    /// - Parameter rawOutputRef: Local raw-output reference from terminal metadata.
    /// - Returns: The stored record, or `nil` when no record exists for the reference.
    /// - Throws: Filesystem or decoding errors.
    public func read(rawOutputRef: String) throws -> ChatRawTerminalOutputRecord? {
        guard let url = fileURL(rawOutputRef: rawOutputRef),
              fileManager.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        return try decoder.decode(ChatRawTerminalOutputRecord.self, from: data)
    }

    /// Removes cached raw-output records older than a cutoff date.
    ///
    /// - Parameter cutoff: Modification-date cutoff; records older than this
    ///   value are removed.
    /// - Returns: Number of cached record files removed.
    /// - Throws: Filesystem errors encountered while enumerating or deleting.
    public func pruneRecords(olderThan cutoff: Date) throws -> Int {
        try Self.pruneRecords(
            in: rootDirectory,
            fileManager: fileManager,
            olderThan: cutoff
        )
    }

    /// Removes cached raw-output records in a directory older than a cutoff date.
    ///
    /// - Parameters:
    ///   - rootDirectory: Directory containing raw-output record JSON files.
    ///   - fileManager: File manager used for filesystem access.
    ///   - cutoff: Modification-date cutoff; records older than this value are removed.
    /// - Returns: Number of cached record files removed.
    /// - Throws: Filesystem errors encountered while enumerating or deleting.
    public static func pruneRecords(
        in rootDirectory: URL,
        fileManager: FileManager = .default,
        olderThan cutoff: Date
    ) throws -> Int {
        guard fileManager.fileExists(atPath: rootDirectory.path) else {
            return 0
        }

        let resourceKeys: [URLResourceKey] = [
            .contentModificationDateKey,
            .isRegularFileKey,
        ]
        let urls = try fileManager.contentsOfDirectory(
            at: rootDirectory,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles]
        )

        var removed = 0
        for url in urls where url.pathExtension == "json" {
            let values = try url.resourceValues(forKeys: Set(resourceKeys))
            guard values.isRegularFile == true,
                  let modified = values.contentModificationDate,
                  modified < cutoff else {
                continue
            }
            try fileManager.removeItem(at: url)
            removed += 1
        }
        return removed
    }

    private func fileURL(rawOutputRef: String) -> URL? {
        guard !rawOutputRef.isEmpty else { return nil }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        let fileName = rawOutputRef.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? String(scalar) : "_"
        }.joined()
        guard !fileName.isEmpty else { return nil }
        return rootDirectory.appendingPathComponent(fileName).appendingPathExtension("json")
    }
}
