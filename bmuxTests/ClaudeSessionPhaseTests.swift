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

    @Test
    func claudeSessionStartRecordIsNotRestorableUntilPrompt() async throws {
        let context = try ClaudeSessionPhaseFixture(cli: BundledCLITestSupport.bundledCLIPath(for: ClaudeSessionPhaseFixture.self))
        defer { context.cleanup() }
        let sessionId = "startup-only-session"
        func readSession() throws -> [String: Any] {
            let data = try Data(contentsOf: context.root.appendingPathComponent("claude-hook-sessions.json"))
            let state = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
            let sessions = try #require(state["sessions"] as? [String: Any])
            return try #require(sessions[sessionId] as? [String: Any])
        }

        // Throwing joined runs retain both original no-timeout assertions.
        let start = try await context.run(
            arguments: ["hooks", "claude", "session-start"],
            standardInput: #"{"session_id":"\#(sessionId)","source":"startup","cwd":"\#(context.root.path)","transcript_path":"\#(context.root.path)/projects/startup-only-session.jsonl","hook_event_name":"SessionStart"}"#
        )
        #expect(start.status == 0, "\(start.stderr)")
        var record = try readSession()
        #expect(
            record["isRestorable"] as? Bool == false,
            "Startup SessionStart records are only routing state until Claude creates a conversation."
        )
        #expect(record["transcriptPath"] as? String == "\(context.root.path)/projects/startup-only-session.jsonl")

        let prompt = try await context.run(
            arguments: ["hooks", "claude", "prompt-submit"],
            standardInput: #"{"session_id":"\#(sessionId)","turn_id":"turn-1","cwd":"\#(context.root.path)","transcript_path":"\#(context.root.path)/projects/startup-only-session.jsonl","hook_event_name":"UserPromptSubmit"}"#
        )
        #expect(prompt.status == 0, "\(prompt.stderr)")
        record = try readSession()
        #expect(
            record["isRestorable"] as? Bool == true,
            "UserPromptSubmit marks the session eligible for resume."
        )
    }

    @Test
    func idlePromptAfterIdleStopTagsNotPending() async throws {
        let context = try ClaudeSessionPhaseFixture(
            cli: BundledCLITestSupport.bundledCLIPath(for: ClaudeSessionPhaseFixture.self),
            processTimeout: 5
        )
        defer { context.cleanup() }
        let session = "idle-after-idle"
        let stop = try await context.run(
            arguments: ["hooks", "claude", "stop"],
            standardInput: #"{"session_id":"\#(session)","cwd":"/tmp/x","hook_event_name":"Stop","last_assistant_message":"ok","background_tasks":[],"session_crons":[]}"#
        )
        #expect(stop.status == 0, "\(stop.stderr)")
        #expect(stop.stdout == "OK\n")

        let notificationStart = context.commands.count
        let notification = try await context.run(
            arguments: ["hooks", "claude", "notification"],
            standardInput: #"{"session_id":"\#(session)","cwd":"/tmp/x","hook_event_name":"Notification","message":"Claude is waiting for your input","notification_type":"idle_prompt"}"#
        )
        #expect(notification.status == 0, "\(notification.stderr)")
        #expect(notification.stdout == "OK\n")
        let commands = Array(context.commands.dropFirst(notificationStart))
        #expect(commands.contains { $0.hasPrefix("notify_target_async ") && $0.contains("c=idle-reminder;p=0") })
        #expect(commands.contains { $0.hasPrefix("set_status claude_code Idle ") })
        #expect(!commands.contains { $0.hasPrefix("set_status claude_code Needs input ") })

        let state = try #require(JSONSerialization.jsonObject(with: Data(contentsOf:
            context.root.appendingPathComponent("claude-hook-sessions.json"))) as? [String: Any])
        let sessions = try #require(state["sessions"] as? [String: Any])
        let record = try #require(sessions[session] as? [String: Any])
        #expect(record["hadPendingBackgroundWorkAtStop"] as? Bool == false)
    }
}
