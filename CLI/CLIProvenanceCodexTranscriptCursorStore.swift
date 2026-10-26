import CryptoKit
import Foundation

/// Private operational cursor files; PE continues to own all durable evidence.
actor CLIProvenanceCodexTranscriptCursorStore {
    private let directoryURL: URL
    private var lastCleanupAt: Date = .distantPast
    private let retentionSeconds: TimeInterval = 30 * 24 * 3_600

    init(directoryURL: URL) {
        self.directoryURL = directoryURL
    }

    func load(providerSessionID: String, now: Date = Date()) throws
        -> CLIProvenanceCodexTranscriptCursor? {
        let url = cursorURL(for: providerSessionID)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let data = try handle.read(upToCount: CLIProvenanceCodexTranscriptCursor.maxEncodedBytes + 1) ?? Data()
        guard data.count <= CLIProvenanceCodexTranscriptCursor.maxEncodedBytes,
              let cursor = try? JSONDecoder().decode(CLIProvenanceCodexTranscriptCursor.self, from: data),
              cursor.formatVersion == CLIProvenanceCodexTranscriptCursor.version,
              (0...retentionSeconds).contains(now.timeIntervalSince(cursor.updatedAt)) else {
            try? FileManager.default.removeItem(at: url)
            return nil
        }
        return cursor
    }

    func save(_ cursor: CLIProvenanceCodexTranscriptCursor) throws {
        let data = try JSONEncoder().encode(cursor)
        guard data.count <= CLIProvenanceCodexTranscriptCursor.maxEncodedBytes else {
            throw CursorError.metadataTooLarge
        }
        try FileManager.default.createDirectory(
            at: directoryURL, withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directoryURL.path)
        let url = cursorURL(for: cursor.providerSessionID)
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        if cursor.updatedAt.timeIntervalSince(lastCleanupAt) >= 3_600 {
            cleanupStaleFiles(now: cursor.updatedAt)
            lastCleanupAt = cursor.updatedAt
        }
    }

    func loadStatus(providerSessionID: String) throws -> CLIProvenanceCodexTranscriptMonitorStatus? {
        let url = statusURL(for: providerSessionID)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let data = try handle.read(upToCount: CLIProvenanceCodexTranscriptCursor.maxEncodedBytes + 1) ?? Data()
        guard data.count <= CLIProvenanceCodexTranscriptCursor.maxEncodedBytes,
              let status = try? JSONDecoder().decode(CLIProvenanceCodexTranscriptMonitorStatus.self, from: data),
              status.formatVersion == CLIProvenanceCodexTranscriptMonitorStatus.version,
              status.providerSessionID == providerSessionID,
              (0...retentionSeconds).contains(Date().timeIntervalSince(status.updatedAt)) else { return nil }
        return status
    }

    func saveStatus(_ status: CLIProvenanceCodexTranscriptMonitorStatus) throws {
        let data = try JSONEncoder().encode(status)
        guard data.count <= CLIProvenanceCodexTranscriptCursor.maxEncodedBytes else {
            throw CursorError.metadataTooLarge
        }
        try FileManager.default.createDirectory(
            at: directoryURL, withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directoryURL.path)
        let url = statusURL(for: status.providerSessionID)
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        if status.updatedAt.timeIntervalSince(lastCleanupAt) >= 3_600 {
            cleanupStaleFiles(now: status.updatedAt)
            lastCleanupAt = status.updatedAt
        }
    }

    private func cursorURL(for sessionID: String) -> URL {
        directoryURL.appendingPathComponent(sessionDigest(sessionID) + ".json", isDirectory: false)
    }

    private func statusURL(for sessionID: String) -> URL {
        directoryURL.appendingPathComponent(sessionDigest(sessionID) + ".status.json", isDirectory: false)
    }

    private func sessionDigest(_ sessionID: String) -> String {
        let digest = SHA256.hash(data: Data(sessionID.utf8))
            .map { String(format: "%02x", $0) }.joined()
        return digest
    }

    private func cleanupStaleFiles(now: Date) {
        guard let files = FileManager.default.enumerator(
            at: directoryURL, includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
        ) else { return }
        var inspected = 0
        var removed = 0
        for case let url as URL in files {
            guard inspected < 512, removed < 16 else { break }
            inspected += 1
            guard url.pathExtension == "json",
                  let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .contentModificationDateKey]),
                  values.isRegularFile == true,
                  let modified = values.contentModificationDate,
                  now.timeIntervalSince(modified) > retentionSeconds else { continue }
            if (try? FileManager.default.removeItem(at: url)) != nil { removed += 1 }
        }
    }

    private enum CursorError: Error {
        case metadataTooLarge
    }
}
