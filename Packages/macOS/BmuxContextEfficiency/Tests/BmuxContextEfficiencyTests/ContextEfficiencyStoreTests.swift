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

        #expect(result.lineCount == 8)
        #expect(result.rolloutEventCount == 8)
        #expect(result.modelCallCount == 1)
        #expect(result.duplicateTokenTelemetryCount == 1)
        #expect(result.parserErrorCount == 1)
        #expect(result.toolCallCount == 1)
        #expect(result.toolOutputCount == 1)
        #expect(result.compactionCount == 1)
        #expect(result.cursor.lineNumber == 8)

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
        #expect(inspection.commandExecutions.count == 1)
        #expect(inspection.commandExecutions.first?.normalizedExecutable == "swift")
        #expect(inspection.commandExecutions.first?.category == .validationRuns)
        #expect(inspection.commandExecutions.first?.outputAttributionConfidence == .exactToolCallLink)
        #expect(inspection.commandCategoryCounts == [
            ContextEfficiencyCommandCategoryCount(category: .validationRuns, commandCount: 1),
        ])
        #expect(inspection.workItemReferences.map(\.reference).contains("github:manaflow-ai/bmux#4536"))
        #expect(inspection.workItemReferences.map(\.reference).contains("ticket:STE-1964"))
        #expect(inspection.workItemReferences.map(\.reference).contains("branch:context-efficiency-wip-20260715"))
        #expect(inspection.workItemReferences.map(\.reference).contains("github-repo:manaflow-ai/bmux"))
        #expect(inspection.parserErrors.count == 1)

        let encodedInspection = try #require(String(data: try JSONEncoder().encode(inspection), encoding: .utf8))
        #expect(!encodedInspection.contains("Original token count: 1800"))
        #expect(!encodedInspection.contains("Raw output: bmux"))
        #expect(!encodedInspection.contains("Continue STE-1964 on"))

        let summary = try await store.summarizeDay("2026-07-13")
        #expect(summary.threadCount == 1)
        #expect(summary.modelCallCount == 1)
        #expect(summary.totalTokens == 120_800)
        #expect(summary.cachedInputTokens == 100_000)
        #expect(summary.outputTokens == 800)
        #expect(summary.parserErrorCount == 1)
        #expect(summary.commandCategoryCounts == [
            ContextEfficiencyCommandCategoryCount(category: .validationRuns, commandCount: 1),
        ])

        let secondImport = try await store.importRollout(at: rolloutURL, fallbackThreadID: "thread-a")
        #expect(secondImport.lineCount == 0)
        #expect(secondImport.modelCallCount == 0)
        #expect(secondImport.cursor.lineNumber == 8)
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
        #expect(result.cursor.lineNumber == 9)

        let inspection = try await store.inspectThread("codex:thread-a")
        #expect(inspection.modelCalls.count == 2)
        #expect(inspection.thread?.cumulativeTotalTokens == 121_500)
        #expect(inspection.commandExecutions.first?.attributedModelCall?.modelCallID == inspection.modelCalls[1].id)
        #expect(inspection.commandExecutions.first?.attributedModelCall?.confidence == .temporalCandidate)
    }

    @Test
    func reportsCommandCategoryCountsForThreadAndDay() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let databaseURL = directory.appendingPathComponent("context-efficiency.sqlite")
        let rolloutURL = directory.appendingPathComponent("rollout-command-counts.jsonl")
        try Data(commandCategoryCountRollout.utf8).write(to: rolloutURL)

        let store = try ContextEfficiencyStore(databaseURL: databaseURL)
        _ = try await store.importRollout(at: rolloutURL, fallbackThreadID: "thread-counts")

        let inspection = try await store.inspectThread("codex:thread-counts")
        #expect(inspection.commandExecutions.count == 4)
        #expect(inspection.commandCategoryCounts == [
            ContextEfficiencyCommandCategoryCount(category: .fileReading, commandCount: 1),
            ContextEfficiencyCommandCategoryCount(category: .sourceSearch, commandCount: 1),
            ContextEfficiencyCommandCategoryCount(category: .validationRuns, commandCount: 2),
        ])

        let firstDaySummary = try await store.summarizeDay("2026-07-13")
        #expect(firstDaySummary.commandCategoryCounts == [
            ContextEfficiencyCommandCategoryCount(category: .sourceSearch, commandCount: 1),
            ContextEfficiencyCommandCategoryCount(category: .validationRuns, commandCount: 2),
        ])

        let secondDaySummary = try await store.summarizeDay("2026-07-14")
        #expect(secondDaySummary.commandCategoryCounts == [
            ContextEfficiencyCommandCategoryCount(category: .fileReading, commandCount: 1),
        ])

        let emptyDaySummary = try await store.summarizeDay("2026-07-15")
        #expect(emptyDaySummary.commandCategoryCounts.isEmpty)
    }

    @Test
    func reportsRepeatedCommandFactsForThread() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let databaseURL = directory.appendingPathComponent("context-efficiency.sqlite")
        let rolloutURL = directory.appendingPathComponent("rollout-repeated-commands.jsonl")
        try Data(repeatedCommandRollout.utf8).write(to: rolloutURL)

        let store = try ContextEfficiencyStore(databaseURL: databaseURL)
        _ = try await store.importRollout(at: rolloutURL, fallbackThreadID: "thread-repeats")

        let inspection = try await store.inspectThread("codex:thread-repeats")
        #expect(inspection.commandExecutions.count == 6)
        #expect(inspection.repeatedCommandFacts.count == 3)

        let repeatedSearch = try #require(inspection.repeatedCommandFacts.first { $0.kind == .sourceSearch })
        #expect(repeatedSearch.category == .sourceSearch)
        #expect(repeatedSearch.normalizedExecutable == "rg")
        #expect(repeatedSearch.representativeCommandSummary == "rg ContextEfficiencyRepeatedCommandDetector Packages/macOS/BmuxContextEfficiency")
        #expect(repeatedSearch.normalizedCommandFingerprint.hasPrefix("fnv1a64:"))
        #expect(repeatedSearch.occurrenceCount == 2)
        #expect(repeatedSearch.sampleCommandExecutionIDs.count == 2)
        #expect(repeatedSearch.firstSourceReference.lineNumber == 2)
        #expect(repeatedSearch.lastSourceReference.lineNumber == 4)

        let repeatedRead = try #require(inspection.repeatedCommandFacts.first { $0.kind == .fileReading })
        #expect(repeatedRead.category == .fileReading)
        #expect(repeatedRead.normalizedExecutable == "cat")
        #expect(repeatedRead.representativeCommandSummary == "cat docs/context-efficiency/current-status.md")
        #expect(repeatedRead.occurrenceCount == 2)
        #expect(repeatedRead.firstSourceReference.lineNumber == 6)
        #expect(repeatedRead.lastSourceReference.lineNumber == 8)

        let repeatedValidation = try #require(inspection.repeatedCommandFacts.first { $0.kind == .command })
        #expect(repeatedValidation.category == .validationRuns)
        #expect(repeatedValidation.normalizedExecutable == "swift")
        #expect(repeatedValidation.representativeCommandSummary == "swift test --package-path Packages/macOS/BmuxContextEfficiency")
        #expect(repeatedValidation.occurrenceCount == 2)
        #expect(repeatedValidation.firstSourceReference.lineNumber == 10)
        #expect(repeatedValidation.lastSourceReference.lineNumber == 12)
    }

    @Test
    func repeatedCommandFactsKeepBoundedExecutionIDSamples() {
        let commands = (1...25).map { index in
            ContextEfficiencyCommandExecutionRecord(
                id: "command-\(index)",
                threadID: "codex:thread-repeats",
                callID: "call-\(index)",
                toolName: "exec_command",
                commandSummary: "rg repeated Packages/macOS/BmuxContextEfficiency",
                normalizedExecutable: "rg",
                category: .sourceSearch,
                argumentsByteCount: 64,
                outputByteCount: nil,
                estimatedOriginalOutputTokens: nil,
                rawOutputReferenceCount: 0,
                startedAt: nil,
                completedAt: nil,
                elapsedSeconds: nil,
                toolCallSourceReference: ContextEfficiencySourceReference(
                    sourcePath: "/tmp/rollout-repeated-commands.jsonl",
                    byteOffset: Int64(index * 100),
                    lineNumber: index,
                    parserVersion: CodexRolloutTelemetryParser.parserVersion
                ),
                toolOutputSourceReference: nil,
                outputAttributionConfidence: .unmatched,
                attributedModelCall: nil
            )
        }

        let fact = ContextEfficiencyRepeatedCommandDetector().facts(for: commands).first

        #expect(fact?.occurrenceCount == 25)
        #expect(fact?.sampleCommandExecutionIDs.count == 20)
        #expect(fact?.sampleCommandExecutionIDs.first == "command-1")
        #expect(fact?.sampleCommandExecutionIDs.last == "command-20")
        #expect(fact?.lastSourceReference.lineNumber == 25)
    }

    @Test
    func replacesPreviouslyImportedSourceRowsWhenRolloutFileShrinks() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let databaseURL = directory.appendingPathComponent("context-efficiency.sqlite")
        let rolloutURL = directory.appendingPathComponent("rollout-thread-a.jsonl")
        try Data(initialRollout.utf8).write(to: rolloutURL)

        let store = try ContextEfficiencyStore(databaseURL: databaseURL)
        _ = try await store.importRollout(at: rolloutURL, fallbackThreadID: "thread-a")

        try FileManager.default.removeItem(at: rolloutURL)
        try Data(replacementRollout.utf8).write(to: rolloutURL)

        let result = try await store.importRollout(at: rolloutURL, fallbackThreadID: "thread-b")
        #expect(result.resetCursor)
        #expect(result.lineCount == 1)
        #expect(result.modelCallCount == 1)
        #expect(result.cursor.lineNumber == 1)

        let staleInspection = try await store.inspectThread("codex:thread-a")
        #expect(staleInspection.thread == nil)
        #expect(staleInspection.modelCalls.isEmpty)
        #expect(staleInspection.tokenTelemetryEvents.isEmpty)
        #expect(staleInspection.parserErrors.isEmpty)

        let replacementInspection = try await store.inspectThread("codex:thread-b")
        #expect(replacementInspection.thread?.cumulativeTotalTokens == 42)
        #expect(replacementInspection.modelCalls.count == 1)

        let staleDaySummary = try await store.summarizeDay("2026-07-13")
        #expect(staleDaySummary.threadCount == 0)
        #expect(staleDaySummary.modelCallCount == 0)
        #expect(staleDaySummary.parserErrorCount == 0)

        let replacementDaySummary = try await store.summarizeDay("2026-07-15")
        #expect(replacementDaySummary.threadCount == 1)
        #expect(replacementDaySummary.modelCallCount == 1)
        #expect(replacementDaySummary.totalTokens == 42)
    }

    @Test
    func recordsInvalidUTF8LinesAsParserErrorsAndContinuesImporting() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let databaseURL = directory.appendingPathComponent("context-efficiency.sqlite")
        let rolloutURL = directory.appendingPathComponent("rollout-thread-a.jsonl")
        var rolloutData = Data()
        rolloutData.append(Data(utf8BeforeInvalidLine.utf8))
        rolloutData.append(contentsOf: [0xff, 0xfe, 0x0a])
        rolloutData.append(Data(utf8AfterInvalidLine.utf8))
        try rolloutData.write(to: rolloutURL)

        let store = try ContextEfficiencyStore(databaseURL: databaseURL)
        let result = try await store.importRollout(at: rolloutURL, fallbackThreadID: "thread-a")

        #expect(result.lineCount == 3)
        #expect(result.rolloutEventCount == 3)
        #expect(result.modelCallCount == 2)
        #expect(result.parserErrorCount == 1)
        #expect(result.cursor.lineNumber == 3)

        let inspection = try await store.inspectThread("codex:thread-a")
        #expect(inspection.modelCalls.count == 2)
        #expect(inspection.parserErrors.count == 1)
        #expect(inspection.parserErrors.first?.message == "line is not UTF-8")
        #expect(inspection.parserErrors.first?.sourceReference.lineNumber == 2)
    }

    @Test
    func importsMissingTimestampTelemetryWithBoundedParserDiagnostic() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let databaseURL = directory.appendingPathComponent("context-efficiency.sqlite")
        let rolloutURL = directory.appendingPathComponent("rollout-thread-a.jsonl")
        try Data(missingTimestampRollout.utf8).write(to: rolloutURL)

        let store = try ContextEfficiencyStore(databaseURL: databaseURL)
        let result = try await store.importRollout(at: rolloutURL, fallbackThreadID: "thread-a")

        #expect(result.lineCount == 1)
        #expect(result.modelCallCount == 1)
        #expect(result.parserErrorCount == 1)

        let inspection = try await store.inspectThread("codex:thread-a")
        #expect(inspection.tokenTelemetryEvents.count == 1)
        #expect(inspection.tokenTelemetryEvents.first?.timestamp == nil)
        #expect(inspection.modelCalls.count == 1)
        #expect(inspection.modelCalls.first?.timestamp == nil)
        #expect(inspection.parserErrors.count == 1)
        #expect(inspection.parserErrors.first?.message == "missing rollout event timestamp")
        #expect(inspection.parserErrors.first?.sourceReference.lineNumber == 1)
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
            "commandExecutions",
            "commandCategoryCounts",
            "repeatedCommandFacts",
            "workItemReferences",
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

        let commandExecutions = try #require(inspectionPayload["commandExecutions"] as? [[String: Any]])
        let commandExecution = try #require(commandExecutions.first)
        #expect(commandExecution["normalizedExecutable"] as? String == "swift")
        #expect(commandExecution["category"] as? String == "tests")
        #expect(commandExecution["outputAttributionConfidence"] as? String == "exact_tool_call_link")
        #expect(commandExecution["rawOutputReferenceCount"] as? Int == 1)
        #expect(commandExecution["rawOutput"] == nil)
        try assertSourceReference(commandExecution["toolCallSourceReference"], sourcePath: rolloutURL.path, lineNumber: 4)
        try assertSourceReference(commandExecution["toolOutputSourceReference"], sourcePath: rolloutURL.path, lineNumber: 5)

        let commandCategoryCounts = try #require(inspectionPayload["commandCategoryCounts"] as? [[String: Any]])
        let commandCategoryCount = try #require(commandCategoryCounts.first)
        #expect(commandCategoryCounts.count == 1)
        #expect(commandCategoryCount["category"] as? String == "tests")
        #expect(commandCategoryCount["commandCount"] as? Int == 1)
        #expect(commandCategoryCount["commandSummary"] == nil)
        #expect(commandCategoryCount["normalizedExecutable"] == nil)
        #expect(commandCategoryCount["toolCallSourceReference"] == nil)
        #expect(commandCategoryCount["toolOutputSourceReference"] == nil)
        #expect(commandCategoryCount["rawOutput"] == nil)
        #expect(commandCategoryCount["output"] == nil)
        #expect(commandCategoryCount["argumentsByteCount"] == nil)

        let repeatedCommandFacts = try #require(inspectionPayload["repeatedCommandFacts"] as? [[String: Any]])
        #expect(repeatedCommandFacts.isEmpty)

        let workItemReferences = try #require(inspectionPayload["workItemReferences"] as? [[String: Any]])
        let pullRequestReference = try #require(workItemReferences.first { $0["reference"] as? String == "github:manaflow-ai/bmux#4536" })
        #expect(pullRequestReference["kind"] as? String == "pull_request")
        #expect(pullRequestReference["repositorySlug"] as? String == "manaflow-ai/bmux")
        #expect(pullRequestReference["number"] as? Int == 4536)
        #expect(pullRequestReference["sourceKind"] as? String == "message")
        #expect(pullRequestReference["confidence"] as? String == "explicit_reference")
        try assertSourceReference(pullRequestReference["sourceReference"], sourcePath: rolloutURL.path, lineNumber: 6)

        let branchReference = try #require(workItemReferences.first { $0["reference"] as? String == "branch:context-efficiency-wip-20260715" })
        #expect(branchReference["kind"] as? String == "branch")
        #expect(branchReference["branchName"] as? String == "context-efficiency-wip-20260715")
        #expect(branchReference["sourceKind"] as? String == "thread_metadata")
        #expect(branchReference["confidence"] as? String == "branch_candidate")
        #expect(branchReference["message"] == nil)
        try assertSourceReference(branchReference["sourceReference"], sourcePath: rolloutURL.path, lineNumber: 1)

        let parserErrors = try #require(inspectionPayload["parserErrors"] as? [[String: Any]])
        let parserError = try #require(parserErrors.first)
        try assertSourceReference(parserError["sourceReference"], sourcePath: rolloutURL.path, lineNumber: 8)

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
            "commandCategoryCounts",
        ])
        #expect(summaryPayload["day"] as? String == "2026-07-13")
        #expect(summaryPayload["threadCount"] as? Int == 1)
        let summaryCommandCategoryCounts = try #require(summaryPayload["commandCategoryCounts"] as? [[String: Any]])
        let summaryCommandCategoryCount = try #require(summaryCommandCategoryCounts.first)
        #expect(summaryCommandCategoryCounts.count == 1)
        #expect(summaryCommandCategoryCount["category"] as? String == "tests")
        #expect(summaryCommandCategoryCount["commandCount"] as? Int == 1)
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
        {"type":"session_meta","timestamp":"2026-07-13T11:59:58Z","payload":{"id":"thread-a","model":"gpt-5","reasoning_effort":"high","cwd":"/repo/bmux","git_branch":"context-efficiency-wip-20260715","git_origin_url":"git@github.com:manaflow-ai/bmux.git"}}
        {"type":"event_msg","timestamp":"2026-07-13T12:00:00Z","payload":{"type":"token_usage","threadID":"thread-a","tokenUsage":{"inputTokens":120000,"cachedInputTokens":100000,"outputTokens":800,"totalTokens":120800}}}
        {"type":"event_msg","timestamp":"2026-07-13T12:00:01Z","payload":{"type":"token_usage","threadID":"thread-a","tokenUsage":{"inputTokens":120000,"cachedInputTokens":100000,"outputTokens":800,"totalTokens":120800}}}
        {"type":"response_item","timestamp":"2026-07-13T12:00:02Z","payload":{"type":"function_call","threadID":"thread-a","call_id":"call-1","name":"shell","arguments":"{\\"cmd\\":\\"swift test --package-path Packages/macOS/BmuxContextEfficiency\\"}"}}
        {"type":"response_item","timestamp":"2026-07-13T12:00:03Z","payload":{"type":"function_call_output","threadID":"thread-a","call_id":"call-1","output":"Original token count: 1800\\nRaw output: bmux agent-token-output show abc\\nok"}}
        {"type":"event_msg","timestamp":"2026-07-13T12:00:03Z","payload":{"type":"user_message","threadID":"thread-a","message":"Continue STE-1964 on https://github.com/manaflow-ai/bmux/pull/4536"}}
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

    private var commandCategoryCountRollout: String {
        """
        {"type":"session_meta","timestamp":"2026-07-13T11:59:58Z","payload":{"id":"thread-counts","model":"gpt-5","reasoning_effort":"high","cwd":"/repo/bmux"}}
        {"type":"response_item","timestamp":"2026-07-13T12:00:02Z","payload":{"type":"function_call","threadID":"thread-counts","call_id":"call-1","name":"shell","arguments":"{\\"cmd\\":\\"swift test --package-path Packages/macOS/BmuxContextEfficiency\\"}"}}
        {"type":"response_item","timestamp":"2026-07-13T12:00:03Z","payload":{"type":"function_call_output","threadID":"thread-counts","call_id":"call-1","output":"ok"}}
        {"type":"response_item","timestamp":"2026-07-13T12:01:02Z","payload":{"type":"function_call","threadID":"thread-counts","call_id":"call-2","name":"shell","arguments":"{\\"cmd\\":\\"rg ContextEfficiencyCommandCategory Packages/macOS/BmuxContextEfficiency\\"}"}}
        {"type":"response_item","timestamp":"2026-07-13T12:01:03Z","payload":{"type":"function_call_output","threadID":"thread-counts","call_id":"call-2","output":"ok"}}
        {"type":"response_item","timestamp":"2026-07-13T12:02:02Z","payload":{"type":"function_call","threadID":"thread-counts","call_id":"call-3","name":"shell","arguments":"{\\"cmd\\":\\"swift test --package-path Packages/macOS/BmuxContextEfficiency --filter Store\\"}"}}
        {"type":"response_item","timestamp":"2026-07-13T12:02:03Z","payload":{"type":"function_call_output","threadID":"thread-counts","call_id":"call-3","output":"ok"}}
        {"type":"response_item","timestamp":"2026-07-14T12:00:02Z","payload":{"type":"function_call","threadID":"thread-counts","call_id":"call-4","name":"shell","arguments":"{\\"cmd\\":\\"cat docs/context-efficiency/current-status.md\\"}"}}
        {"type":"response_item","timestamp":"2026-07-14T12:00:03Z","payload":{"type":"function_call_output","threadID":"thread-counts","call_id":"call-4","output":"ok"}}
        """ + "\n"
    }

    private var repeatedCommandRollout: String {
        """
        {"type":"session_meta","timestamp":"2026-07-13T11:59:58Z","payload":{"id":"thread-repeats","model":"gpt-5","reasoning_effort":"high","cwd":"/repo/bmux"}}
        {"type":"response_item","timestamp":"2026-07-13T12:00:02Z","payload":{"type":"function_call","threadID":"thread-repeats","call_id":"repeat-1","name":"shell","arguments":"{\\"cmd\\":\\"rg ContextEfficiencyRepeatedCommandDetector Packages/macOS/BmuxContextEfficiency\\"}"}}
        {"type":"response_item","timestamp":"2026-07-13T12:00:03Z","payload":{"type":"function_call_output","threadID":"thread-repeats","call_id":"repeat-1","output":"ok"}}
        {"type":"response_item","timestamp":"2026-07-13T12:01:02Z","payload":{"type":"function_call","threadID":"thread-repeats","call_id":"repeat-2","name":"shell","arguments":"{\\"cmd\\":\\"rg ContextEfficiencyRepeatedCommandDetector Packages/macOS/BmuxContextEfficiency\\"}"}}
        {"type":"response_item","timestamp":"2026-07-13T12:01:03Z","payload":{"type":"function_call_output","threadID":"thread-repeats","call_id":"repeat-2","output":"ok"}}
        {"type":"response_item","timestamp":"2026-07-13T12:02:02Z","payload":{"type":"function_call","threadID":"thread-repeats","call_id":"repeat-3","name":"shell","arguments":"{\\"cmd\\":\\"cat docs/context-efficiency/current-status.md\\"}"}}
        {"type":"response_item","timestamp":"2026-07-13T12:02:03Z","payload":{"type":"function_call_output","threadID":"thread-repeats","call_id":"repeat-3","output":"ok"}}
        {"type":"response_item","timestamp":"2026-07-13T12:03:02Z","payload":{"type":"function_call","threadID":"thread-repeats","call_id":"repeat-4","name":"shell","arguments":"{\\"cmd\\":\\"cat docs/context-efficiency/current-status.md\\"}"}}
        {"type":"response_item","timestamp":"2026-07-13T12:03:03Z","payload":{"type":"function_call_output","threadID":"thread-repeats","call_id":"repeat-4","output":"ok"}}
        {"type":"response_item","timestamp":"2026-07-13T12:04:02Z","payload":{"type":"function_call","threadID":"thread-repeats","call_id":"repeat-5","name":"shell","arguments":"{\\"cmd\\":\\"swift test --package-path Packages/macOS/BmuxContextEfficiency\\"}"}}
        {"type":"response_item","timestamp":"2026-07-13T12:04:03Z","payload":{"type":"function_call_output","threadID":"thread-repeats","call_id":"repeat-5","output":"ok"}}
        {"type":"response_item","timestamp":"2026-07-13T12:05:02Z","payload":{"type":"function_call","threadID":"thread-repeats","call_id":"repeat-6","name":"shell","arguments":"{\\"cmd\\":\\"swift test --package-path Packages/macOS/BmuxContextEfficiency\\"}"}}
        {"type":"response_item","timestamp":"2026-07-13T12:05:03Z","payload":{"type":"function_call_output","threadID":"thread-repeats","call_id":"repeat-6","output":"ok"}}
        """ + "\n"
    }

    private var appendedTelemetry: String {
        """
        {"type":"event_msg","timestamp":"2026-07-13T12:01:00Z","payload":{"type":"token_usage","threadID":"thread-a","tokenUsage":{"inputTokens":120500,"cachedInputTokens":100500,"outputTokens":1000,"totalTokens":121500}}}
        """ + "\n"
    }

    private var replacementRollout: String {
        """
        {"type":"event_msg","timestamp":"2026-07-15T12:00:00Z","payload":{"type":"token_usage","threadID":"thread-b","tokenUsage":{"inputTokens":40,"cachedInputTokens":30,"outputTokens":2,"totalTokens":42}}}
        """ + "\n"
    }

    private var missingTimestampRollout: String {
        """
        {"type":"event_msg","payload":{"type":"token_usage","threadID":"thread-a","tokenUsage":{"inputTokens":42,"totalTokens":42}}}
        """ + "\n"
    }

    private var utf8BeforeInvalidLine: String {
        """
        {"type":"event_msg","timestamp":"2026-07-13T12:00:00Z","payload":{"type":"token_usage","threadID":"thread-a","tokenUsage":{"inputTokens":120000,"cachedInputTokens":100000,"outputTokens":800,"totalTokens":120800}}}
        """ + "\n"
    }

    private var utf8AfterInvalidLine: String {
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
