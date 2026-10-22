import Foundation

/// A small, synchronous close record that survives termination before PE's
/// asynchronous archive enrichment completes. One file per logical workspace
/// avoids rewriting the unbounded recently-closed restore history on close.
actor WorkspaceExplorerCloseJournal {
    private struct Record: Codable {
        static let currentVersion = 1

        let version: Int
        let stableID: UUID
        let title: String
        let closedAt: Date
        let colorHex: String?

        var candidate: WorkspaceArchiveRecoveryCandidate {
            WorkspaceArchiveRecoveryCandidate(
                stableID: stableID, title: title, closedAt: closedAt, colorHex: colorHex
            )
        }
    }

    private nonisolated let directoryURL: URL
    private nonisolated let fileLock = NSLock()

    init(databaseURL: URL) {
        directoryURL = databaseURL.deletingLastPathComponent()
            .appendingPathComponent("explorer-close-journal", isDirectory: true)
    }

    /// The close producer must finish this small atomic write before returning.
    nonisolated func record(_ candidate: WorkspaceArchiveRecoveryCandidate) throws {
        try fileLock.withLock {
            try FileManager.default.createDirectory(
                at: directoryURL, withIntermediateDirectories: true
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

    func candidates() throws -> [WorkspaceArchiveRecoveryCandidate] {
        var candidates: [WorkspaceArchiveRecoveryCandidate] = []
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

    /// PE's clear marker guards older records. Remove matching journal files
    /// after PE accepts the clear, while keeping any close made during it.
    func clear(through timestamp: Date) throws {
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

    private nonisolated static func isMissingFile(_ error: Error) -> Bool {
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
