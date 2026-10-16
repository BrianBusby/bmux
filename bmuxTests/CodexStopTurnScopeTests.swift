import Foundation
import Testing

@Suite(.timeLimit(.minutes(1)))
struct CodexStopTurnScopeTests {
    @Test func doesNotKeepOldTranscriptErrorAfterSuccessfulTurn() async throws {
        let fixture = try CodexStopHookFixture()
        let root = fixture.root
        let workspaceId = fixture.workspaceID
        let sessionId = "codex-session-success"
        let transcriptURL = root.appendingPathComponent("rollout-\(sessionId).jsonl")
        try """
        {"timestamp":"2026-04-25T07:55:29.462Z","type":"session_meta","payload":{"id":"\(sessionId)","cwd":"\(root.path)"}}
        {"timestamp":"2026-04-25T07:55:29.803Z","type":"event_msg","payload":{"type":"error","message":"You've hit your usage limit.","codex_error_info":"usage_limit_exceeded"}}
        {"timestamp":"2026-04-25T07:56:00.000Z","type":"response_item","payload":{"type":"message","role":"assistant","content":[{"type":"output_text","text":"Done"}],"phase":"final_answer"}}
        {"timestamp":"2026-04-25T07:56:00.100Z","type":"event_msg","payload":{"type":"task_complete","turn_id":"turn-2","last_agent_message":"Done"}}
        """.write(to: transcriptURL, atomically: true, encoding: .utf8)

        let hookInput = """
        {"session_id":"\(sessionId)","turn_id":"turn-2","transcript_path":"\(transcriptURL.path)","cwd":"\(root.path)","hook_event_name":"Stop","model":"gpt-5.5","permission_mode":"default","stop_hook_active":false,"last_assistant_message":"Done"}
        """
        let commands = try await fixture.run(input: hookInput)

        #expect(
            commands.contains { command in
                command.contains("set_status codex Idle") &&
                    command.contains("--icon=pause.circle.fill") &&
                    command.contains("--tab=\(workspaceId)")
            },
            "Expected successful Codex turn to report Idle, saw \(commands)"
        )
        #expect(
            !commands.contains { $0.contains("set_status codex Codex rate limit") || $0.contains("#FF453A") },
            "Did not expect stale transcript error status, saw \(commands)"
        )
        #expect(
            !commands.contains { command in
                command.contains("notify_target") &&
                    (command.contains("Rate limit") || command.contains("Error") || command.contains("#FF453A"))
            },
            "Did not expect stale failure notification, saw \(commands)"
        )
    }

    @Test func prefersExplicitErrorPayloadOverHealthyTranscript() async throws {
        let fixture = try CodexStopHookFixture()
        let root = fixture.root
        let workspaceId = fixture.workspaceID
        let surfaceId = fixture.surfaceID
        let sessionId = "codex-session-payload-beats-transcript"
        let transcriptURL = root.appendingPathComponent("rollout-\(sessionId).jsonl")
        try """
        {"timestamp":"2026-04-25T07:55:29.462Z","type":"session_meta","payload":{"id":"\(sessionId)","cwd":"\(root.path)"}}
        {"timestamp":"2026-04-25T07:56:00.000Z","type":"response_item","payload":{"type":"message","role":"assistant","content":[{"type":"output_text","text":"Done"}],"phase":"final_answer"}}
        {"timestamp":"2026-04-25T07:56:00.100Z","type":"event_msg","payload":{"type":"task_complete","turn_id":"turn-payload-error","last_agent_message":"Done"}}
        """.write(to: transcriptURL, atomically: true, encoding: .utf8)

        let hookInput = """
        {"session_id":"\(sessionId)","turn_id":"turn-payload-error","transcript_path":"\(transcriptURL.path)","cwd":"\(root.path)","hook_event_name":"Stop","model":"gpt-5.5","permission_mode":"default","stop_hook_active":false,"last_assistant_message":"Partial answer","type":"error","message":"Try again later."}
        """
        let commands = try await fixture.run(input: hookInput)

        #expect(
            commands.contains { command in
                command.contains("notify_target_async \(workspaceId) \(surfaceId) Codex|Error|Try again later.")
            },
            "Expected payload error notification to beat healthy transcript, saw \(commands)"
        )
        #expect(
            commands.contains { command in
                command.contains("set_status codex Codex error") &&
                    command.contains("--icon=exclamationmark.triangle.fill") &&
                    command.contains("--color=#FF453A") &&
                    command.contains("--priority=100") &&
                    command.contains("--tab=\(workspaceId)")
            },
            "Expected payload error status to beat healthy transcript, saw \(commands)"
        )
    }

    @Test func doesNotSynthesizeNoFinalResponseAfterScopedAssistantMessage() async throws {
        let fixture = try CodexStopHookFixture()
        let root = fixture.root
        let workspaceId = fixture.workspaceID
        let sessionId = "codex-session-scoped-assistant"
        let transcriptURL = root.appendingPathComponent("rollout-\(sessionId).jsonl")
        try """
        {"timestamp":"2026-04-25T07:55:29.462Z","type":"session_meta","payload":{"id":"\(sessionId)","cwd":"\(root.path)"}}
        {"timestamp":"2026-04-25T07:55:29.500Z","type":"event_msg","payload":{"type":"task_started","turn_id":"turn-scoped-assistant","started_at":1777107522}}
        {"timestamp":"2026-04-25T07:55:29.600Z","type":"response_item","payload":{"type":"message","role":"assistant","content":[{"type":"output_text","text":"Done"}]}}
        {"timestamp":"2026-04-25T07:55:29.804Z","type":"event_msg","payload":{"type":"task_complete","turn_id":"turn-scoped-assistant","last_agent_message":null}}
        """.write(to: transcriptURL, atomically: true, encoding: .utf8)

        let hookInput = """
        {"session_id":"\(sessionId)","turn_id":"turn-scoped-assistant","transcript_path":"\(transcriptURL.path)","cwd":"\(root.path)","hook_event_name":"Stop","model":"gpt-5.5","permission_mode":"default","stop_hook_active":false,"last_assistant_message":null}
        """
        let commands = try await fixture.run(input: hookInput)

        #expect(
            commands.contains { command in
                command.contains("set_status codex Idle") &&
                    command.contains("--tab=\(workspaceId)")
            },
            "Expected scoped assistant reply to suppress no-final-response error, saw \(commands)"
        )
        #expect(
            !commands.contains { command in
                command.contains("Codex ended before sending a final response") || command.contains("--color=#FF453A")
            },
            "Did not expect no-final-response error after scoped assistant reply, saw \(commands)"
        )
    }

    @Test func ignoresUnscopedTranscriptErrorWithoutTurnEvidence() async throws {
        let fixture = try CodexStopHookFixture()
        let root = fixture.root
        let workspaceId = fixture.workspaceID
        let sessionId = "codex-session-stale-unscoped-error"
        let transcriptURL = root.appendingPathComponent("rollout-\(sessionId).jsonl")
        try """
        {"timestamp":"2026-04-25T07:55:29.462Z","type":"session_meta","payload":{"id":"\(sessionId)","cwd":"\(root.path)"}}
        {"timestamp":"2026-04-25T07:55:29.803Z","type":"event_msg","payload":{"type":"error","message":"Stream disconnected before completion.","codex_error_info":"response_stream_disconnected"}}
        """.write(to: transcriptURL, atomically: true, encoding: .utf8)

        let hookInput = """
        {"session_id":"\(sessionId)","turn_id":"turn-current","transcript_path":"\(transcriptURL.path)","cwd":"\(root.path)","hook_event_name":"Stop","model":"gpt-5.5","permission_mode":"default","stop_hook_active":false,"last_assistant_message":null}
        """
        let commands = try await fixture.run(input: hookInput)

        #expect(
            commands.contains { command in
                command.contains("set_status codex Idle") &&
                    command.contains("--tab=\(workspaceId)")
            },
            "Expected stale unscoped error to leave Codex idle, saw \(commands)"
        )
        #expect(
            !commands.contains { command in
                command.contains("set_status codex Codex network error") || command.contains("--color=#FF453A")
            },
            "Did not expect stale unscoped error status, saw \(commands)"
        )
    }
}
