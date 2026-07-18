import Foundation
import Testing

@testable import BmuxContextEfficiency

@Suite
struct CodexRolloutTelemetryParserTests {
    @Test
    func extractsTokenTelemetryFromNestedCamelCaseUsage() throws {
        let parser = CodexRolloutTelemetryParser()
        let line = CodexRolloutImportedLine(
            text: """
            {"type":"event_msg","timestamp":"2026-07-13T12:00:00Z","payload":{"type":"token_usage","threadID":"thread-a","tokenUsage":{"inputTokens":120000,"cachedInputTokens":100000,"outputTokens":800,"totalTokens":120800}}}
            """,
            sourceReference: ContextEfficiencySourceReference(
                sourcePath: "/tmp/rollout-thread-a.jsonl",
                byteOffset: 0,
                lineNumber: 1,
                parserVersion: CodexRolloutTelemetryParser.parserVersion
            )
        )

        let parsed = parser.parse(line: line, fallbackThreadID: "fallback")

        #expect(parsed.kind == .tokenTelemetryObserved)
        #expect(parsed.threadID == "thread-a")
        #expect(parsed.tokenUsage?.inputTokens == 120_000)
        #expect(parsed.tokenUsage?.cachedInputTokens == 100_000)
        #expect(parsed.tokenUsage?.outputTokens == 800)
        #expect(parsed.tokenUsage?.totalTokens == 120_800)
        #expect(parsed.timestamp == ISO8601DateFormatter().date(from: "2026-07-13T12:00:00Z"))
    }

    @Test
    func extractsTokenTelemetryFromOpenAIUsageDetails() throws {
        let parser = CodexRolloutTelemetryParser()
        let line = CodexRolloutImportedLine(
            text: """
            {"type":"event_msg","timestamp":"2026-07-13T12:01:00Z","payload":{"type":"response_completed","thread_id":"thread-a","response":{"usage":{"prompt_tokens":120000,"completion_tokens":800,"total_tokens":120800,"prompt_tokens_details":{"cached_tokens":100000},"completion_tokens_details":{"reasoning_tokens":400}}}}}
            """,
            sourceReference: ContextEfficiencySourceReference(
                sourcePath: "/tmp/rollout-thread-a.jsonl",
                byteOffset: 319,
                lineNumber: 2,
                parserVersion: CodexRolloutTelemetryParser.parserVersion
            )
        )

        let parsed = parser.parse(line: line, fallbackThreadID: "fallback")

        #expect(parsed.kind == .tokenTelemetryObserved)
        #expect(parsed.threadID == "thread-a")
        #expect(parsed.tokenUsage?.inputTokens == 120_000)
        #expect(parsed.tokenUsage?.cachedInputTokens == 100_000)
        #expect(parsed.tokenUsage?.outputTokens == 800)
        #expect(parsed.tokenUsage?.reasoningOutputTokens == 400)
        #expect(parsed.tokenUsage?.totalTokens == 120_800)
    }

    @Test
    func preservesFractionalSecondTimestamps() throws {
        let parser = CodexRolloutTelemetryParser()
        let line = CodexRolloutImportedLine(
            text: """
            {"type":"event_msg","timestamp":"2026-07-13T12:01:00.123Z","payload":{"type":"token_usage","threadID":"thread-a","tokenUsage":{"inputTokens":42}}}
            """,
            sourceReference: ContextEfficiencySourceReference(
                sourcePath: "/tmp/rollout-thread-a.jsonl",
                byteOffset: 620,
                lineNumber: 3,
                parserVersion: CodexRolloutTelemetryParser.parserVersion
            )
        )
        let expectedFormatter = ISO8601DateFormatter()
        expectedFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let parsed = parser.parse(line: line, fallbackThreadID: "fallback")

        #expect(parsed.kind == .tokenTelemetryObserved)
        #expect(parsed.threadID == "thread-a")
        #expect(parsed.tokenUsage?.inputTokens == 42)
        #expect(parsed.timestamp == expectedFormatter.date(from: "2026-07-13T12:01:00.123Z"))
    }

