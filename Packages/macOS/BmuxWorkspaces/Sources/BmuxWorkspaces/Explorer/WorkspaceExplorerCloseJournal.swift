public import Foundation

/// Persists a minimal close identity before asynchronous archive enrichment.
///
/// One atomic file per logical workspace avoids rewriting restore history at
/// close. Reads and clear run on this actor; the close write is synchronous so
/// the caller can finish it before returning from workspace removal.
public actor WorkspaceExplorerCloseJournal {
    private struct Record: Codable {
        static let currentVersion = 1

        let version: Int
        let stableID: UUID
        let title: String
        let closedAt: Date
        let colorHex: String?

        var candidate: WorkspaceExplorerCloseRecord {
            WorkspaceExplorerCloseRecord(
                stableID: stableID, title: title, closedAt: closedAt, colorHex: colorHex
            )
        }
    }

    private nonisolated let directoryURL: URL
    private nonisolated let fileLock = NSLock()

    /// Creates a journal beside the supplied Provenance Engine database.
    /// - Parameter databaseURL: Location used to choose the journal directory.
    public init(databaseURL: URL) {
        directoryURL = databaseURL.deletingLastPathComponent()
            .appendingPathComponent("explorer-close-journal", isDirectory: true)
    }

    /// Writes an identity synchronously before the close producer returns.
    /// - Parameter candidate: Latest close identity for one logical workspace.
    /// - Throws: A filesystem or encoding error if the atomic write fails.
    public nonisolated func record(_ candidate: WorkspaceExplorerCloseRecord) throws {
        try fileLock.withLock {
            try FileManager.default.createDirectory(
                at: directoryURL, withIntermediateDirectories: true,
                attributes: [.posixPermissions: NSNumber(value: 0o700)]
            )
            // An older tagged build may have created this directory with a
            // wider mode. Keep titles private even when the parent is 0755.
            try FileManager.default.setAttributes(
                [.posixPermissions: NSNumber(value: 0o700)],
                ofItemAtPath: directoryURL.path
            )
            let destination = url(for: candidate.stableID)
            if let existing = try? readRecord(at: destination),
               existing.closedAt > candidate.closedAt {
                return
            }
            let record = Record(
                version: Record.currentVersion,
                stableID: candidate.stableID, title: candidate.title,
                closedAt: candidate.closedAt, colorHex: candidate.colorHex
            )
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .secondsSince1970
            try encoder.encode(record).write(to: destination, options: .atomic)
        }
    }

    /// Returns all journaled close identities, skipping concurrent deletions.
    /// - Returns: The retained identities in unspecified order.
    /// - Throws: A filesystem or decoding error for any retained but unreadable file.
    public func candidates() throws -> [WorkspaceExplorerCloseRecord] {
        var candidates: [WorkspaceExplorerCloseRecord] = []
        for url in try recordURLs() {
            do {
                try fileLock.withLock {
                    candidates.append(try readRecord(at: url).candidate)
                }
            } catch where Self.isMissingFile(error) {
                // Clear may remove a file after directory enumeration.
                continue
            }
        }
        return candidates
    }

    /// Removes identities cleared by PE while preserving later closes.
    /// - Parameter timestamp: The clear time accepted by PE.
    /// - Throws: A filesystem error if a retained file cannot be removed.
    public func clear(through timestamp: Date) throws {
        for url in try recordURLs() {
            try fileLock.withLock {
                let closedAt: Date?
                do {
                    closedAt = try readRecord(at: url).closedAt
                } catch where Self.isMissingFile(error) {
                    return
                } catch {
                    closedAt = nil
                }
                // A damaged record cannot be replayed; Clear must still remove it.
                if closedAt.map({ $0 <= timestamp }) ?? true {
                    do {
                        try FileManager.default.removeItem(at: url)
                    } catch where Self.isMissingFile(error) {
                        return
                    }
                }
            }
        }
    }

    private nonisolated static func isMissingFile(_ error: any Error) -> Bool {
        let error = error as NSError
        return (error.domain == NSCocoaErrorDomain &&
                (error.code == NSFileNoSuchFileError || error.code == NSFileReadNoSuchFileError)) ||
            (error.domain == NSPOSIXErrorDomain && error.code == POSIXError.ENOENT.rawValue)
    }

    private nonisolated func recordURLs() throws -> [URL] {
        guard FileManager.default.fileExists(atPath: directoryURL.path) else { return [] }
        return try FileManager.default.contentsOfDirectory(
            at: directoryURL, includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "json" }
    }

    private nonisolated func readRecord(at url: URL) throws -> Record {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let record = try decoder.decode(Record.self, from: Data(contentsOf: url))
        guard record.version == Record.currentVersion else {
            throw JournalError.unsupportedVersion(record.version)
        }
        return record
    }

    private nonisolated func url(for stableID: UUID) -> URL {
        directoryURL.appendingPathComponent("\(stableID.uuidString).json")
    }

    private enum JournalError: Error {
        case unsupportedVersion(Int)
    }
}
