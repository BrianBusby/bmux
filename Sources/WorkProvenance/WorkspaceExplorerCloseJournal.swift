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
        try fileLock.withLock {
            try recordURLs().map { url in
                try readRecord(at: url).candidate
            }
        }
    }

    /// PE's clear marker guards older records. Remove matching journal files
    /// after PE accepts the clear, while keeping any close made during it.
    func clear(through timestamp: Date) throws {
        try fileLock.withLock {
            for url in try recordURLs() {
                // A damaged record cannot be replayed; Clear must still remove it.
                if (try? readRecord(at: url).closedAt).map({ $0 <= timestamp }) ?? true {
                    try FileManager.default.removeItem(at: url)
                }
            }
        }
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