    @Test
    func missingTimestampRecordsDiagnosticWithoutDroppingTelemetryFacts() throws {
        let parser = CodexRolloutTelemetryParser()
        let line = CodexRolloutImportedLine(
            text: """
            {"type":"event_msg","payload":{"type":"token_usage","threadID":"thread-a","tokenUsage":{"inputTokens":42,"totalTokens":42}}}
            """,
            sourceReference: ContextEfficiencySourceReference(
                sourcePath: "/tmp/rollout-thread-a.jsonl",
                byteOffset: 760,
                lineNumber: 4,
                parserVersion: CodexRolloutTelemetryParser.parserVersion
            )
        )

        let parsed = parser.parse(line: line, fallbackThreadID: "fallback")

        #expect(parsed.kind == .tokenTelemetryObserved)
        #expect(parsed.threadID == "thread-a")
        #expect(parsed.timestamp == nil)
        #expect(parsed.tokenUsage?.inputTokens == 42)
        #expect(parsed.parserErrorMessage == "missing rollout event timestamp")
    }

    @Test
    func extractsToolCallAndToolOutputWithoutRetainingRawPayload() throws {
        let parser = CodexRolloutTelemetryParser()
        let toolCallLine = CodexRolloutImportedLine(
            text: """
            {"type":"response_item","payload":{"type":"function_call","call_id":"call-1","name":"shell","arguments":"{\\"cmd\\":\\"swift test --package-path Packages/macOS/BmuxContextEfficiency\\"}"}}
            """,
            sourceReference: ContextEfficiencySourceReference(
                sourcePath: "/tmp/rollout-thread-a.jsonl",
                byteOffset: 0,
                lineNumber: 1,
                parserVersion: CodexRolloutTelemetryParser.parserVersion
            )
        )
        let toolOutputLine = CodexRolloutImportedLine(
            text: """
            {"type":"response_item","payload":{"type":"function_call_output","call_id":"call-1","output":"Original token count: 1800\\nRaw output: bmux agent-token-output show abc\\nok"}}
            """,
            sourceReference: ContextEfficiencySourceReference(
                sourcePath: "/tmp/rollout-thread-a.jsonl",
                byteOffset: 241,
                lineNumber: 2,
                parserVersion: CodexRolloutTelemetryParser.parserVersion
            )
        )

        let parsedCall = parser.parse(line: toolCallLine, fallbackThreadID: "thread-a")
        let parsedOutput = parser.parse(line: toolOutputLine, fallbackThreadID: "thread-a")

        #expect(parsedCall.kind == .toolCallObserved)
        #expect(parsedCall.toolCall?.callID == "call-1")
        #expect(parsedCall.toolCall?.toolName == "shell")
        #expect(parsedCall.toolCall?.commandSummary == "swift test --package-path Packages/macOS/BmuxContextEfficiency")
        #expect(parsedCall.toolCall?.argumentsByteCount ?? 0 > 0)

        #expect(parsedOutput.kind == .toolOutputObserved)
        #expect(parsedOutput.toolOutput?.callID == "call-1")
        #expect(parsedOutput.toolOutput?.estimatedOriginalTokens == 1_800)
        #expect(parsedOutput.toolOutput?.rawOutputReferenceCount == 1)
        #expect(parsedOutput.toolOutput?.outputByteCount ?? 0 > 0)
    }

