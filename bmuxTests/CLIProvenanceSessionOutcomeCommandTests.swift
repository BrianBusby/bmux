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

    @Test
    func bundledCLISessionsRetrievalCommandsUsePublicPEReads() async throws {
        let fixture = try StoreFixture()
        defer { fixture.remove() }
        let cliPath = try BundledCLITestSupport.bundledCLIPath(for: BundledCLILinkageTests.self)
        let environment = Self.cleanCLIEnvironment(home: fixture.directoryURL)
        let seeded = try await CLIProvenanceRetrievalFixture.seed(databaseURL: fixture.databaseURL)

        let relatedText = Self.runCLI(
            executablePath: cliPath,
            arguments: [
                "provenance", "sessions", "related", seeded.targetSessionID,
                "--database", fixture.databaseURL.path,
            ],
            environment: environment
        )
        #expect(!relatedText.timedOut)
        #expect(relatedText.status == 0)
        #expect(relatedText.output.contains("Related sessions for session-retrieval-b"))
        #expect(relatedText.output.contains("session-retrieval-a"))
        #expect(relatedText.output.contains("coding_agent.blockers=known"))
        #expect(relatedText.output.contains("coding_agent.approach_changes=known"))
        #expect(relatedText.output.contains("validations=1"))

        let relatedJSON = Self.runCLI(
            executablePath: cliPath,
            arguments: [
                "--json", "provenance", "sessions", "related", seeded.targetSessionID,
                "--limit", "10",
                "--exclusion-limit", "10",
                "--updated-after", "2026-01-01T00:00:00Z",
                "--database", fixture.databaseURL.path,
            ],
            environment: environment
        )
        #expect(!relatedJSON.timedOut)
        #expect(relatedJSON.status == 0)
        let relatedPayload = try CLIProvenanceRetrievalFixture.jsonPayload(relatedJSON.output)
        let relatedProjection = try #require(relatedPayload["projection"] as? [String: Any])
        let relatedSessions = try #require(relatedProjection["related_sessions"] as? [[String: Any]])
        let relatedBrief = try #require(relatedSessions.first)
        let semanticFields = try #require(relatedBrief["semantic_fields"] as? [[String: Any]])
        let relatedMetadata = try #require(relatedProjection["projection"] as? [String: Any])
        let relatedRevisionID = try #require(relatedMetadata["revision_id"] as? String)
        #expect(relatedPayload["found"] as? Bool == true)
        #expect(relatedPayload["target_session_id"] as? String == seeded.targetSessionID)
        #expect(relatedBrief["session_id"] as? String == seeded.relatedSessionID)
        #expect(semanticFields.contains { $0["kind"] as? String == "coding_agent.blockers" })
        #expect(semanticFields.contains { $0["kind"] as? String == "coding_agent.approach_changes" })

        let reverseUnknownText = Self.runCLI(
            executablePath: cliPath,
            arguments: [
                "provenance", "sessions", "--database", fixture.databaseURL.path,
                "related", seeded.relatedSessionID,
            ],
            environment: environment
        )
        #expect(!reverseUnknownText.timedOut)
        #expect(reverseUnknownText.status == 0)
        #expect(reverseUnknownText.output.contains(seeded.targetSessionID))
        #expect(reverseUnknownText.output.contains("coding_agent.blockers=unknown"))
        #expect(reverseUnknownText.output.contains("record=unknown"))

        let exactRevision = Self.runCLI(
            executablePath: cliPath,
            arguments: [
                "--json", "provenance", "sessions", "related", seeded.targetSessionID,
                "--revision", relatedRevisionID,
                "--database", fixture.databaseURL.path,
            ],
            environment: environment
        )
        #expect(!exactRevision.timedOut)
        #expect(exactRevision.status == 0)
        let exactPayload = try CLIProvenanceRetrievalFixture.jsonPayload(exactRevision.output)
        let exactProjection = try #require(exactPayload["projection"] as? [String: Any])
        let exactMetadata = try #require(exactProjection["projection"] as? [String: Any])
        #expect(exactMetadata["revision_id"] as? String == relatedRevisionID)

        let collisionsText = Self.runCLI(
            executablePath: cliPath,
            arguments: [
                "provenance", "sessions", "collisions", seeded.targetSessionID,
                "--artifact-path", seeded.sharedArtifactPath,
                "--database", fixture.databaseURL.path,
            ],
            environment: environment
        )
        #expect(!collisionsText.timedOut)
        #expect(collisionsText.status == 0)
        #expect(collisionsText.output.contains("Artifact collisions for session-retrieval-b"))
        #expect(collisionsText.output.contains(seeded.sharedArtifactPath))
        #expect(collisionsText.output.contains("different_worktrees"))
        #expect(collisionsText.output.contains("different_branches"))
        #expect(collisionsText.output.contains("Limitation: candidates start from the target session's recorded changed artifacts"))

        let collisionsJSON = Self.runCLI(
            executablePath: cliPath,
            arguments: [
                "--json", "provenance", "sessions", "collisions", seeded.targetSessionID,
                "--artifact-path", seeded.sharedArtifactPath,
                "--stale-before", "2026-01-01T00:00:00Z",
                "--database", fixture.databaseURL.path,
            ],
            environment: environment
        )
        #expect(!collisionsJSON.timedOut)
        #expect(collisionsJSON.status == 0)
        let collisionsPayload = try CLIProvenanceRetrievalFixture.jsonPayload(collisionsJSON.output)
        let collisionsProjection = try #require(collisionsPayload["projection"] as? [String: Any])
        let candidates = try #require(collisionsProjection["candidates"] as? [[String: Any]])
        let candidate = try #require(candidates.first)
        let artifactIdentity = try #require(candidate["artifact_identity"] as? [String: Any])
        let participants = try #require(candidate["participants"] as? [[String: Any]])
        #expect(collisionsPayload["found"] as? Bool == true)
        #expect(artifactIdentity["normalized_path"] as? String == seeded.sharedArtifactPath)
        #expect(Set(participants.compactMap { $0["session_id"] as? String }) == Set([
            seeded.targetSessionID,
            seeded.relatedSessionID,
        ]))

        let untouchedPath = Self.runCLI(
            executablePath: cliPath,
            arguments: [
                "--json", "provenance", "sessions", "collisions", seeded.targetSessionID,
                "--artifact-path", "Sources/Untouched.swift",
                "--database", fixture.databaseURL.path,
            ],
            environment: environment
        )
        #expect(!untouchedPath.timedOut)
        #expect(untouchedPath.status == 0)
        let untouchedPayload = try CLIProvenanceRetrievalFixture.jsonPayload(untouchedPath.output)
        let untouchedProjection = try #require(untouchedPayload["projection"] as? [String: Any])
        #expect((untouchedProjection["candidates"] as? [[String: Any]])?.isEmpty == true)

        let missingDatabaseURL = fixture.directoryURL.appendingPathComponent("missing-retrieval.sqlite")
        let missingDatabase = Self.runCLI(
            executablePath: cliPath,
            arguments: [
                "--json", "provenance", "sessions", "related", seeded.targetSessionID,
                "--database", missingDatabaseURL.path,
            ],
            environment: environment
        )
        #expect(!missingDatabase.timedOut)
        #expect(missingDatabase.status == 0)
        let missingDatabasePayload = try CLIProvenanceRetrievalFixture.jsonPayload(missingDatabase.output)
        #expect(missingDatabasePayload["found"] as? Bool == false)
        #expect(missingDatabasePayload["reason"] as? String == "no_database")
        #expect(!FileManager.default.fileExists(atPath: missingDatabaseURL.path))

        let missingSession = Self.runCLI(
            executablePath: cliPath,
            arguments: [
                "--json", "provenance", "sessions", "related", "session-missing",
                "--database", fixture.databaseURL.path,
            ],
            environment: environment
        )
        #expect(!missingSession.timedOut)
        #expect(missingSession.status == 0)
        let missingSessionPayload = try CLIProvenanceRetrievalFixture.jsonPayload(missingSession.output)
        #expect(missingSessionPayload["found"] as? Bool == false)
        #expect(missingSessionPayload["reason"] as? String == "no_session")

        let missingRevision = Self.runCLI(
            executablePath: cliPath,
            arguments: [
                "--json", "provenance", "sessions", "related", seeded.targetSessionID,
                "--revision", "missing-revision",
                "--database", fixture.databaseURL.path,
            ],
            environment: environment
        )
        #expect(!missingRevision.timedOut)
        #expect(missingRevision.status == 0)
        let missingRevisionPayload = try CLIProvenanceRetrievalFixture.jsonPayload(missingRevision.output)
        #expect(missingRevisionPayload["found"] as? Bool == false)
        #expect(missingRevisionPayload["reason"] as? String == "no_revision")

        let emptyRevision = Self.runCLI(
            executablePath: cliPath,
            arguments: [
                "provenance", "sessions", "related", seeded.targetSessionID,
                "--revision", "   ",
                "--database", fixture.databaseURL.path,
            ],
            environment: environment
        )
        #expect(!emptyRevision.timedOut)
        #expect(emptyRevision.status != 0)
        #expect(emptyRevision.output.contains("--revision requires a value"))

        let emptyLimit = Self.runCLI(
            executablePath: cliPath,
            arguments: [
                "provenance", "sessions", "related", seeded.targetSessionID,
                "--limit=   ",
                "--database", fixture.databaseURL.path,
            ],
            environment: environment
        )
        #expect(!emptyLimit.timedOut)
        #expect(emptyLimit.status != 0)
        #expect(emptyLimit.output.contains("--limit requires a value"))

        let hugeLimit = Self.runCLI(
            executablePath: cliPath,
            arguments: [
                "provenance", "sessions", "related", seeded.targetSessionID,
                "--limit", "999",
                "--database", fixture.databaseURL.path,
            ],
            environment: environment
        )
        #expect(!hugeLimit.timedOut)
        #expect(hugeLimit.status != 0)
        #expect(hugeLimit.output.contains("--limit must be an integer from 0 through 25"))

        let invalidDate = Self.runCLI(
            executablePath: cliPath,
            arguments: [
                "provenance", "sessions", "related", seeded.targetSessionID,
                "--updated-after", "not-a-date",
                "--database", fixture.databaseURL.path,
            ],
            environment: environment
        )
        #expect(!invalidDate.timedOut)
        #expect(invalidDate.status != 0)
        #expect(invalidDate.output.contains("--updated-after must be RFC 3339"))

        let emptyArtifactPath = Self.runCLI(
            executablePath: cliPath,
            arguments: [
                "provenance", "sessions", "collisions", seeded.targetSessionID,
                "--artifact-path", "",
                "--database", fixture.databaseURL.path,
            ],
            environment: environment
        )
        #expect(!emptyArtifactPath.timedOut)
        #expect(emptyArtifactPath.status != 0)
        #expect(emptyArtifactPath.output.contains("--artifact-path requires a value"))

        let invalidPath = Self.runCLI(
            executablePath: cliPath,
            arguments: [
                "provenance", "sessions", "collisions", seeded.targetSessionID,
                "--artifact-path", "/tmp/absolute.swift",
                "--database", fixture.databaseURL.path,
            ],
            environment: environment
        )
        #expect(!invalidPath.timedOut)
        #expect(invalidPath.status != 0)
        #expect(invalidPath.output.contains("--artifact-path must be a non-empty repository-relative path"))
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

        let outputLock = NSLock()
        var outputData = Data()
        outputPipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            guard !chunk.isEmpty else { return }
            outputLock.lock()
            outputData.append(chunk)
            outputLock.unlock()
        }

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
        outputPipe.fileHandleForReading.readabilityHandler = nil
        let remainingOutput = outputPipe.fileHandleForReading.readDataToEndOfFile()
        outputLock.lock()
        outputData.append(remainingOutput)
        let output = String(data: outputData, encoding: .utf8) ?? ""
        outputLock.unlock()
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
