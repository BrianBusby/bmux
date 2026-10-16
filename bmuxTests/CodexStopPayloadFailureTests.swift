import Foundation
import Testing

@Suite(.timeLimit(.minutes(1)))
struct CodexStopPayloadFailureTests {
    @Test(arguments: [
        (#"{"message":"Try again later.","codex_error_info":"server_overloaded"}"#, "Try again later.", "codex-session-payload-error", "turn-4"),
        (#"{"message":"Try again later.","codex_error_info":{"code":"server_overloaded","retryable":true}}"#, "Try again later.", "codex-session-structured-error", "turn-structured"),
        (#"{"message":"Try again later.","codexErrorInfo":"server_overloaded"}"#, "Try again later.", "codex-session-camel-error", "turn-5"),
        (#"{"type":"error","message":"Try again later."}"#, "Try again later.", "codex-session-hook-type-error", "turn-6"),
        (#"{"error":"quota exceeded"}"#, "quota exceeded", "codex-session-explicit-error-field", "turn-explicit-error"),
    ])
    func publishesPayloadFailure(fields: String, message: String, sessionID: String, turnID: String) async throws {
        let fixture = try CodexStopHookFixture()
        var input = try #require(JSONSerialization.jsonObject(with: Data(fields.utf8)) as? [String: Any])
        input.merge([
            "session_id": sessionID, "turn_id": turnID,
            "cwd": fixture.root.path, "hook_event_name": "Stop", "model": "gpt-5.5",
            "permission_mode": "default", "stop_hook_active": false, "last_assistant_message": NSNull(),
        ]) { current, _ in current }
        let commands = try await fixture.run(input: String(
            decoding: JSONSerialization.data(withJSONObject: input), as: UTF8.self
        ))
        #expect(commands.contains {
            $0.contains("notify_target_async \(fixture.workspaceID) \(fixture.surfaceID) Codex|Error|\(message)")
        }, "Expected payload error notification, saw \(commands)")
        #expect(commands.contains {
            $0.contains("set_status codex Codex error") &&
                $0.contains("--icon=exclamationmark.triangle.fill") &&
                $0.contains("--color=#FF453A") &&
                $0.contains("--priority=100") &&
                $0.contains("--tab=\(fixture.workspaceID)")
        }, "Expected high-priority Codex error status, saw \(commands)")
    }
}
