import Foundation
import Testing

@testable import BmuxContextEfficiency

@Suite
struct ContextEfficiencyStoreTests {
    @Test
    func importsRolloutIncrementallyAndSuppressesDuplicateTelemetry() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let databaseURL = directory.appendingPathComponent("context-efficiency.sqlite")
        let rolloutURL = directory.appendingPathComponent("rollout-thread-a.jsonl")
        try Data(initialRollout.utf8).write(to: rolloutURL)

        let store = try ContextEfficiencyStore(databaseURL: databaseURL)
        let result = try await store.importRollout(at: rolloutURL, fallbackThreadID: "thread-a")

        #expect(result.lineCount == 7)
        #expect(result.rolloutEventCount == 7)
        #expect(result.modelCallCount == 1)
        #expect(result.duplicateTokenTelemetryCount == 1)
        #expect(result.parserErrorCount == 1)
        #expect(result.toolCallCount == 1)
        #expect(result.toolOutputCount == 1)
        #expect(result.compactionCount == 1)
        #expect(result.cursor.lineNumber == 7)

        let inspection = try await store.inspectThread("codex:thread-a")
        #expect(inspection.thread?.model == "gpt-5")
        #expect(inspection.thread?.reasoningEffort == "high")
        #expect(inspection.thread?.cumulativeTotalTokens == 120_800)
        #expect(inspection.thread?.modelCallCount == 1)
        #expect(inspection.thread?.compactionCount == 1)
        #expect(inspection.modelCalls.count == 1)
        #expect(inspection.tokenTelemetryEvents.count == 1)
        #expect(inspection.toolCalls.first?.commandSummary == "swift test --package-path Packages/macOS/BmuxContextEfficiency")
        #expect(inspection.toolOutputs.first?.estimatedOriginalTokens == 1_800)
        #expect(inspection.toolOutputs.first?.rawOutputReferenceCount == 1)
        #expect(inspection.parserErrors.count == 1)

        let summary = try await store.summarizeDay("2026-07-13")
        #expect(summary.threadCount == 1)
        #expect(summary.modelCallCount == 1)
        #expect(summary.totalTokens == 120_800)
        #expect(summary.cachedInputTokens == 100_000)
        #expect(summary.outputTokens == 800)

        let secondImport = try await store.importRollout(at: rolloutURL, fallbackThreadID: "thread-a")
        #expect(secondImport.lineCount == 0)
        #expect(secondImport.modelCallCount == 0)
        #expect(secondImport.cursor.lineNumber == 7)
    }

    @Test
    func resumesFromCursorWhenNewLinesAreAppended() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let databaseURL = directory.appendingPathComponent("context-efficiency.sqlite")
        let rolloutURL = directory.appendingPathComponent("rollout-thread-a.jsonl")
        try Data(initialRollout.utf8).write(to: rolloutURL)

        let store = try ContextEfficiencyStore(databaseURL: databaseURL)
        _ = try await store.importRollout(at: rolloutURL, fallbackThreadID: "thread-a")

        let handle = try FileHandle(forWritingTo: rolloutURL)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: Data(appendedTelemetry.utf8))

        let result = try await store.importRollout(at: rolloutURL, fallbackThreadID: "thread-a")
        #expect(result.lineCount == 1)
        #expect(result.modelCallCount == 1)
        #expect(result.cursor.lineNumber == 8)

        let inspection = try await store.inspectThread("codex:thread-a")
        #expect(inspection.modelCalls.count == 2)
        #expect(inspection.thread?.cumulativeTotalTokens == 121_500)
    }

    private var initialRollout: String {
        """
        {"type":"session_meta","timestamp":"2026-07-13T11:59:58Z","payload":{"id":"thread-a","model":"gpt-5","reasoning_effort":"high","cwd":"/repo/bmux"}}
        {"type":"event_msg","timestamp":"2026-07-13T12:00:00Z","payload":{"type":"token_usage","threadID":"thread-a","tokenUsage":{"inputTokens":120000,"cachedInputTokens":100000,"outputTokens":800,"totalTokens":120800}}}
        {"type":"event_msg","timestamp":"2026-07-13T12:00:01Z","payload":{"type":"token_usage","threadID":"thread-a","tokenUsage":{"inputTokens":120000,"cachedInputTokens":100000,"outputTokens":800,"totalTokens":120800}}}
        {"type":"response_item","timestamp":"2026-07-13T12:00:02Z","payload":{"type":"function_call","threadID":"thread-a","call_id":"call-1","name":"shell","arguments":"{\\"cmd\\":\\"swift test --package-path Packages/macOS/BmuxContextEfficiency\\"}"}}
        {"type":"response_item","timestamp":"2026-07-13T12:00:03Z","payload":{"type":"function_call_output","threadID":"thread-a","call_id":"call-1","output":"Original token count: 1800\\nRaw output: bmux agent-token-output show abc\\nok"}}
        {"type":"compacted","timestamp":"2026-07-13T12:00:04Z","payload":{"threadID":"thread-a"}}
        {not-json
        """ + "\n"
    }

    private var appendedTelemetry: String {
        """
        {"type":"event_msg","timestamp":"2026-07-13T12:01:00Z","payload":{"type":"token_usage","threadID":"thread-a","tokenUsage":{"inputTokens":120500,"cachedInputTokens":100500,"outputTokens":1000,"totalTokens":121500}}}
        """ + "\n"
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("bmux-context-efficiency-tests")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