    @Test
    func extractsToolFactsFromNonStringPayloadShapes() throws {
        let parser = CodexRolloutTelemetryParser()
        let toolCallLine = CodexRolloutImportedLine(
            text: """
            {"type":"response_item","payload":{"type":"function_call","call_id":"call-object","name":"shell","arguments":{"cmd":["swift","test","--package-path","Packages/macOS/BmuxContextEfficiency"],"timeout_ms":30000}}}
            """,
            sourceReference: ContextEfficiencySourceReference(
                sourcePath: "/tmp/rollout-thread-a.jsonl",
                byteOffset: 0,
                lineNumber: 1,
                parserVersion: CodexRolloutTelemetryParser.parserVersion
            )
        )
        let toolOutputLine = CodexRolloutImportedLine(
            text: """
            {"type":"response_item","payload":{"type":"function_call_output","call_id":"call-object","output":{"chunks":["Original token count: 2300","Raw output: bmux agent-token-output show ref"],"truncated":true}}}
            """,
            sourceReference: ContextEfficiencySourceReference(
                sourcePath: "/tmp/rollout-thread-a.jsonl",
                byteOffset: 204,
                lineNumber: 2,
                parserVersion: CodexRolloutTelemetryParser.parserVersion
            )
        )

        let parsedCall = parser.parse(line: toolCallLine, fallbackThreadID: "thread-a")
        let parsedOutput = parser.parse(line: toolOutputLine, fallbackThreadID: "thread-a")

        #expect(parsedCall.kind == .toolCallObserved)
        #expect(parsedCall.toolCall?.callID == "call-object")
        #expect(parsedCall.toolCall?.commandSummary == "swift test --package-path Packages/macOS/BmuxContextEfficiency")
        #expect(parsedCall.toolCall?.argumentsByteCount ?? 0 > 0)

        #expect(parsedOutput.kind == .toolOutputObserved)
        #expect(parsedOutput.toolOutput?.callID == "call-object")
        #expect(parsedOutput.toolOutput?.estimatedOriginalTokens == 2_300)
        #expect(parsedOutput.toolOutput?.rawOutputReferenceCount == 1)
        #expect(parsedOutput.toolOutput?.outputByteCount ?? 0 > 0)
    }

    @Test
    func extractsToolFactsFromStringEncodedPayloadObjects() throws {
        let parser = CodexRolloutTelemetryParser()
        let line = CodexRolloutImportedLine(
            text: """
            {"type":"response_item","payload":"{\\"type\\":\\"function_call\\",\\"call_id\\":\\"call-string-payload\\",\\"name\\":\\"shell\\",\\"arguments\\":{\\"cmd\\":[\\"swift\\",\\"test\\",\\"--package-path\\",\\"Packages/macOS/BmuxContextEfficiency\\"],\\"timeout_ms\\":30000}}"}
            """,
            sourceReference: ContextEfficiencySourceReference(
                sourcePath: "/tmp/rollout-thread-a.jsonl",
                byteOffset: 408,
                lineNumber: 3,
                parserVersion: CodexRolloutTelemetryParser.parserVersion
            )
        )

        let parsed = parser.parse(line: line, fallbackThreadID: "thread-a")

        #expect(parsed.kind == .toolCallObserved)
        #expect(parsed.toolCall?.callID == "call-string-payload")
        #expect(parsed.toolCall?.toolName == "shell")
        #expect(parsed.toolCall?.commandSummary == "swift test --package-path Packages/macOS/BmuxContextEfficiency")
        #expect(parsed.toolCall?.argumentsByteCount ?? 0 > 0)
    }

    @Test
    func extractsWorkItemReferencesWithoutRetainingMessageText() throws {
        let parser = CodexRolloutTelemetryParser()
        let line = CodexRolloutImportedLine(
            text: """
            {"type":"event_msg","timestamp":"2026-07-13T12:02:00Z","payload":{"type":"user_message","threadID":"thread-a","message":"Continue STE-1964 on https://github.com/manaflow-ai/bmux/pull/4536 and issue https://github.com/manaflow-ai/bmux/issues/4529"}}
            """,
            sourceReference: ContextEfficiencySourceReference(
                sourcePath: "/tmp/rollout-thread-a.jsonl",
                byteOffset: 940,
                lineNumber: 6,
                parserVersion: CodexRolloutTelemetryParser.parserVersion
            )
        )

        let parsed = parser.parse(line: line, fallbackThreadID: "thread-a")

        #expect(parsed.kind == .userMessageObserved)
        #expect(parsed.workItemReferences.map(\.reference).contains("github:manaflow-ai/bmux#4536"))
        #expect(parsed.workItemReferences.map(\.reference).contains("github-issue:manaflow-ai/bmux#4529"))
        #expect(parsed.workItemReferences.map(\.reference).contains("ticket:STE-1964"))
        #expect(parsed.workItemReferences.allSatisfy { $0.sourceKind == .message })
        #expect(parsed.workItemReferences.allSatisfy { $0.sourceReference?.lineNumber == 6 })
    }

