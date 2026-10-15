import Foundation
import Testing
@MainActor
struct ClaudeSessionPhaseTests {
    @Test
    func claudeStopFromPreviousSessionDoesNotClobberClearRunningStatus() async throws {
        let context = try ClaudeSessionPhaseFixture(cli: BundledCLITestSupport.bundledCLIPath(for: ClaudeSessionPhaseFixture.self))
        defer { context.cleanup() }

        // A throwing, joined run retains each original no-timeout assertion.
        let oldStart = try await context.run(
            arguments: ["hooks", "claude", "session-start"],
            standardInput: #"{"session_id":"old-session","cwd":"\#(context.root.path)","hook_event_name":"SessionStart"}"#
        )
        #expect(oldStart.status == 0, "\(oldStart.stderr)")

        let clearStart = try await context.run(
            arguments: ["hooks", "claude", "session-start"],
            standardInput: #"{"session_id":"clear-session","source":"clear","cwd":"\#(context.root.path)","hook_event_name":"SessionStart"}"#
        )
        #expect(clearStart.status == 0, "\(clearStart.stderr)")

        let lateOldStart = try await context.run(
            arguments: ["hooks", "claude", "session-start"],
            standardInput: #"{"session_id":"old-session","source":"startup","cwd":"\#(context.root.path)","hook_event_name":"SessionStart"}"#
        )
        #expect(lateOldStart.status == 0, "\(lateOldStart.stderr)")

        let staleStop = try await context.run(
            arguments: ["hooks", "claude", "stop"],
            standardInput: #"{"session_id":"old-session","cwd":"\#(context.root.path)","hook_event_name":"Stop","last_assistant_message":"old turn finished late"}"#
        )
        #expect(staleStop.status == 0, "\(staleStop.stderr)")

        #expect(
            context.commands.contains {
                $0.hasPrefix("set_status claude_code Running --icon=bolt.fill --color=#4C8DFF --tab=\(context.workspaceId)")
                    && $0.contains("--panel=\(context.surfaceId)")
            },
            "Expected clear SessionStart to mark Claude running, saw \(context.commands)"
        )
        #expect(
            !context.commands.contains {
                $0.hasPrefix("set_status claude_code Idle ") && $0.contains("--tab=\(context.workspaceId)")
            },
            "Expected stale Stop from old session not to clobber the clear session, saw \(context.commands)"
        )
        let resumeBindingRequests = context.commands.compactMap { command -> [String: Any]? in
            guard let payload = try? JSONSerialization.jsonObject(with: Data(command.utf8)) as? [String: Any],
                  payload["method"] as? String == "surface.resume.set" else {
                return nil
            }
            return payload["params"] as? [String: Any]
        }
        #expect(resumeBindingRequests.count == 1)
        #expect(resumeBindingRequests.first?["checkpoint_id"] as? String == "clear-session")
        #expect(resumeBindingRequests.first?["auto_resume"] as? Bool == true)
    }

    @Test
    func claudePromptSubmitFromNewSessionCanReplaceStoppedSession() async throws {
        let context = try ClaudeSessionPhaseFixture(cli: BundledCLITestSupport.bundledCLIPath(for: ClaudeSessionPhaseFixture.self))
        defer { context.cleanup() }

        // A throwing, joined run retains each original no-timeout assertion.
        let oldStart = try await context.run(
            arguments: ["hooks", "claude", "session-start"],
            standardInput: #"{"session_id":"old-session","cwd":"\#(context.root.path)","hook_event_name":"SessionStart"}"#
        )
        #expect(oldStart.status == 0, "\(oldStart.stderr)")

        let oldPrompt = try await context.run(
            arguments: ["hooks", "claude", "prompt-submit"],
            standardInput: #"{"session_id":"old-session","turn_id":"turn-1","cwd":"\#(context.root.path)","hook_event_name":"PromptSubmit"}"#
        )
        #expect(oldPrompt.status == 0, "\(oldPrompt.stderr)")

        let oldStop = try await context.run(
            arguments: ["hooks", "claude", "stop"],
            standardInput: #"{"session_id":"old-session","turn_id":"turn-1","cwd":"\#(context.root.path)","hook_event_name":"Stop","last_assistant_message":"old turn finished"}"#
        )
        #expect(oldStop.status == 0, "\(oldStop.stderr)")

        let newStart = try await context.run(
            arguments: ["hooks", "claude", "session-start"],
            standardInput: #"{"session_id":"new-session","source":"startup","cwd":"\#(context.root.path)","hook_event_name":"SessionStart"}"#
        )
        #expect(newStart.status == 0, "\(newStart.stderr)")

        let newPromptStart = context.commands.count
        let newPrompt = try await context.run(
            arguments: ["hooks", "claude", "prompt-submit"],
            standardInput: #"{"session_id":"new-session","turn_id":"turn-1","cwd":"\#(context.root.path)","hook_event_name":"PromptSubmit"}"#
        )
        #expect(newPrompt.status == 0, "\(newPrompt.stderr)")

        let newPromptCommands = Array(context.commands.dropFirst(newPromptStart))
        #expect(
            newPromptCommands.contains {
                $0.hasPrefix("set_status claude_code Running --icon=bolt.fill --color=#4C8DFF --tab=\(context.workspaceId)")
            },
            "Expected a new Claude session to replace a stopped idle owner on prompt-submit, saw \(newPromptCommands)"
        )
    }
}
