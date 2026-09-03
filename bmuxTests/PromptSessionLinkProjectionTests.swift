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

final class PromptSessionLinkProjectionTests: XCTestCase {
    @MainActor
    func testMonitorTranscriptAndIdentityHookConvergeWithoutDisplayMetadataSeed() async throws {
        let fixture = try StoreFixture()
        defer { fixture.remove() }
        let client: any ProvenanceEngineContracts.ProvenanceEngineClient =
            try ProvenanceEngineClientFactory().sqliteClient(databaseURL: fixture.databaseURL)
        let repositoryRoot = "/tmp/bmux-monitor-session-link-repo"
        let gitSnapshot = WorkProvenanceGitSnapshot(
            repositoryRoot: repositoryRoot,
            commonDirectory: "\(repositoryRoot)/.git",
            remoteSlug: "manaflow-ai/bmux",
            branch: "harden-pe-session-readiness",
            headCommit: "def456",
            isDirty: false
        )
        let sessionID = "codex-monitor-session"
        let surfaceID = UUID()
        let promptText = "Show the factual Session data for this workspace."
        let transcriptURL = fixture.root.appendingPathComponent("rollout-\(sessionID).jsonl")
        try Self.writeCodexTranscript(
            sessionID: sessionID,
            repositoryRoot: repositoryRoot,
            promptText: promptText,
            to: transcriptURL
        )

        let importer = CLIProvenanceCodexTranscriptImporter(client: client)
        var liveImportState = CLIProvenanceCodexTranscriptImporter.LiveImportState()
        let importResult = try await importer.importLiveTranscriptAppend(
            at: transcriptURL,
            state: &liveImportState
        )
        XCTAssertEqual(importResult.fileReport.threads, 1)
        XCTAssertEqual(importResult.fileReport.turns, 1)
        XCTAssertEqual(importResult.fileReport.prompts, 1)
        let directProjection = try await client.factualSessionProjection(
            ProvenanceFactualSessionProjectionRequest(sessionID: sessionID)
        )
        XCTAssertEqual(directProjection.snapshot?.session.id, sessionID)

        let manager = TabManager()
        let workspace = manager.tabs[0]
        workspace.currentDirectory = repositoryRoot
        let observationService = WorkProvenanceObservationService(
            client: client,
            gitInspector: FakeGitInspector(snapshotsByDirectory: [repositoryRoot: gitSnapshot])
        )
        let runtime = WorkProvenanceRuntime(
            observationService: observationService,
            workspaceDisplayCurrentStateStore: WorkspaceDisplayCurrentStateStore(client: client),
            agentSessionFactualProjectionStore: AgentSessionFactualProjectionStore(client: client),
            codingAgentEvidenceRecorder: WorkProvenanceCodingAgentEvidenceRecorder(
                client: client,
                gitInspector: FakeGitInspector(snapshotsByDirectory: [repositoryRoot: gitSnapshot])
            )
        )
        runtime.start(tabManager: manager)

        let transcriptService = AgentChatTranscriptService(
            registry: AgentChatSessionRegistry(),
            resolver: AgentChatTranscriptResolver(
                homeDirectory: fixture.root,
                environment: ["CODEX_HOME": fixture.root.appendingPathComponent("empty-codex").path]
            ),
            recordTaskWorkspaceDirectory: { _, _ in }
        )
        transcriptService.recordSessionLifecycleChanges(with: runtime)
        transcriptService.noteHookEvent(WorkstreamEvent(
            sessionId: "codex-\(sessionID)",
            hookEventName: .userPromptSubmit,
            source: "codex",
            workspaceId: workspace.id.uuidString,
            surfaceId: surfaceID.uuidString,
            transcriptPath: nil,
            cwd: repositoryRoot,
            requestId: "identity-only-hook",
            receivedAt: Date(timeIntervalSince1970: 1_725_000_123)
        ))

        let result = await Self.waitForFactualProjection(
            runtime: runtime,
            stableWorkspaceID: workspace.stableId
        )
        guard case .available(let projection) = result else {
            XCTFail("Expected monitor transcript plus identity hook to converge to an available factual projection; got \(result)")
            return
        }
        XCTAssertEqual(projection.session.id, sessionID)
    }