    @Test
    func extractsBranchAndRepositoryMetadataReferences() throws {
        let parser = CodexRolloutTelemetryParser()
        let line = CodexRolloutImportedLine(
            text: """
            {"type":"session_meta","timestamp":"2026-07-13T12:03:00Z","payload":{"id":"thread-a","git_branch":"STE-1964-add-starter-checklist","git_origin_url":"git@github.com:manaflow-ai/bmux.git"}}
            """,
            sourceReference: ContextEfficiencySourceReference(
                sourcePath: "/tmp/rollout-thread-a.jsonl",
                byteOffset: 1200,
                lineNumber: 7,
                parserVersion: CodexRolloutTelemetryParser.parserVersion
            )
        )

        let parsed = parser.parse(line: line, fallbackThreadID: "thread-a")

        #expect(parsed.workItemReferences.map(\.reference).contains("branch:STE-1964-add-starter-checklist"))
        #expect(parsed.workItemReferences.map(\.reference).contains("ticket:STE-1964"))
        #expect(parsed.workItemReferences.map(\.reference).contains("github-repo:manaflow-ai/bmux"))
        #expect(parsed.workItemReferences.first(where: { $0.kind == .branch })?.confidence == .branchCandidate)
        #expect(parsed.workItemReferences.first(where: { $0.kind == .repository })?.confidence == .metadata)
    }

    @Test
    func extractsToolFactsFromArrayPayloadObjects() throws {
        let parser = CodexRolloutTelemetryParser()
        let line = CodexRolloutImportedLine(
            text: """
            {"type":"response_item","payload":["unexpected",{"metadata":"ignored"},{"type":"function_call","call_id":"call-array-payload","name":"shell","arguments":{"cmd":["swift","test","--package-path","Packages/macOS/BmuxContextEfficiency"],"timeout_ms":30000}}]}
            """,
            sourceReference: ContextEfficiencySourceReference(
                sourcePath: "/tmp/rollout-thread-a.jsonl",
                byteOffset: 680,
                lineNumber: 4,
                parserVersion: CodexRolloutTelemetryParser.parserVersion
            )
        )

        let parsed = parser.parse(line: line, fallbackThreadID: "thread-a")

        #expect(parsed.kind == .toolCallObserved)
        #expect(parsed.toolCall?.callID == "call-array-payload")
        #expect(parsed.toolCall?.toolName == "shell")
        #expect(parsed.toolCall?.commandSummary == "swift test --package-path Packages/macOS/BmuxContextEfficiency")
        #expect(parsed.toolCall?.argumentsByteCount ?? 0 > 0)
    }

    @Test
    func scalarPayloadShapesRemainNonFatal() throws {
        let parser = CodexRolloutTelemetryParser()
        let line = CodexRolloutImportedLine(
            text: """
            {"type":"response_item","payload":42}
            """,
            sourceReference: ContextEfficiencySourceReference(
                sourcePath: "/tmp/rollout-thread-a.jsonl",
                byteOffset: 920,
                lineNumber: 5,
                parserVersion: CodexRolloutTelemetryParser.parserVersion
            )
        )

        let parsed = parser.parse(line: line, fallbackThreadID: "thread-a")

        #expect(parsed.kind == .unknownImported)
        #expect(parsed.parserErrorMessage == nil)
        #expect(parsed.toolCall == nil)
        #expect(parsed.toolOutput == nil)
    }

    @Test
    func malformedJSONBecomesParserErrorEvent() {
        let parser = CodexRolloutTelemetryParser()
        let line = CodexRolloutImportedLine(
            text: "{not-json",
            sourceReference: ContextEfficiencySourceReference(
                sourcePath: "/tmp/rollout-thread-a.jsonl",
                byteOffset: 9,
                lineNumber: 2,
                parserVersion: CodexRolloutTelemetryParser.parserVersion
            )
        )

        let parsed = parser.parse(line: line, fallbackThreadID: "thread-a")

        #expect(parsed.kind == .parserErrorObserved)
        #expect(parsed.parserErrorMessage == "line is not valid JSON")
        #expect(parsed.sourceReference.byteOffset == 9)
    }
}
