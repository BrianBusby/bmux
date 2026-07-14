import Foundation
import Testing

@testable import BmuxAgentChat

@Suite("ChatRawTerminalOutputFileStore")
struct ChatRawTerminalOutputFileStoreTests {
    @Test("writes and reads raw terminal output by local reference")
    func writeAndRead() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let metadata = ChatTerminalOutputMetadata(
            kind: .search,
            rawOutputRef: "terminal-output:call_1:abc123",
            rawByteCount: 17,
            rawLineCount: 2,
            optimizedByteCount: 9,
            omittedLineCount: 1,
            wasOptimized: true
        )
        let record = ChatRawTerminalOutputRecord(
            messageID: "call_1",
            command: "rg token Sources",
            rawOutput: "one\ntwo",
            metadata: metadata
        )
        let store = ChatRawTerminalOutputFileStore(rootDirectory: directory)

        try await store.write([record])
        let loaded = try await store.read(rawOutputRef: "terminal-output:call_1:abc123")

        #expect(loaded == record)
    }

    @Test("unknown references read as nil")
    func unknownReference() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ChatRawTerminalOutputFileStore(rootDirectory: directory)

        let loaded = try await store.read(rawOutputRef: "terminal-output:missing:abc123")

        #expect(loaded == nil)
    }

    @Test("prunes raw output records older than the cutoff")
    func pruneExpiredRecords() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let oldRecord = record(rawOutputRef: "old-record", rawOutput: "old\n")
        let recentRecord = record(rawOutputRef: "recent-record", rawOutput: "recent\n")
        let store = ChatRawTerminalOutputFileStore(rootDirectory: directory)
        try await store.write([oldRecord, recentRecord])

        let cutoff = Date()
        try FileManager.default.setAttributes(
            [.modificationDate: cutoff.addingTimeInterval(-60)],
            ofItemAtPath: directory.appendingPathComponent("old-record.json").path
        )
        try FileManager.default.setAttributes(
            [.modificationDate: cutoff.addingTimeInterval(60)],
            ofItemAtPath: directory.appendingPathComponent("recent-record.json").path
        )

        let removed = try await store.pruneRecords(olderThan: cutoff)

        #expect(removed == 1)
        #expect(try await store.read(rawOutputRef: "old-record") == nil)
        #expect(try await store.read(rawOutputRef: "recent-record") == recentRecord)
    }

    @Test("pruning leaves non-record files untouched")
    func pruneLeavesNonRecordFiles() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let markerURL = directory.appendingPathComponent("marker.txt")
        try Data("keep me".utf8).write(to: markerURL)
        let cutoff = Date()
        try FileManager.default.setAttributes(
            [.modificationDate: cutoff.addingTimeInterval(-60)],
            ofItemAtPath: markerURL.path
        )

        let removed = try ChatRawTerminalOutputFileStore.pruneRecords(
            in: directory,
            olderThan: cutoff
        )

        #expect(removed == 0)
        #expect(FileManager.default.fileExists(atPath: markerURL.path))
    }

    private func record(rawOutputRef: String, rawOutput: String) -> ChatRawTerminalOutputRecord {
        let metadata = ChatTerminalOutputMetadata(
            kind: .search,
            rawOutputRef: rawOutputRef,
            rawByteCount: rawOutput.utf8.count,
            rawLineCount: rawOutput.split(separator: "\n", omittingEmptySubsequences: false).count,
            optimizedByteCount: 0,
            omittedLineCount: 0,
            wasOptimized: true
        )
        return ChatRawTerminalOutputRecord(
            messageID: rawOutputRef,
            command: "rg token",
            rawOutput: rawOutput,
            metadata: metadata
        )
    }
}
