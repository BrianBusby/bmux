import Darwin
import Foundation
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@Suite(.serialized)
struct CLIProvenanceSessionOutcomeCommandTests {
    @Test
    func bundledCLISessionOutcomeCommandPrintsTextAndCompleteJSON() throws {
        let fixture = try StoreFixture()
        defer { fixture.remove() }
        let cliPath = try BundledCLITestSupport.bundledCLIPath(for: BundledCLILinkageTests.self)
        let transcriptURL = fixture.directoryURL.appendingPathComponent("codex-session.jsonl")
        try Self.writeCodexTranscriptFixture(to: transcriptURL)
        let environment = Self.cleanCLIEnvironment(home: fixture.directoryURL)

        let importResult = Self.runCLI(
            executablePath: cliPath,
            arguments: [
                "provenance", "import", "codex-transcripts",
                "--path", transcriptURL.path,
                "--database", fixture.databaseURL.path,
            ],
            environment: environment
        )
        #expect(!importResult.timedOut)
        #expect(importResult.status == 0)

        let textResult = Self.runCLI(
            executablePath: cliPath,
            arguments: [
                "provenance", "session", "outcome", "codex-session-1",
                "--database", fixture.databaseURL.path,
            ],
            environment: environment
        )
        #expect(!textResult.timedOut)
        #expect(textResult.status == 0)
        #expect(textResult.output.contains("Session outcome for codex-session-1"))
        #expect(textResult.output.contains("Turns: 1"))
        #expect(textResult.output.contains("Commands: 1 - validations: 1"))

        let jsonResult = Self.runCLI(
            executablePath: cliPath,
            arguments: [
                "--json", "provenance", "session", "outcome", "codex-session-1",
                "--database", fixture.databaseURL.path,
            ],
            environment: environment
        )
        #expect(!jsonResult.timedOut)
        #expect(jsonResult.status == 0)
        let payload = try #require(JSONSerialization.jsonObject(with: Data(jsonResult.output.utf8)) as? [String: Any])
        let outcome = try #require(payload["outcome"] as? [String: Any])
        let projection = try #require(outcome["projection"] as? [String: Any])
        #expect(payload["found"] as? Bool == true)
        #expect(payload["session_id"] as? String == "codex-session-1")
        #expect(projection["projection_rule_id"] as? String == "deterministic_session_outcome")
        #expect((outcome["constituent_turns"] as? [[String: Any]])?.count == 1)
        #expect((outcome["turn_outcomes"] as? [[String: Any]])?.count == 1)
        #expect((outcome["objectives"] as? [[String: Any]])?.count == 1)
        #expect((outcome["commands_completed"] as? [[String: Any]])?.count == 1)
        #expect((outcome["validations_attempted"] as? [[String: Any]])?.count == 1)

        let missingDatabaseURL = fixture.directoryURL.appendingPathComponent("missing.sqlite")
        let missingResult = Self.runCLI(
            executablePath: cliPath,
            arguments: [
                "--json", "provenance", "session", "outcome", "codex-missing-session",
                "--database", missingDatabaseURL.path,
            ],
            environment: environment
        )
        #expect(!missingResult.timedOut)
        #expect(missingResult.status == 0)
        let missingPayload = try #require(JSONSerialization.jsonObject(with: Data(missingResult.output.utf8)) as? [String: Any])
        #expect(missingPayload["found"] as? Bool == false)
        #expect(missingPayload["reason"] as? String == "no_database")
        #expect(missingPayload["session_id"] as? String == "codex-missing-session")
    }

    private static func writeCodexTranscriptFixture(to url: URL) throws {
        let lines = try CLIProvenanceCodexTranscriptImporterTests.codexTranscriptFixtureLines()
        try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
    }

    private static func cleanCLIEnvironment(home: URL) -> [String: String] {
        [
            "BMUX_CLI_SENTRY_DISABLED": "1",
            "CFFIXED_USER_HOME": home.path,
            "HOME": home.path,
            "PATH": "/usr/bin:/bin:/usr/sbin:/sbin",
            "TMPDIR": FileManager.default.temporaryDirectory.path,
        ]
    }

    private static func runCLI(
        executablePath: String,
        arguments: [String],
        environment: [String: String],
        timeout: TimeInterval = 30
    ) -> CLIProcessResult {
        let process = Process()
        let outputPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        process.environment = environment
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        let exitSignal = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in
            exitSignal.signal()
        }

        do {
            try process.run()
        } catch {
            return CLIProcessResult(status: -1, output: String(describing: error), timedOut: false)
        }

        let timedOut = exitSignal.wait(timeout: .now() + timeout) == .timedOut
        if timedOut {
            process.terminate()
            if exitSignal.wait(timeout: .now() + 1) == .timedOut,
               process.isRunning {
                kill(process.processIdentifier, SIGKILL)
                _ = exitSignal.wait(timeout: .now() + 1)
            }
        }
        let output = String(
            data: outputPipe.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        ) ?? ""
        return CLIProcessResult(status: process.terminationStatus, output: output, timedOut: timedOut)
    }

    private struct CLIProcessResult {
        let status: Int32
        let output: String
        let timedOut: Bool
    }

    private struct StoreFixture {
        let directoryURL: URL
        let databaseURL: URL

        init() throws {
            directoryURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("bmux-session-outcome-cli-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true
            )
            databaseURL = directoryURL.appendingPathComponent("provenance.sqlite")
        }

        func remove() {
            try? FileManager.default.removeItem(at: directoryURL)
        }
    }
}
