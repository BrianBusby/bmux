import Darwin
import Foundation

/// A bounded in-memory capture, not a source-generation or ownership proof.
struct CodexTranscriptSnapshot {
    static let maxBytes = 4 * 1_024 * 1_024

    let device: UInt64
    let inode: UInt64
    let capturedBytes: Int
    let lines: [String]

    static func capture(
        path: URL,
        expectedSessionID: String,
        read: (FileHandle, Int) throws -> Data = { try $0.read(upToCount: $1) ?? Data() }
    ) -> CodexTranscriptSnapshotResult {
        let expected = expectedSessionID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !expected.isEmpty, expected.utf8.count <= 1_024 else { return .unknown(.invalidSession) }
        let descriptor = path.path.withCString { Darwin.open($0, O_RDONLY | O_NONBLOCK | O_CLOEXEC) }
        guard descriptor >= 0 else { return .unknown(.unavailable) }
        var before = stat()
        guard fstat(descriptor, &before) == 0,
              (before.st_mode & mode_t(S_IFMT)) == mode_t(S_IFREG),
              before.st_size >= 0 else {
            Darwin.close(descriptor)
            return .unknown(.unavailable)
        }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        defer { try? handle.close() }

        do {
            guard before.st_size <= maxBytes else { return .unknown(.oversized) }
            let size = Int(before.st_size)
            try handle.seek(toOffset: 0)
            let data = try read(handle, size)
            guard data.count == size else { return .unknown(.shortRead) }

            var after = stat()
            var currentPath = stat()
            guard fstat(handle.fileDescriptor, &after) == 0,
                  path.path.withCString({ stat($0, &currentPath) }) == 0 else {
                return .unknown(.unavailable)
            }
            guard unchanged(before, after), unchanged(after, currentPath) else {
                return .unknown(.sourceChanged)
            }
            guard !data.isEmpty, data.last == 0x0a else { return .unknown(.partial) }
            guard let text = String(data: data, encoding: .utf8) else { return .unknown(.malformed) }

            var foundMetadata = false
            var lines: [String] = []
            for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
                let text = String(line)
                guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
                let encoded = Data(text.utf8)
                var uniqueness = CodexJSONUniqueKeys(bytes: Array(encoded))
                guard uniqueness.validate() else { return .unknown(.malformed) }
                guard let object = try? JSONSerialization.jsonObject(with: encoded) as? [String: Any],
                      let kind = object["type"] as? String, let payload = object["payload"] as? [String: Any] else {
                    return .unknown(.malformed)
                }
                if kind == "session_meta" {
                    let values = ["session_id", "id"].compactMap { key -> String? in
                        guard let value = payload[key] as? String else { return nil }
                        return value.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    guard !values.isEmpty, values.allSatisfy({ !$0.isEmpty && $0 == expected }),
                          ["session_id", "id"].allSatisfy({ payload[$0] == nil || payload[$0] is String }) else {
                        return .unknown(.unverifiedSession)
                    }
                    foundMetadata = true
                } else if !foundMetadata {
                    return .unknown(.unverifiedSession)
                }
                lines.append(text)
            }
            guard foundMetadata else { return .unknown(.unverifiedSession) }
            return .verified(CodexTranscriptSnapshot(device: UInt64(before.st_dev), inode: UInt64(before.st_ino),
                                                     capturedBytes: size, lines: lines))
        } catch {
            return .unknown(.unavailable)
        }
    }

    private static func unchanged(_ first: stat, _ second: stat) -> Bool {
        first.st_dev == second.st_dev && first.st_ino == second.st_ino && first.st_size == second.st_size &&
            first.st_mtimespec.tv_sec == second.st_mtimespec.tv_sec &&
            first.st_mtimespec.tv_nsec == second.st_mtimespec.tv_nsec &&
            first.st_ctimespec.tv_sec == second.st_ctimespec.tv_sec &&
            first.st_ctimespec.tv_nsec == second.st_ctimespec.tv_nsec
    }
}

enum CodexTranscriptSnapshotUnknown {
    case invalidSession, unavailable, oversized, shortRead, sourceChanged, partial, malformed, unverifiedSession
}

enum CodexTranscriptSnapshotResult {
    case verified(CodexTranscriptSnapshot)
    case unknown(CodexTranscriptSnapshotUnknown)
}

/// Rejects ambiguous keys and excessive nesting before Foundation validates JSON.
private struct CodexJSONUniqueKeys {
    let bytes: [UInt8]
    private var offset = 0
    private let maxDepth = 64

    init(bytes: [UInt8]) { self.bytes = bytes }

    mutating func validate() -> Bool {
        guard value(depth: 0) else { return false }
        skipWhitespace()
        return offset == bytes.count
    }

    private mutating func value(depth: Int) -> Bool {
        guard depth <= maxDepth else { return false }
        skipWhitespace()
        guard offset < bytes.count else { return false }
        switch bytes[offset] {
        case 0x7b: return object(depth: depth + 1)
        case 0x5b: return array(depth: depth + 1)
        case 0x22: return string() != nil
        default:
            let start = offset
            while offset < bytes.count && ![0x2c, 0x5d, 0x7d, 0x20, 0x09, 0x0a, 0x0d].contains(bytes[offset]) {
                offset += 1
            }
            return offset > start
        }
    }

    private mutating func object(depth: Int) -> Bool {
        offset += 1
        skipWhitespace()
        if consume(0x7d) { return true }
        var keys = Set<String>()
        while true {
            guard let key = string(), keys.insert(key).inserted else { return false }
            skipWhitespace()
            guard consume(0x3a), value(depth: depth) else { return false }
            skipWhitespace()
            if consume(0x7d) { return true }
            guard consume(0x2c) else { return false }
            skipWhitespace()
        }
    }

    private mutating func array(depth: Int) -> Bool {
        offset += 1
        skipWhitespace()
        if consume(0x5d) { return true }
        while true {
            guard value(depth: depth) else { return false }
            skipWhitespace()
            if consume(0x5d) { return true }
            guard consume(0x2c) else { return false }
        }
    }

    private mutating func string() -> String? {
        guard offset < bytes.count, bytes[offset] == 0x22 else { return nil }
        let start = offset
        offset += 1
        while offset < bytes.count {
            let byte = bytes[offset]
            offset += 1
            if byte == 0x5c {
                guard offset < bytes.count else { return nil }
                offset += 1
            } else if byte == 0x22 {
                var wrapped = Data([0x5b])
                wrapped.append(contentsOf: bytes[start..<offset])
                wrapped.append(0x5d)
                return (try? JSONSerialization.jsonObject(with: wrapped) as? [String])?.first
            }
        }
        return nil
    }

    private mutating func skipWhitespace() {
        while offset < bytes.count && [0x20, 0x09, 0x0a, 0x0d].contains(bytes[offset]) { offset += 1 }
    }

    private mutating func consume(_ byte: UInt8) -> Bool {
        guard offset < bytes.count, bytes[offset] == byte else { return false }
        offset += 1
        return true
    }
}