    @MainActor
    func testPromptSubmitSessionLinkSurvivesThroughWorkspaceDisplayProjection() async throws {
        let fixture = try StoreFixture()
        defer { fixture.remove() }
        let client: any ProvenanceEngineContracts.ProvenanceEngineClient =
            try ProvenanceEngineClientFactory().sqliteClient(databaseURL: fixture.databaseURL)
        let repositoryRoot = "/tmp/bmux-prompt-session-link-repo"
        let gitSnapshot = WorkProvenanceGitSnapshot(
            repositoryRoot: repositoryRoot,
            commonDirectory: "\(repositoryRoot)/.git",
            remoteSlug: "manaflow-ai/bmux",
            branch: "fix-workspace-tab-conversation-metadata",
            headCommit: "abc123",
            isDirty: false
        )
        let promptText = "Fix the PE session tab"
        let sessionID = "raw-codex-session"
        let observedAt = Date(timeIntervalSince1970: 1_725_000_321)
        let recorder = WorkProvenanceCodingAgentEvidenceRecorder(
            client: client,
            gitInspector: FakeGitInspector(snapshotsByDirectory: [repositoryRoot: gitSnapshot])
        )

        try await recorder.recordTranscriptUserPrompts(
            record: AgentChatSessionRecord(
                sessionID: sessionID,
                agentKind: .codex,
                workspaceID: nil,
                surfaceID: nil,
                workingDirectory: repositoryRoot,
                transcriptPath: nil,
                state: .working(since: observedAt),
                lastActivityAt: observedAt,
                title: nil,
                pid: 321
            ),
            messages: [
                ChatMessage(
                    id: "line-1",
                    seq: 1,
                    role: .user,
                    timestamp: observedAt,
                    kind: .prose(ChatProse(text: promptText))
                )
            ]
        )

        let manager = TabManager()
        let workspace = manager.tabs[0]
        workspace.currentDirectory = repositoryRoot
        let promptOutcome = try XCTUnwrap(manager.handlePromptSubmit(
            workspaceId: workspace.id,
            message: " \(promptText) ",
            sessionID: " \(sessionID) ",
            iMessageModeEnabled: false
        ))
        XCTAssertTrue(promptOutcome.messageRecorded)

        let observationService = WorkProvenanceObservationService(
            client: client,
            gitInspector: FakeGitInspector(snapshotsByDirectory: [repositoryRoot: gitSnapshot]),
            dateProvider: { observedAt.addingTimeInterval(1) }
        )
        await observationService.observeWorkspaceSnapshot(WorkProvenanceWorkspaceSnapshot(workspace: workspace))

        let display = try await client.workspaceDisplay(ProvenanceWorkspaceDisplayRequest(
            workspaceID: workspace.stableId.uuidString
        ))
        XCTAssertEqual(display.display?.lastSubmittedPrompt, promptText)
        XCTAssertEqual(display.display?.lastSubmittedPromptSessionID, sessionID)

        let runtime = WorkProvenanceRuntime(
            observationService: observationService,
            workspaceDisplayCurrentStateStore: WorkspaceDisplayCurrentStateStore(client: client),
            agentSessionFactualProjectionStore: AgentSessionFactualProjectionStore(client: client)
        )
        guard case .available(let projection) = await runtime.agentSessionFactualProjection(
            stableWorkspaceID: workspace.stableId
        ) else {
            XCTFail("Expected PE factual session projection for the prompt-linked workspace")
            return
        }

        XCTAssertEqual(projection.session.id, sessionID)
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
                    "content": [
                        [
                            "type": "input_text",
                            "text": promptText
                        ]
                    ]
                ]
            ),
            try codexTranscriptLine(
                ordinal: 2,
                type: "event_msg",
                timestamp: "\(timestampMinute):02Z",
                payload: [
                    "type": "task_started",
                    "turn_id": turnID,
                    "started_at": startedAt
                ]
            )
        ]
    }

    private static func writeCodexTranscript(
        sessionID: String,
        repositoryRoot: String,
        promptText: String,
        to url: URL
    ) throws {
        let lines = try codexPromptTranscriptLines(
            sessionID: sessionID,
            repositoryRoot: repositoryRoot,
            promptText: promptText
        )
        try lines.joined(separator: "\n")
            .appending("\n")
            .write(to: url, atomically: true, encoding: .utf8)
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
                .appendingPathComponent("bmux-prompt-session-link-store-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            databaseURL = root.appendingPathComponent("provenance.sqlite", isDirectory: false)
        }

        func remove() {
            try? FileManager.default.removeItem(at: root)
        }
    }
}
