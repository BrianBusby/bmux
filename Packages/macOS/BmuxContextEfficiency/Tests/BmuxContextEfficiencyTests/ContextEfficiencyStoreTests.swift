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

        let encodedInspection = try #require(String(data: try JSONEncoder().encode(inspection), encoding: .utf8))
        #expect(!encodedInspection.contains("Original token count: 1800"))
        #expect(!encodedInspection.contains("Raw output: bmux"))

        let summary = try await store.summarizeDay("2026-07-13")
        #expect(summary.threadCount == 1)
        #expect(summary.modelCallCount == 1)
        #expect(summary.totalTokens == 120_800)
        #expect(summary.cachedInputTokens == 100_000)
        #expect(summary.outputTokens == 800)
        #expect(summary.parserErrorCount == 1)

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

    @Test
    func encodedReportsExposeCompactFactsAndSourceReferences() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let databaseURL = directory.appendingPathComponent("context-efficiency.sqlite")
        let rolloutURL = directory.appendingPathComponent("rollout-thread-a.jsonl")
        try Data(initialRollout.utf8).write(to: rolloutURL)

        let store = try ContextEfficiencyStore(databaseURL: databaseURL)
        _ = try await store.importRollout(at: rolloutURL, fallbackThreadID: "thread-a")

        let inspection = try await store.inspectThread("codex:thread-a")
        let encodedInspection = try encodedJSONString(inspection)
        #expect(!encodedInspection.contains("Original token count:"))
        #expect(!encodedInspection.contains("Raw output: bmux"))

        let inspectionPayload = try jsonObject(from: encodedInspection)
        #expect(Set(inspectionPayload.keys) == [
            "thread",
            "modelCalls",
            "tokenTelemetryEvents",
            "toolCalls",
            "toolOutputs",
            "parserErrors",
        ])

        let modelCalls = try #require(inspectionPayload["modelCalls"] as? [[String: Any]])
        let modelCall = try #require(modelCalls.first)
        let modelCallUsage = try #require(modelCall["tokenUsage"] as? [String: Any])
        #expect(modelCallUsage["totalTokens"] as? Int == 120_800)
        #expect(modelCallUsage["cachedInputTokens"] as? Int == 100_000)
        try assertSourceReference(modelCall["sourceReference"], sourcePath: rolloutURL.path, lineNumber: 2)

        let toolCalls = try #require(inspectionPayload["toolCalls"] as? [[String: Any]])
        let toolCall = try #require(toolCalls.first)
        let commandSummary = toolCall["commandSummary"] as? String
        #expect(commandSummary?.isEmpty == false)
        #expect((toolCall["argumentsByteCount"] as? Int).map { $0 > 0 } == true)
        #expect(toolCall["arguments"] == nil)
        try assertSourceReference(toolCall["sourceReference"], sourcePath: rolloutURL.path, lineNumber: 4)

        let toolOutputs = try #require(inspectionPayload["toolOutputs"] as? [[String: Any]])
        let toolOutput = try #require(toolOutputs.first)
        #expect((toolOutput["outputByteCount"] as? Int).map { $0 > 0 } == true)
        #expect(toolOutput["estimatedOriginalTokens"] as? Int == 1_800)
        #expect(toolOutput["rawOutputReferenceCount"] as? Int == 1)
        #expect(toolOutput["output"] == nil)
        #expect(toolOutput["rawOutput"] == nil)
        try assertSourceReference(toolOutput["sourceReference"], sourcePath: rolloutURL.path, lineNumber: 5)

        let parserErrors = try #require(inspectionPayload["parserErrors"] as? [[String: Any]])
        let parserError = try #require(parserErrors.first)
        try assertSourceReference(parserError["sourceReference"], sourcePath: rolloutURL.path, lineNumber: 7)

        let summary = try await store.summarizeDay("2026-07-13")
        let encodedSummary = try encodedJSONString(summary)
        #expect(!encodedSummary.contains("Original token count:"))
        #expect(!encodedSummary.contains("Raw output: bmux"))

        let summaryPayload = try jsonObject(from: encodedSummary)
        #expect(Set(summaryPayload.keys) == [
            "day",
            "threadCount",
            "modelCallCount",
            "totalTokens",
            "cachedInputTokens",
            "outputTokens",
            "parserErrorCount",
        ])
        #expect(summaryPayload["day"] as? String == "2026-07-13")
        #expect(summaryPayload["threadCount"] as? Int == 1)
        #expect(summaryPayload["modelCallCount"] as? Int == 1)
        #expect(summaryPayload["totalTokens"] as? Int == 120_800)
        #expect(summaryPayload["cachedInputTokens"] as? Int == 100_000)
        #expect(summaryPayload["outputTokens"] as? Int == 800)
        #expect(summaryPayload["parserErrorCount"] as? Int == 1)
    }

    @Test
    func summarizeDayScopesParserErrorsToRolloutSourcesWithEventsInRequestedDay() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let databaseURL = directory.appendingPathComponent("context-efficiency.sqlite")
        let firstRolloutURL = directory.appendingPathComponent("rollout-thread-a.jsonl")
        let secondRolloutURL = directory.appendingPathComponent("rollout-thread-b.jsonl")
        try Data(initialRollout.utf8).write(to: firstRolloutURL)
        try Data(otherDayRollout.utf8).write(to: secondRolloutURL)

        let store = try ContextEfficiencyStore(databaseURL: databaseURL)
        _ = try await store.importRollout(at: firstRolloutURL, fallbackThreadID: "thread-a")
        _ = try await store.importRollout(at: secondRolloutURL, fallbackThreadID: "thread-b")

        let firstDaySummary = try await store.summarizeDay("2026-07-13")
        #expect(firstDaySummary.threadCount == 1)
        #expect(firstDaySummary.modelCallCount == 1)
        #expect(firstDaySummary.parserErrorCount == 1)

        let secondDaySummary = try await store.summarizeDay("2026-07-14")
        #expect(secondDaySummary.threadCount == 1)
        #expect(secondDaySummary.modelCallCount == 1)
        #expect(secondDaySummary.parserErrorCount == 1)

        let emptyDaySummary = try await store.summarizeDay("2026-07-15")
        #expect(emptyDaySummary.threadCount == 0)
        #expect(emptyDaySummary.modelCallCount == 0)
        #expect(emptyDaySummary.parserErrorCount == 0)
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

    private var otherDayRollout: String {
        """
        {"type":"session_meta","timestamp":"2026-07-14T11:59:58Z","payload":{"id":"thread-b","model":"gpt-5","reasoning_effort":"high","cwd":"/repo/bmux"}}
        {"type":"event_msg","timestamp":"2026-07-14T12:00:00Z","payload":{"type":"token_usage","threadID":"thread-b","tokenUsage":{"inputTokens":220000,"cachedInputTokens":200000,"outputTokens":1800,"totalTokens":221800}}}
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

    private func encodedJSONString<Value: Encodable>(_ value: Value) throws -> String {
        let data = try JSONEncoder().encode(value)
        return try #require(String(data: data, encoding: .utf8))
    }

    private func jsonObject(from string: String) throws -> [String: Any] {
        let data = try #require(string.data(using: .utf8))
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func assertSourceReference(
        _ value: Any?,
        sourcePath: String,
        lineNumber: Int
    ) throws {
        let sourceReference = try #require(value as? [String: Any])
        #expect(sourceReference["sourcePath"] as? String == sourcePath)
        #expect((sourceReference["byteOffset"] as? Int).map { $0 >= 0 } == true)
        #expect(sourceReference["lineNumber"] as? Int == lineNumber)
        #expect((sourceReference["parserVersion"] as? Int).map { $0 > 0 } == true)
    }
}
