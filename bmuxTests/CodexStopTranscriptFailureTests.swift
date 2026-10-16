import Foundation
import Testing

@Suite(.timeLimit(.minutes(1)))
struct CodexStopTranscriptFailureTests {
    @Test func setsRateLimitStatusFromTranscript() async throws {
        let fixture = try CodexStopHookFixture()
        let root = fixture.root
        let workspaceId = fixture.workspaceID
        let surfaceId = fixture.surfaceID
        let sessionId = "codex-session-error"
        let transcriptDirectory = try fixture.sessionDirectory()
        let transcriptURL = transcriptDirectory.appendingPathComponent("rollout-\(sessionId).jsonl")
        try """
        {"timestamp":"2026-04-25T07:55:29.462Z","type":"session_meta","payload":{"id":"\(sessionId)","cwd":"\(root.path)"}}
        {"timestamp":"2026-04-25T07:55:29.799Z","type":"event_msg","payload":{"type":"token_count","info":null,"rate_limits":{"credits":{"has_credits":false,"unlimited":false,"balance":"0"}}}}
        {"timestamp":"2026-04-25T07:55:29.803Z","type":"event_msg","payload":{"type":"error","message":"You've hit your usage limit. Visit https://chatgpt.com/codex/settings/usage to purchase more credits or try again at 4:05 AM.","codex_error_info":"usage_limit_exceeded"}}
        {"timestamp":"2026-04-25T07:55:29.804Z","type":"event_msg","payload":{"type":"task_complete","turn_id":"turn-1","last_agent_message":null}}
        """.write(to: transcriptURL, atomically: true, encoding: .utf8)

        let hookInput = """
        {"session_id":"\(sessionId)","turn_id":"turn-1","cwd":"\(root.path)","hook_event_name":"Stop","model":"gpt-5.5","permission_mode":"default","stop_hook_active":false,"last_assistant_message":null}
        """
        let commands = try await fixture.run(input: hookInput)

        #expect(
            commands.contains { command in
                command.contains("notify_target_async \(workspaceId) \(surfaceId) Codex|Rate limit|")
            },
            "Expected Codex failure notification, saw \(commands)"
        )
        #expect(
            commands.contains { command in
                command.contains("set_status codex Codex rate limit") &&
                    command.contains("--icon=exclamationmark.triangle.fill") &&
                    command.contains("--color=#FF453A") &&
                    command.contains("--priority=100") &&
                    command.contains("--tab=\(workspaceId)")
            },
            "Expected high-priority Codex rate limit status, saw \(commands)"
        )
    }

    @Test func treatsTypedCodexErrorEventAsFailure() async throws {
        let fixture = try CodexStopHookFixture()
        let root = fixture.root
        let workspaceId = fixture.workspaceID
        let surfaceId = fixture.surfaceID
        let sessionId = "codex-session-typed-error"
        let transcriptURL = root.appendingPathComponent("rollout-\(sessionId).jsonl")
        try """
        {"timestamp":"2026-04-25T07:55:29.462Z","type":"session_meta","payload":{"id":"\(sessionId)","cwd":"\(root.path)"}}
        {"timestamp":"2026-04-25T07:55:29.803Z","type":"event_msg","payload":{"type":"error","message":"Try again later.","codex_error_info":"server_overloaded"}}
        {"timestamp":"2026-04-25T07:55:29.804Z","type":"event_msg","payload":{"type":"task_complete","turn_id":"turn-3","last_agent_message":null}}
        """.write(to: transcriptURL, atomically: true, encoding: .utf8)

        let hookInput = """
        {"session_id":"\(sessionId)","turn_id":"turn-3","transcript_path":"\(transcriptURL.path)","cwd":"\(root.path)","hook_event_name":"Stop","model":"gpt-5.5","permission_mode":"default","stop_hook_active":false,"last_assistant_message":null}
        """
        let commands = try await fixture.run(input: hookInput)

        #expect(
            commands.contains { command in
                command.contains("notify_target_async \(workspaceId) \(surfaceId) Codex|Error|Try again later.")
            },
            "Expected typed Codex error notification, saw \(commands)"
        )
        #expect(
            commands.contains { command in
                command.contains("set_status codex Codex error") &&
                    command.contains("--icon=exclamationmark.triangle.fill") &&
                    command.contains("--color=#FF453A") &&
                    command.contains("--priority=100") &&
                    command.contains("--tab=\(workspaceId)")
            },
            "Expected high-priority Codex error status, saw \(commands)"
        )
    }

    @Test func fallsBackToDiscoveredTranscriptWhenProvidedPathUnavailable() async throws {
        let fixture = try CodexStopHookFixture()
        let root = fixture.root
        let workspaceId = fixture.workspaceID
        let surfaceId = fixture.surfaceID
        let sessionId = "codex-session-stale-provided-path"
        let transcriptDirectory = try fixture.sessionDirectory()
        let discoveredTranscriptURL = transcriptDirectory.appendingPathComponent("rollout-\(sessionId).jsonl")
        try """
        {"timestamp":"2026-04-25T07:55:29.462Z","type":"session_meta","payload":{"id":"\(sessionId)","cwd":"\(root.path)"}}
        {"timestamp":"2026-04-25T07:55:29.803Z","type":"event_msg","payload":{"type":"error","turn_id":"turn-stale-path","message":"Stream disconnected before completion.","codex_error_info":"response_stream_disconnected"}}
        {"timestamp":"2026-04-25T07:55:29.804Z","type":"event_msg","payload":{"type":"task_complete","turn_id":"turn-stale-path","last_agent_message":null}}
        """.write(to: discoveredTranscriptURL, atomically: true, encoding: .utf8)

        let unavailableTranscriptURL = root.appendingPathComponent("missing-\(sessionId).jsonl")
        let hookInput = """
        {"session_id":"\(sessionId)","turn_id":"turn-stale-path","transcript_path":"\(unavailableTranscriptURL.path)","cwd":"\(root.path)","hook_event_name":"Stop","model":"gpt-5.5","permission_mode":"default","stop_hook_active":false,"last_assistant_message":null}
        """
        let commands = try await fixture.run(input: hookInput)

        #expect(
            commands.contains { command in
                command.contains("notify_target_async \(workspaceId) \(surfaceId) Codex|Network error|Stream disconnected before completion.")
            },
            "Expected discovered transcript failure notification, saw \(commands)"
        )
        #expect(
            commands.contains { command in
                command.contains("set_status codex Codex network error") &&
                    command.contains("--icon=exclamationmark.triangle.fill") &&
                    command.contains("--color=#FF453A") &&
                    command.contains("--priority=100") &&
                    command.contains("--tab=\(workspaceId)")
            },
            "Expected discovered transcript failure status, saw \(commands)"
        )
    }

    @Test func treatsCompletedTurnWithoutAssistantAsFailure() async throws {
        let fixture = try CodexStopHookFixture()
        let root = fixture.root
        let workspaceId = fixture.workspaceID
        let surfaceId = fixture.surfaceID
        let sessionId = "codex-session-no-final"
        let transcriptURL = root.appendingPathComponent("rollout-\(sessionId).jsonl")
        try """
        {"timestamp":"2026-04-25T07:55:29.462Z","type":"session_meta","payload":{"id":"\(sessionId)","cwd":"\(root.path)"}}
        {"timestamp":"2026-04-25T07:55:29.600Z","type":"response_item","payload":{"type":"message","role":"assistant","content":[{"type":"output_text","text":"Previous turn completed."}]}}
        {"timestamp":"2026-04-25T07:55:29.804Z","type":"event_msg","payload":{"type":"task_complete","turn_id":"turn-no-final","last_agent_message":null}}
        """.write(to: transcriptURL, atomically: true, encoding: .utf8)

        let hookInput = """
        {"session_id":"\(sessionId)","turn_id":"turn-no-final","transcript_path":"\(transcriptURL.path)","cwd":"\(root.path)","hook_event_name":"Stop","model":"gpt-5.5","permission_mode":"default","stop_hook_active":false,"last_assistant_message":null}
        """
        let commands = try await fixture.run(input: hookInput)

        #expect(
            commands.contains { command in
                command.contains("notify_target_async \(workspaceId) \(surfaceId) Codex|Error|Codex ended before sending a final response")
            },
            "Expected no-final-response notification, saw \(commands)"
        )
        #expect(
            commands.contains { command in
                command.contains("set_status codex Codex error") &&
                    command.contains("--icon=exclamationmark.triangle.fill") &&
                    command.contains("--color=#FF453A") &&
                    command.contains("--priority=100") &&
                    command.contains("--tab=\(workspaceId)")
            },
            "Expected high-priority Codex error status, saw \(commands)"
        )
    }
}
