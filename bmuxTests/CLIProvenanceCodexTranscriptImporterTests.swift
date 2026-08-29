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

        #expect(firstImport.eventsAppended == 8)
        #expect(firstImport.duplicateEvents == 0)
        #expect(firstImport.threads == 1)
        #expect(firstImport.turns == 1)
        #expect(firstImport.prompts == 1)
        #expect(firstImport.plans == 1)
        #expect(firstImport.commands == 1)
        #expect(firstImport.reasoningSummaries == 1)
        #expect(firstImport.assistantMessages == 1)
        #expect(firstImport.fileChanges == 1)
        #expect(secondImport.eventsAppended == 0)
        #expect(secondImport.duplicateEvents == 8)
        let projection = try await Self.factualProjection(client: client, sessionID: "codex-session-1")
        #expect(projection.latestTurn?.assistantMessages.count == 1)
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
        #expect(evidenceImport.consumedLines == 5)
        #expect(evidenceImport.fileReport.plans == 1)
        #expect(evidenceImport.fileReport.commands == 1)
        #expect(evidenceImport.fileReport.reasoningSummaries == 1)
        #expect(evidenceImport.fileReport.assistantMessages == 1)
        #expect(evidenceImport.fileReport.fileChanges == 1)

        let replay = try await importer.importTranscripts(path: transcriptURL.path)
        #expect(replay.eventsAppended == 0)
        #expect(replay.duplicateEvents == 8)
    }

    @Test
    func liveImportConvergesLongRunningCodexTurnAcrossAppendCycles() async throws {
        let fixture = try StoreFixture()
        defer { fixture.remove() }
        let client: any ProvenanceEngineContracts.ProvenanceEngineClient =
            try ProvenanceEngineClientFactory().sqliteClient(databaseURL: fixture.databaseURL)
        let transcriptURL = fixture.directoryURL.appendingPathComponent("codex-long-session.jsonl")
        FileManager.default.createFile(atPath: transcriptURL.path, contents: Data())
        let lines = try Self.longRunningCodexTranscriptFixtureLines()
        let importer = CLIProvenanceCodexTranscriptImporter(client: client)
        var state = CLIProvenanceCodexTranscriptImporter.LiveImportState()

        try Self.appendText(lines[0] + "\n", to: transcriptURL)
        let metadataImport = try await importer.importLiveTranscriptAppend(at: transcriptURL, state: &state)
        #expect(metadataImport.fileReport.threads == 1)
        let metadataProjection = try await Self.factualProjection(client: client, sessionID: "codex-long-session")
        #expect(metadataProjection.latestTurn == nil)

        try Self.appendText(lines[1...5].joined(separator: "\n") + "\n", to: transcriptURL)
        let firstEvidenceImport = try await importer.importLiveTranscriptAppend(at: transcriptURL, state: &state)
        #expect(firstEvidenceImport.fileReport.prompts == 1)
        #expect(firstEvidenceImport.fileReport.commands == 1)
        #expect(firstEvidenceImport.fileReport.reasoningSummaries == 1)
        let firstProjection = try await Self.factualProjection(client: client, sessionID: "codex-long-session")
        let firstTurn = try #require(firstProjection.latestTurn)
        #expect(firstTurn.turn.provider == "codex")
        #expect(firstTurn.turn.providerTurnID == "turn-long-1")
        #expect(firstTurn.turn.model == "gpt-5.5")
        #expect(firstTurn.turn.effort == "xhigh")
        #expect(firstTurn.submittedPrompt?.text == "Review this PR for evidence convergence.")
        #expect(firstTurn.completedCommands.count == 1)
        #expect(firstTurn.visibleReasoningSummaries.count == 1)
        #expect(firstProjection.providerThreadIdentities.map(\.providerThreadID) == ["codex-long-session"])

        try Self.appendText(lines[6], to: transcriptURL)
        let partialImport = try await importer.importLiveTranscriptAppend(at: transcriptURL, state: &state)
        #expect(partialImport.consumedLines == 0)
        #expect(partialImport.retainedPartialLine)

        try Self.appendText("\n" + lines[7...10].joined(separator: "\n") + "\n", to: transcriptURL)
        let laterEvidenceImport = try await importer.importLiveTranscriptAppend(at: transcriptURL, state: &state)
        #expect(laterEvidenceImport.fileReport.commands == 3)
        #expect(laterEvidenceImport.fileReport.reasoningSummaries == 2)
        let laterProjection = try await Self.factualProjection(client: client, sessionID: "codex-long-session")
        let laterTurn = try #require(laterProjection.latestTurn)
        #expect((laterProjection.revision ?? 0) > (firstProjection.revision ?? 0))
        #expect(laterProjection.turns.map(\.turn.providerTurnID) == ["turn-long-1"])
        #expect(laterTurn.completedCommands.count == 4)
        #expect(laterTurn.visibleReasoningSummaries.count == 3)
        #expect(laterTurn.submittedPrompt?.text == "Review this PR for evidence convergence.")

        let retry = try await importer.importLiveTranscriptAppend(at: transcriptURL, state: &state)
        #expect(retry.consumedLines == 0)
        let replay = try await importer.importTranscripts(path: transcriptURL.path)
        #expect(replay.eventsAppended == 0)
        let replayProjection = try await Self.factualProjection(client: client, sessionID: "codex-long-session")
        #expect(replayProjection.latestTurn?.completedCommands.count == 4)
        #expect(replayProjection.latestTurn?.visibleReasoningSummaries.count == 3)

        try Self.appendText(lines[11] + "\n", to: transcriptURL)
        _ = try await importer.importLiveTranscriptAppend(at: transcriptURL, state: &state)
        let completedProjection = try await Self.factualProjection(client: client, sessionID: "codex-long-session")
        #expect(completedProjection.latestTurn?.turn.status == "completed")

        try Self.appendText(lines[12] + "\n", to: transcriptURL)
        let finalOutputImport = try await importer.importLiveTranscriptAppend(at: transcriptURL, state: &state)
        #expect(finalOutputImport.fileReport.assistantMessages == 1)
        let finalProjection = try await Self.factualProjection(client: client, sessionID: "codex-long-session")
        #expect(finalProjection.latestTurn?.assistantMessages.count == 1)
    }

    @Test
    func promptAfterCompletedTurnLinksToNextProviderTurn() async throws {
        let fixture = try StoreFixture()
        defer { fixture.remove() }
        let client: any ProvenanceEngineContracts.ProvenanceEngineClient =
            try ProvenanceEngineClientFactory().sqliteClient(databaseURL: fixture.databaseURL)
        let transcriptURL = fixture.directoryURL.appendingPathComponent("codex-two-turn-session.jsonl")
        FileManager.default.createFile(atPath: transcriptURL.path, contents: Data())
        let lines = try Self.twoTurnCodexTranscriptFixtureLines()
        let importer = CLIProvenanceCodexTranscriptImporter(client: client)
        var state = CLIProvenanceCodexTranscriptImporter.LiveImportState()

        try Self.appendText(lines[0...3].joined(separator: "\n") + "\n", to: transcriptURL)
        let firstTurnImport = try await importer.importLiveTranscriptAppend(at: transcriptURL, state: &state)
        #expect(firstTurnImport.fileReport.prompts == 1)
        let firstProjection = try await Self.factualProjection(client: client, sessionID: "codex-two-turn-session")
        #expect(firstProjection.latestTurn?.turn.providerTurnID == "turn-1")
        #expect(firstProjection.latestTurn?.submittedPrompt?.text == "First prompt.")

        try Self.appendText(lines[4] + "\n", to: transcriptURL)
        let pendingPromptImport = try await importer.importLiveTranscriptAppend(at: transcriptURL, state: &state)
        #expect(pendingPromptImport.fileReport.prompts == 0)
        let pendingProjection = try await Self.factualProjection(client: client, sessionID: "codex-two-turn-session")
        #expect(pendingProjection.latestTurn?.turn.providerTurnID == "turn-1")
        #expect(pendingProjection.latestTurn?.submittedPrompt?.text == "First prompt.")

        try Self.appendText(lines[5] + "\n", to: transcriptURL)
        let secondTurnImport = try await importer.importLiveTranscriptAppend(at: transcriptURL, state: &state)
        #expect(secondTurnImport.fileReport.prompts == 1)

        let projection = try await Self.factualProjection(client: client, sessionID: "codex-two-turn-session")
        #expect(projection.turns.map(\.turn.providerTurnID) == ["turn-1", "turn-2"])
        let firstTurn = try #require(projection.turns.first { $0.turn.providerTurnID == "turn-1" })
        let secondTurn = try #require(projection.turns.first { $0.turn.providerTurnID == "turn-2" })
        #expect(firstTurn.submittedPrompt?.text == "First prompt.")
        #expect(secondTurn.submittedPrompt?.text == "Second prompt.")
        #expect(projection.latestTurn?.turn.providerTurnID == "turn-2")

        let replay = try await importer.importTranscripts(path: transcriptURL.path)
        #expect(replay.eventsAppended == 0)
    }

    @Test
    func liveImportKeepsTailStateWhenBatchParsingFails() async throws {
        let fixture = try StoreFixture()
        defer { fixture.remove() }
        let client: any ProvenanceEngineContracts.ProvenanceEngineClient =
            try ProvenanceEngineClientFactory().sqliteClient(databaseURL: fixture.databaseURL)
        let transcriptURL = fixture.directoryURL.appendingPathComponent("codex-session.jsonl")
        FileManager.default.createFile(atPath: transcriptURL.path, contents: Data())
        let importer = CLIProvenanceCodexTranscriptImporter(client: client)
        var state = CLIProvenanceCodexTranscriptImporter.LiveImportState()
        let lines = try Self.codexTranscriptFixtureLines()

        try Self.appendText(lines[0] + "\nnot-json\n", to: transcriptURL)
        do {
            _ = try await importer.importLiveTranscriptAppend(at: transcriptURL, state: &state)
            Issue.record("Expected invalid JSON to fail the live import batch")
        } catch {
            #expect(state.offset == 0)
            #expect(state.nextLineNumber == 1)
            #expect(state.metadata == nil)
            #expect(state.pendingLines.isEmpty)
        }

        try (lines[0] + "\n").write(to: transcriptURL, atomically: true, encoding: .utf8)
        let retry = try await importer.importLiveTranscriptAppend(at: transcriptURL, state: &state)
        #expect(retry.consumedLines == 1)
        #expect(retry.fileReport.threads == 1)
        #expect(state.metadata != nil)
    }

    @Test
    func liveImportKeepsTailStateWhenAppendFails() async throws {
        let fixture = try StoreFixture()
        defer { fixture.remove() }
        let transcriptURL = fixture.directoryURL.appendingPathComponent("codex-session.jsonl")
        let lines = try Self.codexTranscriptFixtureLines()
        try (lines[0] + "\n").write(to: transcriptURL, atomically: true, encoding: .utf8)
        let importer = CLIProvenanceCodexTranscriptImporter(client: FailingAppendClient())
        var state = CLIProvenanceCodexTranscriptImporter.LiveImportState()

        do {
            _ = try await importer.importLiveTranscriptAppend(at: transcriptURL, state: &state)
            Issue.record("Expected append failure to fail the live import batch")
        } catch {
            #expect(state.offset == 0)
            #expect(state.nextLineNumber == 1)
            #expect(state.metadata == nil)
            #expect(state.pendingLines.isEmpty)
        }
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

    private static func factualProjection(
        client: any ProvenanceEngineContracts.ProvenanceEngineClient,
        sessionID: String
    ) async throws -> ProvenanceFactualSessionProjectionSnapshot {
        let projection = try await client.factualSessionProjection(
            ProvenanceFactualSessionProjectionRequest(sessionID: sessionID)
        )
        return try #require(projection.snapshot)
    }

    static func codexTranscriptFixtureLines() throws -> [String] {
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
            ),
            try assistantFinalLine(ordinal: 7, timestamp: "2026-08-21T10:00:07Z", id: "assistant-final-1", text: "Final.", turnID: "turn-1")
        ]
    }

    private static func longRunningCodexTranscriptFixtureLines() throws -> [String] {
        return [
            try codexTranscriptLine(
                ordinal: 0,
                type: "session_meta",
                timestamp: "2026-08-22T10:00:00Z",
                payload: [
                    "session_id": "codex-long-session",
                    "id": "codex-long-session",
                    "timestamp": "2026-08-22T10:00:00Z",
                    "cwd": "/tmp/provenance-long-transcript-fixture",
                    "originator": "codex-tui",
                    "source": "cli",
                    "model_provider": "openai"
                ]
            ),
            try codexTranscriptLine(
                ordinal: 1,
                type: "response_item",
                timestamp: "2026-08-22T10:00:01Z",
                payload: [
                    "type": "message",
                    "role": "user",
                    "content": [
                        [
                            "type": "input_text",
                            "text": "Review this PR for evidence convergence."
                        ]
                    ]
                ]
            ),
            try codexTranscriptLine(
                ordinal: 2,
                type: "event_msg",
                timestamp: "2026-08-22T10:00:02Z",
                payload: [
                    "type": "task_started",
                    "turn_id": "turn-long-1",
                    "started_at": 1_787_412_002
                ]
            ),
            try codexTranscriptLine(
                ordinal: 3,
                type: "turn_context",
                timestamp: "2026-08-22T10:00:03Z",
                payload: [
                    "turn_id": "turn-long-1",
                    "cwd": "/tmp/provenance-long-transcript-fixture",
                    "model": "gpt-5.5",
                    "effort": "xhigh"
                ]
            ),
            try assistantCommentaryLine(
                ordinal: 4,
                id: "agent-message-1",
                text: "Inspecting the recently merged transcript ingestion path first."
            ),
            try commandLine(ordinal: 5, id: "cmd-1", command: ["rg", "CodexTranscriptImporter"]),
            try assistantCommentaryLine(
                ordinal: 6,
                id: "agent-message-2",
                text: "The first import pass reached PE; now checking whether later appends reuse the same turn."
            ),
            try commandLine(ordinal: 7, id: "cmd-2", command: ["gh", "pr", "view", "68"]),
            try commandLine(ordinal: 8, id: "cmd-3", command: ["node", "--test", "url-prefix.test.js"]),
            try assistantCommentaryLine(
                ordinal: 9,
                id: "agent-message-3",
                text: "The reproduction is confirmed; continuing into CODEOWNERS and Slack evidence."
            ),
            try commandLine(ordinal: 10, id: "cmd-4", command: ["rg", "CODEOWNERS"]),
            try codexTranscriptLine(
                ordinal: 11,
                type: "event_msg",
                timestamp: "2026-08-22T10:00:11Z",
                payload: [
                    "type": "task_complete",
                    "turn_id": "turn-long-1",
                    "completed_at": 1_787_412_011
                ]
            ),
            try assistantFinalLine(ordinal: 12, timestamp: "2026-08-22T10:00:12Z", id: "agent-final-1", text: "Final.")
        ]
    }

    private static func twoTurnCodexTranscriptFixtureLines() throws -> [String] {
        return [
            try codexTranscriptLine(
                ordinal: 0,
                type: "session_meta",
                timestamp: "2026-08-22T11:00:00Z",
                payload: [
                    "session_id": "codex-two-turn-session",
                    "id": "codex-two-turn-session",
                    "timestamp": "2026-08-22T11:00:00Z",
                    "cwd": "/tmp/provenance-two-turn-transcript-fixture",
                    "originator": "codex-tui",
                    "source": "cli",
                    "model_provider": "openai"
                ]
            ),
            try codexTranscriptLine(
                ordinal: 1,
                type: "response_item",
                timestamp: "2026-08-22T11:00:01Z",
                payload: [
                    "type": "message",
                    "role": "user",
                    "content": [
                        [
                            "type": "input_text",
                            "text": "First prompt."
                        ]
                    ]
                ]
            ),
            try codexTranscriptLine(
                ordinal: 2,
                type: "event_msg",
                timestamp: "2026-08-22T11:00:02Z",
                payload: [
                    "type": "task_started",
                    "turn_id": "turn-1",
                    "started_at": 1_787_415_602
                ]
            ),
            try codexTranscriptLine(
                ordinal: 3,
                type: "event_msg",
                timestamp: "2026-08-22T11:00:03Z",
                payload: [
                    "type": "task_complete",
                    "turn_id": "turn-1",
                    "completed_at": 1_787_415_603
                ]
            ),
            try codexTranscriptLine(
                ordinal: 4,
                type: "response_item",
                timestamp: "2026-08-22T11:00:04Z",
                payload: [
                    "type": "message",
                    "role": "user",
                    "content": [
                        [
                            "type": "input_text",
                            "text": "Second prompt."
                        ]
                    ]
                ]
            ),
            try codexTranscriptLine(
                ordinal: 5,
                type: "event_msg",
                timestamp: "2026-08-22T11:00:05Z",
                payload: [
                    "type": "task_started",
                    "turn_id": "turn-2",
                    "started_at": 1_787_415_605
                ]
            )
        ]
    }

    private static func assistantCommentaryLine(ordinal: Int, id: String, text: String) throws -> String {
        try codexTranscriptLine(
            ordinal: ordinal,
            type: "response_item",
            timestamp: String(format: "2026-08-22T10:00:%02dZ", ordinal),
            payload: [
                "type": "message",
                "role": "assistant",
                "phase": "commentary",
                "id": id,
                "internal_chat_message_metadata_passthrough": [
                    "turn_id": "turn-long-1"
                ],
                "content": [
                    [
                        "type": "output_text",
                        "text": text
                    ]
                ]
            ]
        )
    }

    private static func assistantFinalLine(ordinal: Int, timestamp: String, id: String, text: String, turnID: String? = nil) throws -> String {
        var payload: [String: Any] = [
            "type": "message", "role": "assistant", "phase": "final", "id": id,
            "content": [["type": "output_text", "text": text]]
        ]
        if let turnID { payload["internal_chat_message_metadata_passthrough"] = ["turn_id": turnID] }
        return try codexTranscriptLine(ordinal: ordinal, type: "response_item", timestamp: timestamp, payload: payload)
    }

    private static func commandLine(ordinal: Int, id: String, command: [String]) throws -> String {
        try codexTranscriptLine(
            ordinal: ordinal,
            type: "event_msg",
            timestamp: String(format: "2026-08-22T10:00:%02dZ", ordinal),
            payload: [
                "type": "item_completed",
                "thread_id": "codex-long-session",
                "turn_id": "turn-long-1",
                "started_at_ms": 1_787_412_000_000 + ordinal * 1_000,
                "completed_at_ms": 1_787_412_000_500 + ordinal * 1_000,
                "item": [
                    "type": "CommandExecution",
                    "id": id,
                    "command": command,
                    "cwd": "/tmp/provenance-long-transcript-fixture",
                    "status": "completed",
                    "exit_code": 0
                ]
            ]
        )
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

    private actor FailingAppendClient: ProvenanceEngineContracts.ProvenanceEngineClient {
        func health() async throws -> ProvenanceEngineContracts.ProvenanceEngineHealth {
            throw CancellationError()
        }

        func appendEvent(
            _ request: ProvenanceEngineContracts.ProvenanceAppendEventRequest
        ) async throws -> ProvenanceEngineContracts.ProvenanceAppendEventResponse {
            throw CancellationError()
        }

        func recordSessionLifecycle(
            _ request: ProvenanceEngineContracts.ProvenanceSessionLifecycleRequest
        ) async -> ProvenanceEngineContracts.ProvenanceSessionLifecycleResponse {
            ProvenanceEngineContracts.ProvenanceSessionLifecycleResponse(
                accepted: false,
                eventID: nil,
                sessionID: nil,
                relationshipSessionID: nil,
                externalIdentityID: nil
            )
        }

        func sessionTree(
            _ request: ProvenanceEngineContracts.ProvenanceSessionTreeRequest
        ) async throws -> ProvenanceEngineContracts.ProvenanceSessionTreeResponse {
            throw CancellationError()
        }

        func fileExplanation(
            _ request: ProvenanceEngineContracts.ProvenanceFileExplanationRequest
        ) async throws -> ProvenanceEngineContracts.ProvenanceFileExplanationResponse {
            throw CancellationError()
        }

        func worktrees(
            _ request: ProvenanceEngineContracts.ProvenanceWorktreeListRequest
        ) async throws -> ProvenanceEngineContracts.ProvenanceWorktreeListResponse {
            throw CancellationError()
        }

        func currentContext(
            _ request: ProvenanceEngineContracts.ProvenanceCurrentContextRequest
        ) async throws -> ProvenanceEngineContracts.ProvenanceCurrentContextResponse {
            throw CancellationError()
        }

        func workspaceDisplay(
            _ request: ProvenanceEngineContracts.ProvenanceWorkspaceDisplayRequest
        ) async throws -> ProvenanceEngineContracts.ProvenanceWorkspaceDisplayResponse {
            throw CancellationError()
        }

        func factualSessionProjection(
            _ request: ProvenanceEngineContracts.ProvenanceFactualSessionProjectionRequest
        ) async throws -> ProvenanceEngineContracts.ProvenanceFactualSessionProjectionResponse {
            throw CancellationError()
        }
    }
}
