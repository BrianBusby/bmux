import Foundation
import BMUXAgentLaunch
import BmuxAgentChat
import ProvenanceEngineContracts
import ProvenanceEngineSDK
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@Suite
struct CLIProvenanceCodexTranscriptImporterTests {
    @Test
    func appendsCanonicalEvidenceIdempotently() async throws {
        let fixture = try StoreFixture()
        defer { fixture.remove() }
        let client: any ProvenanceEngineContracts.ProvenanceEngineClient =
            try ProvenanceEngineClientFactory().sqliteClient(databaseURL: fixture.databaseURL)
        let transcriptURL = fixture.directoryURL.appendingPathComponent("codex-session.jsonl")
        try Self.writeCodexTranscriptFixture(to: transcriptURL)

        let importer = CLIProvenanceCodexTranscriptImporter(client: client)
        let firstImport = try await importer.importTranscripts(path: transcriptURL.path)
        let secondImport = try await importer.importTranscripts(path: transcriptURL.path)

        #expect(firstImport.eventsAppended == 7)
        #expect(firstImport.duplicateEvents == 0)
        #expect(firstImport.threads == 1)
        #expect(firstImport.turns == 1)
        #expect(firstImport.prompts == 1)
        #expect(firstImport.plans == 1)
        #expect(firstImport.commands == 1)
        #expect(firstImport.reasoningSummaries == 1)
        #expect(firstImport.fileChanges == 1)
        #expect(secondImport.eventsAppended == 0)
        #expect(secondImport.duplicateEvents == 7)
    }

    @Test
    func liveImportConsumesCompletedAppendsAndReplaysIdempotently() async throws {
        let fixture = try StoreFixture()
        defer { fixture.remove() }
        let client: any ProvenanceEngineContracts.ProvenanceEngineClient =
            try ProvenanceEngineClientFactory().sqliteClient(databaseURL: fixture.databaseURL)
        let transcriptURL = fixture.directoryURL.appendingPathComponent("codex-session.jsonl")
        FileManager.default.createFile(atPath: transcriptURL.path, contents: Data())
        let lines = try Self.codexTranscriptFixtureLines()
        let importer = CLIProvenanceCodexTranscriptImporter(client: client)
        var state = CLIProvenanceCodexTranscriptImporter.LiveImportState()

        try Self.appendText(lines[0] + "\n", to: transcriptURL)
        let metadataImport = try await importer.importLiveTranscriptAppend(at: transcriptURL, state: &state)
        #expect(metadataImport.consumedLines == 1)
        #expect(metadataImport.fileReport.threads == 1)
        #expect(metadataImport.metadataAvailable)

        try Self.appendText(lines[1], to: transcriptURL)
        let partialImport = try await importer.importLiveTranscriptAppend(at: transcriptURL, state: &state)
        #expect(partialImport.consumedLines == 0)
        #expect(partialImport.retainedPartialLine)

        try Self.appendText("\n" + lines[2] + "\n", to: transcriptURL)
        let turnImport = try await importer.importLiveTranscriptAppend(at: transcriptURL, state: &state)
        #expect(turnImport.consumedLines == 2)
        #expect(turnImport.fileReport.turns == 1)
        #expect(turnImport.fileReport.prompts == 1)

        try Self.appendText(lines[3...].joined(separator: "\n") + "\n", to: transcriptURL)
        let evidenceImport = try await importer.importLiveTranscriptAppend(at: transcriptURL, state: &state)
        #expect(evidenceImport.consumedLines == 4)
        #expect(evidenceImport.fileReport.plans == 1)
        #expect(evidenceImport.fileReport.commands == 1)
        #expect(evidenceImport.fileReport.reasoningSummaries == 1)
        #expect(evidenceImport.fileReport.fileChanges == 1)

        let replay = try await importer.importTranscripts(path: transcriptURL.path)
        #expect(replay.eventsAppended == 0)
        #expect(replay.duplicateEvents == 7)
    }

    @Test
    func hookAndLiveTranscriptEvidenceShareOneFactualTurn() async throws {
        let fixture = try StoreFixture()
        defer { fixture.remove() }
        let client: any ProvenanceEngineContracts.ProvenanceEngineClient =
            try ProvenanceEngineClientFactory().sqliteClient(databaseURL: fixture.databaseURL)
        let recorder = WorkProvenanceCodingAgentEvidenceRecorder(
            client: client,
            gitInspector: EmptyGitInspector()
        )
        let transcriptURL = fixture.directoryURL.appendingPathComponent("codex-session.jsonl")
        let lines = try Self.codexTranscriptFixtureLines()
        try (lines.joined(separator: "\n") + "\n").write(to: transcriptURL, atomically: true, encoding: .utf8)

        let timestamp = Date(timeIntervalSince1970: 1_787_325_601)
        let record = AgentChatSessionRecord(
            sessionID: "codex-session-1",
            agentKind: .codex,
            workspaceID: "workspace-1",
            surfaceID: "surface-1",
            workingDirectory: "/tmp/provenance-transcript-fixture",
            transcriptPath: transcriptURL.path,
            state: .working(since: timestamp),
            lastActivityAt: timestamp,
            title: nil,
            pid: 123
        )
        let hookEvent = WorkstreamEvent(
            sessionId: "codex-session-1",
            hookEventName: .userPromptSubmit,
            source: "codex",
            workspaceId: "workspace-1",
            surfaceId: "surface-1",
            transcriptPath: transcriptURL.path,
            cwd: "/tmp/provenance-transcript-fixture",
            context: WorkstreamContext(lastUserMessage: "Please add transcript ingestion."),
            requestId: "hook-request-1",
            ppid: 123,
            receivedAt: timestamp,
            extraFieldsJSON: #"{"turn_id":"turn-1"}"#
        )

        try await recorder.recordHookUserPromptSubmit(
            record: record,
            event: hookEvent,
            stableWorkspaceID: UUID()
        )

        let importer = CLIProvenanceCodexTranscriptImporter(client: client)
        var state = CLIProvenanceCodexTranscriptImporter.LiveImportState()
        _ = try await importer.importLiveTranscriptAppend(at: transcriptURL, state: &state)

        let projection = try await client.factualSessionProjection(
            ProvenanceFactualSessionProjectionRequest(sessionID: "codex-session-1")
        )
        let snapshot = try #require(projection.snapshot)
        #expect(snapshot.turns.count == 1)
        let turn = try #require(snapshot.latestTurn)
        #expect(turn.turn.providerTurnID == "turn-1")
        #expect(turn.submittedPrompt?.text == "Please add transcript ingestion.")
    }

