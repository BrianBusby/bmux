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
