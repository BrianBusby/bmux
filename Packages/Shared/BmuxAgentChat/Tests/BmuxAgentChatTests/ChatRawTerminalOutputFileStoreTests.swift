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
}
