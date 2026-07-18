import Foundation
import Testing

@testable import BmuxContextEfficiency

@Suite
struct CodexRolloutJSONLStreamReaderTests {
    @Test
    func leavesPartialTrailingLineForNextImport() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let rolloutURL = directory.appendingPathComponent("rollout-thread-a.jsonl")
        try Data("first\npartial".utf8).write(to: rolloutURL)

        let reader = CodexRolloutJSONLStreamReader(chunkSize: 3)
        var lines: [CodexRolloutImportedLine] = []
        let result = try reader.readLines(
            from: rolloutURL,
            sourcePath: rolloutURL.path,
            startingByteOffset: 0,
            startingLineNumber: 0
        ) { line in
            lines.append(line)
        }

        #expect(lines.map(\.text) == ["first"])
        #expect(result.lineCount == 1)
        #expect(result.nextByteOffset == 6)
        #expect(result.nextLineNumber == 1)
        #expect(result.pendingByteCount == 7)
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("bmux-context-efficiency-tests")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
