import Testing

@testable import BmuxAgentChat

@Suite("CommandOutputOptimizer")
struct CommandOutputOptimizerTests {
    @Test("git status summarizes counts and keeps the first changed paths")
    func gitStatusSummary() {
        let output = """
        On branch feature/token-layer
        Changes to be committed:
          modified:   Sources/App.swift
          new file:   Sources/NewThing.swift
        Changes not staged for commit:
          modified:   Sources/OldThing.swift
          deleted:    Sources/Removed.swift
        Untracked files:
          docs/token-layer.md
          scripts/probe.sh
          tmp/debug.log

        """

        let result = CommandOutputOptimizer().optimize(
            command: "git status --short --branch",
            output: output,
            exitCode: 0
        )

        #expect(result.kind == .git)
        #expect(result.wasOptimized)
        #expect(result.text.contains("branch: feature/token-layer"))
        #expect(result.text.contains("staged: 2"))
        #expect(result.text.contains("unstaged: 2"))
        #expect(result.text.contains("untracked: 3"))
        #expect(result.text.contains("Sources/App.swift"))
        #expect(result.text.contains("1 additional file omitted"))
    }

    @Test("passing test output collapses repetitive success logs")
    func passingTestsSummary() {
        let output = """
        Test Suite 'All tests' started.
        Test Case '-[A testOne]' passed (0.001 seconds).
        Test Case '-[A testTwo]' passed (0.002 seconds).
        Test Case '-[B testThree]' passed (0.003 seconds).
        Executed 417 tests, with 0 failures (0 unexpected) in 11.4 seconds
        """

        let result = CommandOutputOptimizer().optimize(
            command: "swift test",
            output: output,
            exitCode: 0
        )

        #expect(result.kind == .tests)
        #expect(result.text == "OK: 417 tests passed, 0 failed. Elapsed: 11.4s")
    }

    @Test("TypeScript errors are grouped by file and repeated diagnostics are deduplicated")
    func typescriptErrorSummary() {
        let output = """
        src/a.ts(10,5): error TS2322: Type 'string' is not assignable to type 'number'.
        src/a.ts(10,5): error TS2322: Type 'string' is not assignable to type 'number'.
        src/a.ts(22,1): error TS2552: Cannot find name 'frobnicate'.
        src/b.ts(4,8): error TS2304: Cannot find name 'Widget'.
        """

        let result = CommandOutputOptimizer().optimize(
            command: "yarn tsc --noEmit",
            output: output,
            exitCode: 2
        )

        #expect(result.kind == .typescript)
        #expect(result.wasOptimized)
        #expect(result.text.contains("src/a.ts"))
        #expect(result.text.contains("TS2322"))
        #expect(result.text.contains("TS2552"))
        #expect(result.text.contains("src/b.ts"))
        #expect(result.text.components(separatedBy: "TS2322").count == 2)
    }

    @Test("search commands keep the first matches and report omitted lines")
    func searchSummary() {
        let output = (1...8)
            .map { "Sources/File\($0).swift:\($0):match line \($0)" }
            .joined(separator: "\n")

        let result = CommandOutputOptimizer().optimize(
            command: "rg token Sources",
            output: output,
            exitCode: 0
        )

        #expect(result.kind == .search)
        #expect(result.wasOptimized)
        #expect(result.text.contains("8 matches"))
        #expect(result.text.contains("Sources/File1.swift:1:match line 1"))
        #expect(result.text.contains("3 additional matches omitted"))
    }

    @Test("package installs remove progress chatter and preserve warnings")
    func packageInstallSummary() {
        let output = """
        Resolving packages...
        Downloading left-pad 12.5 MB/24.0 MB
        Downloading left-pad 24.0 MB/24.0 MB
        warning left-pad@1.0.0: deprecated package
        added 124 packages, and audited 125 packages in 8s
        found 0 vulnerabilities
        """

        let result = CommandOutputOptimizer().optimize(
            command: "npm install",
            output: output,
            exitCode: 0
        )

        #expect(result.kind == .packageInstall)
        #expect(result.wasOptimized)
        #expect(result.text.contains("package install summary"))
        #expect(result.text.contains("added 124 packages"))
        #expect(result.text.contains("warning left-pad@1.0.0: deprecated package"))
        #expect(!result.text.contains("24.0 MB/24.0 MB"))
    }
}
