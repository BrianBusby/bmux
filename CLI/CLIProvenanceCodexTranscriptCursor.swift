import Foundation

/// Payload-free, versioned acknowledgment of complete Codex JSONL lines.
struct CLIProvenanceCodexTranscriptCursor: Codable, Equatable, Sendable {
    static let version = 1
    static let maxEncodedBytes = 4_096

    let formatVersion: Int
    let providerSessionID: String
    let sourcePath: String
    let fileIdentity: CLIProvenanceCodexTranscriptFileIdentity
    let byteOffset: UInt64
    let lineNumber: Int
    let updatedAt: Date

    init(providerSessionID: String, sourcePath: String,
         fileIdentity: CLIProvenanceCodexTranscriptFileIdentity,
         byteOffset: UInt64, lineNumber: Int, updatedAt: Date) {
        formatVersion = Self.version
        self.providerSessionID = providerSessionID
        self.sourcePath = sourcePath
        self.fileIdentity = fileIdentity
        self.byteOffset = byteOffset
        self.lineNumber = lineNumber
        self.updatedAt = updatedAt
    }

    func matches(sessionID: String, url: URL,
                 fileIdentity: CLIProvenanceCodexTranscriptFileIdentity,
                 fileSize: UInt64) -> Bool {
        formatVersion == Self.version && providerSessionID == sessionID &&
            sourcePath == url.standardizedFileURL.path &&
            self.fileIdentity.matches(fileIdentity) && byteOffset <= fileSize &&
            lineNumber >= 0
    }
}

/// Operational counters only. Transcript text never enters this record.
struct CLIProvenanceCodexTranscriptMonitorStatus: Codable, Sendable {
    static let version = 1
    let formatVersion: Int
    let providerSessionID: String
    var cursorOffset: UInt64
    var readOffset: UInt64
    var unreadBytes: UInt64
    var skippedLines: Int
    var appendFailures: Int
    var retrying: Bool
    var lastErrorKind: String?
    var lastProgressAt: Date?
    var firstBacklogAt: Date?
    var updatedAt: Date

    init(providerSessionID: String) {
        formatVersion = Self.version
        self.providerSessionID = providerSessionID
        cursorOffset = 0
        readOffset = 0
        unreadBytes = 0
        skippedLines = 0
        appendFailures = 0
        retrying = false
        lastErrorKind = nil
        lastProgressAt = nil
        firstBacklogAt = nil
        updatedAt = Date()
    }
}
