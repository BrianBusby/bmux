import Foundation

@main
struct CodexTranscriptSnapshotExperimentTests {
    static func main() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("bmux-snapshot-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let path = root.appendingPathComponent("source.jsonl")
        let meta = #"{"type":"session_meta","payload":{"id":"session-a"}}"# + "\n"
        let event = #"{"type":"event_msg","payload":{"type":"task_started","turn_id":"turn-a"}}"# + "\n"
        func write(_ text: String) throws { try Data(text.utf8).write(to: path) }
        func unknown(_ value: CodexTranscriptSnapshotResult, _ label: String) {
            guard case .unknown = value else { fatalError("expected unknown: \(label)") }
        }
        try write(meta + event)
        guard case let .verified(snapshot) = CodexTranscriptSnapshot.capture(path: path, expectedSessionID: "session-a") else {
            fatalError("matching session should be verified")
        }
        precondition(snapshot.lines.count == 2 && snapshot.lines[1] == event.trimmingCharacters(in: .newlines))
        unknown(CodexTranscriptSnapshot.capture(path: path, expectedSessionID: "session-b"), "mismatch")
        try write(event)
        unknown(CodexTranscriptSnapshot.capture(path: path, expectedSessionID: "session-a"), "missing metadata")
        try write(meta + #"{"type":"session_meta","payload":{"id":"session-b"}}"# + "\n" + event)
        unknown(CodexTranscriptSnapshot.capture(path: path, expectedSessionID: "session-a"), "conflicting metadata")
        try write(#"{"type":"session_meta","payload":{"id":"session-a","session_id":"session-b"}}"# + "\n")
        unknown(CodexTranscriptSnapshot.capture(path: path, expectedSessionID: "session-a"), "conflicting metadata fields")
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
            let replacement = root.appendingPathComponent("replacement.jsonl")
            try Data((meta + event).utf8).write(to: replacement)
            try FileManager.default.removeItem(at: path)
            try FileManager.default.moveItem(at: replacement, to: path)
            return data
        }), "replacement during capture")
        try Data(repeating: 0x20, count: CodexTranscriptSnapshot.maxBytes + 1).write(to: path)
        unknown(CodexTranscriptSnapshot.capture(path: path, expectedSessionID: "session-a"), "oversize")
        print("snapshot experiment: 11 cases passed")
    }
}
