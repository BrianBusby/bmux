import XCTest
import BMUXAgentLaunch
import BmuxAgentChat
import Foundation
import ProvenanceEngineContracts
import ProvenanceEngineSDK

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

final class PromptSessionLinkProductionLifecycleTests: XCTestCase {
    @MainActor
    func testCanonicalAssociationSurvivesOrderingReplayRestartResumeAndConcurrentSessions() async throws {
        let fixture = try StoreFixture()
        defer { fixture.remove() }
        let client: any ProvenanceEngineContracts.ProvenanceEngineClient =
            try ProvenanceEngineClientFactory().sqliteClient(databaseURL: fixture.databaseURL)
        let repositoryRoot = "/tmp/bmux-production-session-link-repo"
        let gitSnapshot = WorkProvenanceGitSnapshot(
            repositoryRoot: repositoryRoot,
            commonDirectory: "\(repositoryRoot)/.git",
            remoteSlug: "manaflow-ai/bmux",
            branch: "harden-pe-session-readiness",
            headCommit: "feed123",
            isDirty: false
        )
        let gitInspector = FakeGitInspector(snapshotsByDirectory: [repositoryRoot: gitSnapshot])
        let importer = CLIProvenanceCodexTranscriptImporter(client: client)
        let manager = TabManager()
        let workspace = manager.tabs[0]
        workspace.currentDirectory = repositoryRoot
        let otherManager = TabManager()
        let otherWorkspace = otherManager.tabs[0]
        otherWorkspace.currentDirectory = repositoryRoot
        let surfaceID = UUID()
        let otherSurfaceID = UUID()
        let runtime = Self.runtime(client: client, gitInspector: gitInspector)
        runtime.start(tabManager: manager)
        runtime.observeWorkspaces([workspace, otherWorkspace])
        let transcriptService = AgentChatTranscriptService(
            registry: AgentChatSessionRegistry(),
            resolver: AgentChatTranscriptResolver(
                homeDirectory: fixture.root,
                environment: ["CODEX_HOME": fixture.root.appendingPathComponent("empty-codex").path]
            ),
            recordTaskWorkspaceDirectory: { _, _ in }
        )
        transcriptService.recordSessionLifecycleChanges(with: runtime)

        let hookFirstSessionID = "production-hook-first"
        transcriptService.noteHookEvent(WorkstreamEvent(
            sessionId: "codex-\(hookFirstSessionID)",
            hookEventName: .userPromptSubmit,
            source: "codex",
            workspaceId: workspace.id.uuidString,
            surfaceId: surfaceID.uuidString,
            cwd: repositoryRoot,
            context: WorkstreamContext(lastUserMessage: "Link the hook-first Codex session."),
            requestId: "hook-first-request",
            receivedAt: try Self.isoDate("2026-08-21T10:00:01Z")
        ))
        try Self.assertAvailable(
            await Self.waitForFactualProjection(runtime: runtime, stableWorkspaceID: workspace.stableId),
            sessionID: hookFirstSessionID
        )

        let hookFirstTranscriptURL = fixture.root.appendingPathComponent("rollout-\(hookFirstSessionID).jsonl")
        try Self.writeCodexTranscript(
            sessionID: hookFirstSessionID,
            repositoryRoot: repositoryRoot,
            promptText: "Link the hook-first Codex session.",
            to: hookFirstTranscriptURL
        )
        var hookFirstTranscriptState = CLIProvenanceCodexTranscriptImporter.LiveImportState(
            workspaceID: workspace.stableId.uuidString,
            surfaceID: surfaceID.uuidString
        )
        let hookFirstTranscriptImport = try await importer.importLiveTranscriptAppend(
            at: hookFirstTranscriptURL,
            state: &hookFirstTranscriptState
        )
        XCTAssertEqual(hookFirstTranscriptImport.fileReport.prompts, 1)
        try Self.assertAvailable(
            await Self.waitForFactualProjection(runtime: runtime, stableWorkspaceID: workspace.stableId),
            sessionID: hookFirstSessionID
        )
        let hookFirstAssociationResponse = try await client.workspaceCodingAgentSessionAssociation(
            ProvenanceWorkspaceCodingAgentSessionAssociationRequest(workspaceID: workspace.stableId.uuidString)
        )
        let hookFirstAssociation = try XCTUnwrap(hookFirstAssociationResponse.association)
        XCTAssertEqual(hookFirstAssociation.sessionID, hookFirstSessionID)

        let currentSessionID = "production-current"
        let currentTranscriptURL = fixture.root.appendingPathComponent("rollout-\(currentSessionID).jsonl")
        let currentLines = try Self.codexPromptTranscriptLines(
            sessionID: currentSessionID,
            repositoryRoot: repositoryRoot,
            promptText: "Finish the partial JSONL line.",
            timestampMinute: "2026-08-21T10:10",
            turnID: "turn-current-1",
            startedAt: 1_787_326_202
        )
        try Self.writeTranscriptLines([currentLines[0]], to: currentTranscriptURL)
        var currentLiveState = CLIProvenanceCodexTranscriptImporter.LiveImportState(
            workspaceID: otherWorkspace.stableId.uuidString,
            surfaceID: otherSurfaceID.uuidString
        )
        let metadataOnly = try await importer.importLiveTranscriptAppend(
            at: currentTranscriptURL,
            state: &currentLiveState
        )
        XCTAssertEqual(metadataOnly.fileReport.threads, 1)
        guard case .agentDetectedAwaitingFirstPrompt(let awaitingReadiness) =
            await runtime.agentSessionFactualProjection(stableWorkspaceID: otherWorkspace.stableId) else {
            XCTFail("Metadata-only transcript evidence must be pending, not missing or available")
            return
        }
        XCTAssertEqual(awaitingReadiness.sessionID, currentSessionID)

        try Self.appendTranscriptText(currentLines[1], to: currentTranscriptURL)
        let partialPrompt = try await importer.importLiveTranscriptAppend(
            at: currentTranscriptURL,
            state: &currentLiveState
        )
        XCTAssertEqual(partialPrompt.consumedLines, 0)
        XCTAssertTrue(partialPrompt.retainedPartialLine)
        guard case .agentDetectedAwaitingFirstPrompt =
            await runtime.agentSessionFactualProjection(stableWorkspaceID: otherWorkspace.stableId) else {
            XCTFail("An unterminated JSONL prompt must remain pending")
            return
        }

        try Self.appendTranscriptText("\n\(currentLines[2])\n", to: currentTranscriptURL)
        let completedPrompt = try await importer.importLiveTranscriptAppend(
            at: currentTranscriptURL,
            state: &currentLiveState
        )
        XCTAssertEqual(completedPrompt.fileReport.prompts, 1)
        try Self.assertAvailable(
            await Self.waitForFactualProjection(runtime: runtime, stableWorkspaceID: otherWorkspace.stableId),
            sessionID: currentSessionID
        )

        let replay = try await importer.importTranscripts(path: currentTranscriptURL.path)
        XCTAssertEqual(replay.eventsAppended, 0)
        XCTAssertGreaterThan(replay.duplicateEvents, 0)
        let restartedRuntime = Self.runtime(client: client, gitInspector: gitInspector)
        try Self.assertAvailable(
            await Self.waitForFactualProjection(runtime: restartedRuntime, stableWorkspaceID: otherWorkspace.stableId),
            sessionID: currentSessionID
        )

        transcriptService.noteResumeInitiated(
            sessionID: currentSessionID,
            source: "codex",
            surfaceID: otherSurfaceID.uuidString,
            workspaceID: otherWorkspace.id.uuidString,
            workingDirectory: repositoryRoot
        )
        try Self.assertAvailable(
            await Self.waitForFactualProjection(runtime: restartedRuntime, stableWorkspaceID: otherWorkspace.stableId),
            sessionID: currentSessionID
        )

        let staleURL = fixture.root.appendingPathComponent("rollout-codex-production-stale.jsonl")
        try Self.writeCodexTranscript(
            sessionID: "codex-production-stale",
            repositoryRoot: repositoryRoot,
            promptText: "This stale session should not replace the active association.",
            to: staleURL
        )
        var staleState = CLIProvenanceCodexTranscriptImporter.LiveImportState(
            workspaceID: otherWorkspace.stableId.uuidString,
            surfaceID: otherSurfaceID.uuidString
        )
        let staleImport = try await importer.importLiveTranscriptAppend(at: staleURL, state: &staleState)
        XCTAssertEqual(staleImport.fileReport.prompts, 1)
        try Self.assertAvailable(
            await Self.waitForFactualProjection(runtime: restartedRuntime, stableWorkspaceID: otherWorkspace.stableId),
            sessionID: currentSessionID
        )
        try Self.assertAvailable(
            await Self.waitForFactualProjection(runtime: restartedRuntime, stableWorkspaceID: workspace.stableId),
            sessionID: hookFirstSessionID
        )
    }

