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