    private static func writeCodexTranscriptFixture(to url: URL) throws {
        let lines = try codexTranscriptFixtureLines()
        try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
    }

    private static func appendText(_ text: String, to url: URL) throws {
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        handle.seekToEndOfFile()
        handle.write(Data(text.utf8))
    }

    private static func codexTranscriptFixtureLines() throws -> [String] {
        let patch = [
            "*** Begin Patch",
            "*** Add File: Sources/Importer.swift",
            "+struct Importer {}",
            "*** End Patch"
        ].joined(separator: "\n")
        return [
            try codexTranscriptLine(
                ordinal: 0,
                type: "session_meta",
                timestamp: "2026-08-21T10:00:00Z",
                payload: [
                    "session_id": "codex-session-1",
                    "id": "codex-session-1",
                    "timestamp": "2026-08-21T10:00:00Z",
                    "cwd": "/tmp/provenance-transcript-fixture",
                    "originator": "codex-tui",
                    "source": "cli",
                    "model_provider": "openai"
                ]
            ),
            try codexTranscriptLine(
                ordinal: 1,
                type: "response_item",
                timestamp: "2026-08-21T10:00:01Z",
                payload: [
                    "type": "message",
                    "role": "user",
                    "content": [
                        [
                            "type": "input_text",
                            "text": "Please add transcript ingestion."
                        ]
                    ]
                ]
            ),
            try codexTranscriptLine(
                ordinal: 2,
                type: "event_msg",
                timestamp: "2026-08-21T10:00:02Z",
                payload: [
                    "type": "task_started",
                    "turn_id": "turn-1",
                    "started_at": 1_787_325_602
                ]
            ),
            try codexTranscriptLine(
                ordinal: 3,
                type: "response_item",
                timestamp: "2026-08-21T10:00:03Z",
                payload: [
                    "type": "function_call",
                    "name": "update_plan",
                    "call_id": "call-plan-1",
                    "internal_chat_message_metadata_passthrough": [
                        "turn_id": "turn-1"
                    ],
                    "arguments": #"{"plan":[{"step":"Inspect transcripts","status":"completed"},{"step":"Append evidence","status":"in_progress"}]}"#
                ]
            ),
            try codexTranscriptLine(
                ordinal: 4,
                type: "event_msg",
                timestamp: "2026-08-21T10:00:04Z",
                payload: [
                    "type": "item_completed",
                    "thread_id": "codex-session-1",
                    "turn_id": "turn-1",
                    "started_at_ms": 1_787_325_603_000,
                    "completed_at_ms": 1_787_325_604_000,
                    "item": [
                        "type": "CommandExecution",
                        "id": "cmd-1",
                        "command": ["swift", "test", "--filter", "TranscriptImporter"],
                        "cwd": "/tmp/provenance-transcript-fixture",
                        "status": "completed",
                        "exit_code": 0
                    ]
                ]
            ),
            try codexTranscriptLine(
                ordinal: 5,
                type: "event_msg",
                timestamp: "2026-08-21T10:00:05Z",
                payload: [
                    "type": "item_completed",
                    "thread_id": "codex-session-1",
                    "turn_id": "turn-1",
                    "item": [
                        "type": "Reasoning",
                        "id": "reasoning-1",
                        "summary_text": ["Mapped transcript facts to canonical PE evidence."]
                    ]
                ]
            ),
            try codexTranscriptLine(
                ordinal: 6,
                type: "response_item",
                timestamp: "2026-08-21T10:00:06Z",
                payload: [
                    "type": "custom_tool_call",
                    "name": "apply_patch",
                    "call_id": "patch-1",
                    "status": "completed",
                    "internal_chat_message_metadata_passthrough": [
                        "turn_id": "turn-1"
                    ],
                    "input": patch
                ]
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

    private struct StoreFixture {
        let directoryURL: URL
        let databaseURL: URL

        init() throws {
            directoryURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("bmux-codex-transcript-importer-\(UUID().uuidString)", isDirectory: true)
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

    private struct EmptyGitInspector: WorkProvenanceGitInspecting {
        func snapshot(for directory: String) async -> WorkProvenanceGitSnapshot? {
            nil
        }
    }
}