    @MainActor
    private static func waitForFactualProjection(
        runtime: WorkProvenanceRuntime,
        stableWorkspaceID: UUID,
        timeout: TimeInterval = 1
    ) async -> AgentSessionFactualProjectionReadResult {
        let deadline = Date().addingTimeInterval(timeout)
        var latest = await runtime.agentSessionFactualProjection(stableWorkspaceID: stableWorkspaceID)
        while Date() < deadline {
            if case .available = latest {
                return latest
            }
            try? await Task.sleep(nanoseconds: 50_000_000)
            latest = await runtime.agentSessionFactualProjection(stableWorkspaceID: stableWorkspaceID)
        }
        return latest
    }

    @MainActor
    private static func runtime(
        client: any ProvenanceEngineContracts.ProvenanceEngineClient,
        gitInspector: FakeGitInspector
    ) -> WorkProvenanceRuntime {
        WorkProvenanceRuntime(
            observationService: WorkProvenanceObservationService(
                client: client,
                gitInspector: gitInspector
            ),
            workspaceDisplayCurrentStateStore: WorkspaceDisplayCurrentStateStore(client: client),
            agentSessionFactualProjectionStore: AgentSessionFactualProjectionStore(client: client),
            codingAgentEvidenceRecorder: WorkProvenanceCodingAgentEvidenceRecorder(
                client: client,
                gitInspector: gitInspector
            )
        )
    }

