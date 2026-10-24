public import Foundation

/// Persists a minimal close identity before asynchronous archive enrichment.
///
/// Each close has its own atomic file, so independent app processes never
/// overwrite one another's record. Reads and clear run on this actor; the close
/// write is synchronous so it completes before workspace removal returns.
public actor WorkspaceExplorerCloseJournal: WorkspaceExplorerCloseJournaling {
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

    private struct ClearMarker: Codable {
        let clearedAt: Date
    }

    private nonisolated let directoryURL: URL
    // FileManager is documented thread-safe; injection keeps filesystem access testable.
    private nonisolated(unsafe) let fileManager: FileManager

    /// Creates a journal beside the supplied Provenance Engine database.
    /// - Parameters:
    ///   - databaseURL: Location used to choose the journal directory.
    ///   - fileManager: Filesystem dependency; tests may supply an isolated instance.
    public init(databaseURL: URL, fileManager: FileManager = .default) {
        directoryURL = databaseURL.deletingLastPathComponent()
            .appendingPathComponent("explorer-close-journal", isDirectory: true)
        self.fileManager = fileManager
    }

    /// Writes an identity synchronously before the close producer returns.
    /// - Parameter candidate: Latest close identity for one logical workspace.
    /// - Throws: A filesystem or encoding error if the atomic write fails.
    public nonisolated func record(_ candidate: WorkspaceExplorerCloseRecord) throws {
        try fileManager.createDirectory(
            at: directoryURL, withIntermediateDirectories: true,
            attributes: [.posixPermissions: NSNumber(value: 0o700)]
        )
        // An older tagged build may have created this directory with a wider
        // mode. Keep titles private even when the parent is 0755.
        try fileManager.setAttributes(
            [.posixPermissions: NSNumber(value: 0o700)],
            ofItemAtPath: directoryURL.path
        )
        let record = Record(
            version: Record.currentVersion,
            stableID: candidate.stableID, title: candidate.title,
            closedAt: candidate.closedAt, colorHex: candidate.colorHex
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        let destination = url(for: candidate.stableID)
        try encoder.encode(record).write(to: destination, options: .atomic)
        // Clear publishes a marker before scanning. A concurrent writer that
        // lands after that scan removes its own older file here.
        if let clearedAt = try latestClearAt(), candidate.closedAt <= clearedAt {
            do {
                try fileManager.removeItem(at: destination)
            } catch where Self.isMissingFile(error) {
                // A concurrent Clear already removed this record.
            }
        }
    }

    /// Returns all journaled close identities, skipping concurrent deletions.
    /// - Returns: The retained identities in unspecified order.
    /// - Throws: A filesystem or decoding error for any retained but unreadable file.
    public func candidates() throws -> [WorkspaceExplorerCloseRecord] {
        var latestByID: [UUID: WorkspaceExplorerCloseRecord] = [:]
        let clearedAt = try latestClearAt()
        for url in try recordURLs() {
            do {
                let candidate = try readRecord(at: url).candidate
                if let clearedAt, candidate.closedAt <= clearedAt {
                    do {
                        try fileManager.removeItem(at: url)
                    } catch where Self.isMissingFile(error) {
                        // The Clear path or writer removed it after enumeration.
                    }
                    continue
                }
                if let previous = latestByID[candidate.stableID],
                   previous.closedAt > candidate.closedAt {
                    continue
                }
                latestByID[candidate.stableID] = candidate
            } catch where Self.isMissingFile(error) {
                // Clear may remove a file after directory enumeration.
                continue
            }
        }
        return Array(latestByID.values)
    }

    /// Removes identities cleared by PE while preserving later closes.
    /// - Parameter timestamp: The clear time accepted by PE.
    /// - Throws: A filesystem error if a retained file cannot be removed.
    public func clear(through timestamp: Date) throws {
        try fileManager.createDirectory(
            at: directoryURL, withIntermediateDirectories: true,
            attributes: [.posixPermissions: NSNumber(value: 0o700)]
        )
        try fileManager.setAttributes(
            [.posixPermissions: NSNumber(value: 0o700)],
            ofItemAtPath: directoryURL.path
        )
        let effectiveTimestamp = max(try latestClearAt() ?? timestamp, timestamp)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        let markerURL = directoryURL.appendingPathComponent("\(UUID().uuidString).clear")
        try encoder.encode(ClearMarker(clearedAt: effectiveTimestamp))
            .write(to: markerURL, options: .atomic)
        try pruneOlderClearMarkers()
        for url in try recordURLs() {
            let closedAt: Date?
            do {
                closedAt = try readRecord(at: url).closedAt
            } catch where Self.isMissingFile(error) {
                continue
            } catch {
                closedAt = nil
            }
            // A damaged record cannot be replayed; Clear must still remove it.
            if closedAt.map({ $0 <= effectiveTimestamp }) ?? true {
                do {
                    try fileManager.removeItem(at: url)
                } catch where Self.isMissingFile(error) {
                    continue
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
        guard fileManager.fileExists(atPath: directoryURL.path) else { return [] }
        return try fileManager.contentsOfDirectory(
            at: directoryURL, includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "json" }
    }

    private nonisolated func latestClearAt() throws -> Date? {
        guard fileManager.fileExists(atPath: directoryURL.path) else { return nil }
        let urls = try fileManager.contentsOfDirectory(
            at: directoryURL, includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "clear" }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        var latest: Date?
        for url in urls {
            do {
                let marker = try decoder.decode(ClearMarker.self, from: Data(contentsOf: url))
                latest = max(latest ?? marker.clearedAt, marker.clearedAt)
            } catch where Self.isMissingFile(error) {
                continue
            }
        }
        return latest
    }

    /// Keep the newest published cutoff. For equal cutoffs, keep the marker
    /// with the smallest filename so retries do not accumulate files. A
    /// concurrent clear can publish a newer marker during this scan; that
    /// marker remains even if this scan never observes it.
    private func pruneOlderClearMarkers() throws {
        let urls = try fileManager.contentsOfDirectory(
            at: directoryURL, includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "clear" }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        var markers: [(url: URL, clearedAt: Date)] = []
        for url in urls {
            do {
                let marker = try decoder.decode(ClearMarker.self, from: Data(contentsOf: url))
                markers.append((url, marker.clearedAt))
            } catch where Self.isMissingFile(error) {
                continue
            }
        }
        guard let newest = markers.map(\.clearedAt).max() else { return }
        let keeper = markers.filter { $0.clearedAt == newest }
            .map(\.url.lastPathComponent).min()
        for marker in markers where marker.clearedAt < newest ||
            (marker.clearedAt == newest && marker.url.lastPathComponent != keeper) {
            do {
                try fileManager.removeItem(at: marker.url)
            } catch where Self.isMissingFile(error) {
                continue
            }
        }
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
        directoryURL.appendingPathComponent("\(stableID.uuidString)-\(UUID().uuidString).json")
    }

    private enum JournalError: Error {
        case unsupportedVersion(Int)
    }
}
