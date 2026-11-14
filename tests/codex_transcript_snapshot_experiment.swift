import Foundation

@main
struct CodexTranscriptSnapshotExperimentTests {
    static func main() throws {
        if CommandLine.arguments.count == 2 || CommandLine.arguments.count == 3 {
            let result = CodexTranscriptSnapshot.capture(
                path: URL(fileURLWithPath: CommandLine.arguments[1]), expectedSessionID: "session-a"
            )
            if CommandLine.arguments.count == 3 && CommandLine.arguments[2] == "verified" {
                guard case .verified = result else { exit(1) }
            } else {
                guard case .unknown = result else { exit(1) }
            }
            return
        }
        testIncrementalFraming()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("bmux-snapshot-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let path = root.appendingPathComponent("source.jsonl")
        let meta = #"{"type":"session_meta","payload":{"id":"session-a"}}"# + "\n"
        let event = #"{"type":"event_msg","payload":{"type":"task_started","turn_id":"turn-a"}}"# + "\n"
        func write(_ text: String) throws { try Data(text.utf8).write(to: path) }
        func unknown(_ value: CodexTranscriptSnapshotResult, _ label: String) {
            guard case .unknown = value else { print("expected unknown: \(label)"); exit(1) }
        }
        try write(meta + event)
        guard case let .verified(snapshot) = CodexTranscriptSnapshot.capture(path: path, expectedSessionID: "session-a") else {
            fatalError("matching session should be verified")
        }
        precondition(snapshot.lines.count == 2 && snapshot.lines[1] == event.trimmingCharacters(in: .newlines))
        try write(meta + #"{"type":"event_msg","payload":{"text":"x,}\"[\\done","nested":[{"key":"value"}]}}"# + "\n")
        guard case .verified = CodexTranscriptSnapshot.capture(path: path, expectedSessionID: "session-a") else {
            fatalError("valid escaped JSON should be verified")
        }
        try write(meta + "{\"type\":\"event_msg\",\"payload\":{\"nested\":" + String(repeating: "[", count: 70) + "0" + String(repeating: "]", count: 70) + "}}\n")
        unknown(CodexTranscriptSnapshot.capture(path: path, expectedSessionID: "session-a"), "excessive nesting")
        try write(meta + event)
        unknown(CodexTranscriptSnapshot.capture(path: path, expectedSessionID: "session-b"), "mismatch")
        try write(event)
        unknown(CodexTranscriptSnapshot.capture(path: path, expectedSessionID: "session-a"), "missing metadata")
        try write(event + meta)
        unknown(CodexTranscriptSnapshot.capture(path: path, expectedSessionID: "session-a"), "late metadata")
        try write(meta + #"{"type":"session_meta","payload":{"id":"session-b"}}"# + "\n" + event)
        unknown(CodexTranscriptSnapshot.capture(path: path, expectedSessionID: "session-a"), "conflicting metadata")
        try write(#"{"type":"session_meta","payload":{"id":"session-a","session_id":"session-b"}}"# + "\n")
        unknown(CodexTranscriptSnapshot.capture(path: path, expectedSessionID: "session-a"), "conflicting metadata fields")
        try write(#"{"type":"session_meta","payload":{"id":"session-a","id":"session-b"}}"# + "\n")
        unknown(CodexTranscriptSnapshot.capture(path: path, expectedSessionID: "session-a"), "duplicate raw identity key")
        try write(#"{"type":"session_meta","payload":{"id":"session-a","\u0069d":"session-b"}}"# + "\n")
        unknown(CodexTranscriptSnapshot.capture(path: path, expectedSessionID: "session-a"), "escaped duplicate identity key")
        try write(meta + #"{"type":"event_msg","payload":{"x":1,"x":2}}"# + "\n")
        unknown(CodexTranscriptSnapshot.capture(path: path, expectedSessionID: "session-a"), "duplicate nested key")
        try write(meta + event.dropLast())
        unknown(CodexTranscriptSnapshot.capture(path: path, expectedSessionID: "session-a"), "partial line")
        try write(meta + "not-json\n")
        unknown(CodexTranscriptSnapshot.capture(path: path, expectedSessionID: "session-a"), "malformed line")
        try write(meta + event)
        unknown(CodexTranscriptSnapshot.capture(path: path, expectedSessionID: "session-a", read: { handle, count in
            let data = try handle.read(upToCount: count) ?? Data()
            return Data(data.dropLast())
        }), "short read")
        try write(meta + event)
        unknown(CodexTranscriptSnapshot.capture(path: path, expectedSessionID: "session-a", read: { handle, count in
            let data = try handle.read(upToCount: count) ?? Data()
            let writer = try FileHandle(forWritingTo: path)
            defer { try? writer.close() }
            try writer.seekToEnd()
            try writer.write(contentsOf: Data(event.utf8))
            return data
        }), "append during capture")
        try write(meta + event)
        unknown(CodexTranscriptSnapshot.capture(path: path, expectedSessionID: "session-a", read: { handle, count in
            let data = try handle.read(upToCount: count) ?? Data()
            let writer = try FileHandle(forWritingTo: path)
            defer { try? writer.close() }
            try writer.truncate(atOffset: 0)
            return data
        }), "truncate during capture")
        try write(meta + event)
        unknown(CodexTranscriptSnapshot.capture(path: path, expectedSessionID: "session-a", read: { handle, count in
            let data = try handle.read(upToCount: count) ?? Data()
            let writer = try FileHandle(forWritingTo: path)
            defer { try? writer.close() }
            try writer.seek(toOffset: 0)
            try writer.write(contentsOf: Data((meta.replacingOccurrences(of: "session-a", with: "session-b") + event).utf8))
            return data
        }), "same-inode rewrite during capture")
        try write(meta + event)
        unknown(CodexTranscriptSnapshot.capture(path: path, expectedSessionID: "session-a", read: { handle, count in
            let data = try handle.read(upToCount: count) ?? Data()
            let replacement = root.appendingPathComponent("replacement.jsonl")
            try Data((meta + event).utf8).write(to: replacement)
            try FileManager.default.removeItem(at: path)
            try FileManager.default.moveItem(at: replacement, to: path)
            return data
        }), "replacement during capture")
        unknown(CodexTranscriptSnapshot.capture(path: path, expectedSessionID: " "), "empty expected session")
        unknown(CodexTranscriptSnapshot.capture(path: path, expectedSessionID: String(repeating: "x", count: 1_025)), "oversize expected session")
        let prefix = meta + #"{"type":"event_msg","payload":{"text":""#
        let suffix = #""}}"# + "\n"
        let padding = CodexTranscriptSnapshot.maxBytes - prefix.utf8.count - suffix.utf8.count
        try write(prefix + String(repeating: "x", count: padding) + suffix)
        guard case let .verified(atLimit) = CodexTranscriptSnapshot.capture(path: path, expectedSessionID: "session-a"),
              atLimit.capturedBytes == CodexTranscriptSnapshot.maxBytes else {
            fatalError("valid source at byte limit should be verified")
        }
        try Data(repeating: 0x20, count: CodexTranscriptSnapshot.maxBytes + 1).write(to: path)
        unknown(CodexTranscriptSnapshot.capture(path: path, expectedSessionID: "session-a"), "oversize")
        print("snapshot experiment: 22 cases passed")
    }

    private static func testIncrementalFraming() {
        var framer = CodexTranscriptLineFramer(maximumLineBytes: 4)
        var lines: [(String, Int)] = []
        func record(_ line: CodexTranscriptLineFramer.Line, _ number: Int) {
            switch line {
            case .bytes(let bytes): lines.append((String(decoding: bytes, as: UTF8.self), number))
            case .oversized: lines.append(("oversized", number))
            }
        }
        framer.append(Data([0x61, 0x0d, 0x0a, 0xc3]), startOffset: 0, onLine: record)
        precondition(framer.fragment == Data([0xc3]) && framer.lastCompletedLineOffset == 3)
        framer.append(Data([0xa9, 0x0a, 0x78, 0x78, 0x78, 0x78, 0x78]), startOffset: 4, onLine: record)
        precondition(framer.discardingOversizedLine && framer.lastCompletedLineOffset == 6)
        framer.append(Data([0x0a, 0x0a, 0x7a, 0x0a]), startOffset: 11, onLine: record)
        precondition(lines.map(\.0) == ["a\r", "é", "oversized", "z"])
        precondition(lines.map(\.1) == [1, 2, 3, 5])
        precondition(framer.fragment.isEmpty && framer.nextLineNumber == 6 && framer.lastCompletedLineOffset == 15)

        var atLimit = CodexTranscriptLineFramer(maximumLineBytes: 4)
        var result: [String] = []
        atLimit.append(Data("xxxx\nyyyyy\n".utf8), startOffset: 0) { line, _ in
            switch line {
            case .bytes(let bytes): result.append(String(decoding: bytes, as: UTF8.self))
            case .oversized: result.append("oversized")
            }
        }
        precondition(result == ["xxxx", "oversized"])
    }
}