    private static func assertAvailable(
        _ result: AgentSessionFactualProjectionReadResult,
        sessionID: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        guard case .available(let projection) = result else {
            XCTFail("Expected available factual projection for \(sessionID); got \(result)", file: file, line: line)
            return
        }
        XCTAssertEqual(projection.session.id, sessionID, file: file, line: line)
    }

    private static func isoDate(_ rawValue: String) throws -> Date {
        try XCTUnwrap(ISO8601DateFormatter().date(from: rawValue))
    }

    private static func writeCodexTranscript(
        sessionID: String,
        repositoryRoot: String,
        promptText: String,
        to url: URL
    ) throws {
        try writeTranscriptLines(
            codexPromptTranscriptLines(
                sessionID: sessionID,
                repositoryRoot: repositoryRoot,
                promptText: promptText
            ),
            to: url
        )
    }

    private static func writeTranscriptLines(_ lines: [String], to url: URL) throws {
        try lines.joined(separator: "\n")
            .appending("\n")
            .write(to: url, atomically: true, encoding: .utf8)
    }

    private static func appendTranscriptText(_ text: String, to url: URL) throws {
        let existing = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        try existing.appending(text).write(to: url, atomically: true, encoding: .utf8)
    }

    private static func codexPromptTranscriptLines(
        sessionID: String,
        repositoryRoot: String,
        promptText: String,
        timestampMinute: String = "2026-08-21T10:00",
        turnID: String = "turn-monitor-1",
        startedAt: Int = 1_787_325_602
    ) throws -> [String] {
        [
            try codexTranscriptLine(
                ordinal: 0,
                type: "session_meta",
                timestamp: "\(timestampMinute):00Z",
                payload: [
                    "session_id": sessionID,
                    "id": sessionID,
                    "timestamp": "\(timestampMinute):00Z",
                    "cwd": repositoryRoot,
                    "originator": "codex-tui",
                    "source": "cli",
                    "model_provider": "openai"
                ]
            ),
            try codexTranscriptLine(
                ordinal: 1,
                type: "response_item",
                timestamp: "\(timestampMinute):01Z",
                payload: [
                    "type": "message",
                    "role": "user",
                    "content": [["type": "input_text", "text": promptText]]
                ]
            ),
            try codexTranscriptLine(
                ordinal: 2,
                type: "event_msg",
                timestamp: "\(timestampMinute):02Z",
                payload: ["type": "task_started", "turn_id": turnID, "started_at": startedAt]
            )
        ]
    }

    private static func codexTranscriptLine(
        ordinal: Int,
        type: String,
        timestamp: String,
        payload: [String: Any]
    ) throws -> String {
        let object: [String: Any] = [
            "timestamp": timestamp,
            "ordinal": ordinal,
            "type": type,
            "payload": payload
        ]
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        return String(decoding: data, as: UTF8.self)
    }

    private struct FakeGitInspector: WorkProvenanceGitInspecting {
        let snapshotsByDirectory: [String: WorkProvenanceGitSnapshot]

        func snapshot(for directory: String) async -> WorkProvenanceGitSnapshot? {
            snapshotsByDirectory[directory]
        }
    }

    private struct StoreFixture {
        let root: URL
        let databaseURL: URL

        init() throws {
            root = FileManager.default.temporaryDirectory
                .appendingPathComponent("bmux-production-session-link-store-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            databaseURL = root.appendingPathComponent("provenance.sqlite", isDirectory: false)
        }

        func remove() {
            try? FileManager.default.removeItem(at: root)
        }
    }
}
