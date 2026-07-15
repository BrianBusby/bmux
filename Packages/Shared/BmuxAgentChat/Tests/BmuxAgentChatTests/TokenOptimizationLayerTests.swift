import Testing

import BmuxAgentChat

@Suite("TokenOptimizationLayer")
struct TokenOptimizationLayerTests {
    @Test("optimizes command output and returns a complete raw-output record")
    func optimizesOutputAndPreservesRawRecord() {
        let rawOutput = """
        On branch feature/token-layer
        Changes to be committed:
          modified:   Sources/App.swift
        Changes not staged for commit:
          modified:   Sources/OldThing.swift
        Untracked files:
          docs/token-layer.md

        """

        let result = TokenOptimizationLayer().optimizeTerminalOutput(
            messageID: "message-1",
            command: "git status",
            rawOutput: rawOutput,
            exitCode: 0
        )

        #expect(result.kind == .git)
        #expect(result.wasOptimized)
        #expect(result.output.contains("git status summary"))
        #expect(result.output.contains("branch: feature/token-layer"))
        #expect(result.output.contains("staged: 1"))
        #expect(result.rawOutputRecord.rawOutput == rawOutput)
        #expect(result.rawOutputRecord.command == "git status")
        #expect(result.rawOutputRecord.metadata == result.metadata)
        #expect(result.metadata.rawOutputRef?.hasPrefix("terminal-output:message-1:") == true)
        #expect(result.metadata.rawByteCount == rawOutput.utf8.count)
        #expect(result.metadata.optimizedByteCount == result.output.utf8.count)
    }

    @Test("returns raw output and metadata when no compressor matches")
    func returnsRawOutputForGenericCommand() {
        let rawOutput = "plain output\n"

        let result = TokenOptimizationLayer().optimizeTerminalOutput(
            messageID: "message-2",
            command: "echo plain",
            rawOutput: rawOutput,
            exitCode: 0
        )

        #expect(result.kind == .generic)
        #expect(!result.wasOptimized)
        #expect(result.output == rawOutput)
        #expect(result.rawOutputRecord.rawOutput == rawOutput)
        #expect(result.metadata.wasOptimized == false)
        #expect(result.metadata.omittedLineCount == 0)
    }

    @Test("off mode preserves raw output even when a compressor matches")
    func offModePreservesRawOutput() {
        let rawOutput = """
        On branch feature/token-layer
        Changes to be committed:
          modified:   Sources/App.swift

        """

        let result = TokenOptimizationLayer(mode: .off).optimizeTerminalOutput(
            messageID: "message-3",
            command: "git status",
            rawOutput: rawOutput,
            exitCode: 0
        )

        #expect(result.output == rawOutput)
        #expect(!result.wasOptimized)
        #expect(result.metadata.rawOutputRef?.hasPrefix("terminal-output:message-3:") == true)
        #expect(result.metadata.rawByteCount == rawOutput.utf8.count)
        #expect(result.rawOutputRecord.rawOutput == rawOutput)
    }

    @Test("conservative mode leaves git details raw")
    func conservativeModeLeavesGitOutputRaw() {
        let rawOutput = """
        On branch feature/token-layer
        Changes not staged for commit:
          modified:   Sources/OldThing.swift

        """

        let result = TokenOptimizationLayer(mode: .conservative).optimizeTerminalOutput(
            messageID: "message-4",
            command: "git status",
            rawOutput: rawOutput,
            exitCode: 0
        )

        #expect(result.kind == .git)
        #expect(result.output == rawOutput)
        #expect(!result.wasOptimized)
    }

    @Test("conservative mode keeps passing test summaries")
    func conservativeModeKeepsPassingTestSummary() {
        let rawOutput = """
        Test Suite 'All tests' started
        Test Case '-[ExampleTests testOne]' passed (0.001 seconds)
        Test Case '-[ExampleTests testTwo]' passed (0.001 seconds)
        Test Suite 'All tests' passed at 2026-07-07.
            Executed 2 tests, with 0 failures (0 unexpected) in 0.002 seconds
        """

        let result = TokenOptimizationLayer(mode: .conservative).optimizeTerminalOutput(
            messageID: "message-5",
            command: "swift test",
            rawOutput: rawOutput,
            exitCode: 0
        )

        #expect(result.kind == .tests)
        #expect(result.wasOptimized)
        #expect(result.output.contains("tests passed"))
        #expect(!result.output.contains("testOne"))
    }

    @Test("summarizes failing test output while preserving diagnostics")
    func summarizesFailingTestOutput() {
        var lines = [
            "Test Suite 'All tests' started",
            "Build settings loaded",
            "Running ExampleTests"
        ]
        for index in 1...120 {
            lines.append("Test Case '-[ExampleTests testPass\(index)]' passed (0.001 seconds)")
        }
        lines.append("/tmp/project/Tests/ExampleTests.swift:42: error: ExampleTests.testFailure : XCTAssertEqual failed")
        lines.append("Expected: \"ready\"")
        lines.append("Received: \"blocked\"")
        lines.append("Test Case '-[ExampleTests testFailure]' failed (0.004 seconds)")
        lines.append("Executed 121 tests, with 1 failure (0 unexpected) in 0.500 seconds")
        let rawOutput = lines.joined(separator: "\n")

        let result = TokenOptimizationLayer().optimizeTerminalOutput(
            messageID: "message-6",
            command: "swift test",
            rawOutput: rawOutput,
            exitCode: 1
        )

        #expect(result.kind == .tests)
        #expect(result.wasOptimized)
        #expect(result.output.contains("test failure summary"))
        #expect(result.output.contains("ExampleTests.swift:42"))
        #expect(result.output.contains("Expected: \"ready\""))
        #expect(result.output.contains("Received: \"blocked\""))
        #expect(result.output.contains("raw output"))
        #expect(!result.output.contains("testPass50"))
        #expect(result.rawOutputRecord.rawOutput == rawOutput)
    }
}
