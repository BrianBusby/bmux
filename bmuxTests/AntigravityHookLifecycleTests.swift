import Foundation
import Testing

struct AntigravityHookLifecycleTests {
    @Test func stopAndNotificationsUseGenericNotificationPath() async throws {
        let fixture = try AntigravityHookLifecycleFixture()
        let root = fixture.root, workspaceId = fixture.workspaceID, surfaceId = fixture.surfaceID
        let sessionId = "antigravity-conversation-123"
        _ = try await fixture.run(
            "session-start",
            input: #"{"session_id":"\#(sessionId)","cwd":"\#(root.path)","hook_event_name":"SessionStart"}"#
        )

        let backgroundMessage = "Antigravity is waiting on background work"
        let backgroundStopCommands = try await fixture.run(
            "stop",
            input: #"{"session_id":"\#(sessionId)","cwd":"\#(root.path)","hook_event_name":"Stop","last_assistant_message":"\#(backgroundMessage)","fullyIdle":false}"#
        )

        #expect(!backgroundStopCommands.contains { $0.hasPrefix("notify_target_async ") }, "Antigravity Stop with active background work must not publish idle notifications, saw \(backgroundStopCommands)")
        #expect(backgroundStopCommands.contains { $0.contains("set_status antigravity Running") }, "Antigravity Stop with active background work should keep the session running, saw \(backgroundStopCommands)")
        #expect(!backgroundStopCommands.contains { $0.contains("set_status antigravity Idle") }, "Antigravity Stop with active background work must not mark idle, saw \(backgroundStopCommands)")

        let backgroundDuplicateCommands = try await fixture.run(
            "notification",
            input: #"{"session_id":"\#(sessionId)","cwd":"\#(root.path)","hook_event_name":"Notification","message":"Turn complete in 1.0s.","fullyIdle":false}"#
        )

        #expect(!backgroundDuplicateCommands.contains { $0.hasPrefix("notify_target_async ") }, "Idle-classified Antigravity notifications must not double-notify while background work is active, saw \(backgroundDuplicateCommands)")
        #expect(!backgroundDuplicateCommands.contains { $0.contains("set_status antigravity Idle") }, "Idle-classified Antigravity notifications must not override the running status while background work is active, saw \(backgroundDuplicateCommands)")

        let missingFullyIdleSessionId = "\(sessionId)-missing-fully-idle"
        _ = try await fixture.run(
            "session-start",
            input: #"{"session_id":"\#(missingFullyIdleSessionId)","cwd":"\#(root.path)","hook_event_name":"SessionStart"}"#
        )

        _ = try await fixture.run(
            "stop",
            input: #"{"session_id":"\#(missingFullyIdleSessionId)","cwd":"\#(root.path)","hook_event_name":"Stop","last_assistant_message":"Background work still running","fullyIdle":false}"#
        )

        let missingFullyIdleNotificationCommands = try await fixture.run(
            "notification",
            input: #"{"session_id":"\#(missingFullyIdleSessionId)","cwd":"\#(root.path)","hook_event_name":"Notification","message":"Turn complete in 2.0s."}"#
        )

        #expect(missingFullyIdleNotificationCommands.contains { $0.hasPrefix("notify_target_async ") }, "Antigravity idle notifications without fullyIdle must publish instead of staying suppressed, saw \(missingFullyIdleNotificationCommands)")
        #expect(!missingFullyIdleNotificationCommands.contains { $0.contains("set_status antigravity Idle") }, "Antigravity idle notifications must not reset the shared status while another background session is running, saw \(missingFullyIdleNotificationCommands)")

        let stopMessage = "Antigravity finished updating docs"
        let stopCommands = try await fixture.run(
            "stop",
            input: #"{"session_id":"\#(sessionId)","cwd":"\#(root.path)","hook_event_name":"AfterAgent","last_assistant_message":"\#(stopMessage)"}"#
        )

        #expect(stopCommands.contains {
                $0.contains("notify_target_async \(workspaceId) \(surfaceId) Antigravity|Completed in ")
                    && $0.contains(stopMessage)
            }, "Expected Antigravity stop to publish a turn-completion notification, saw \(stopCommands)")
        #expect(stopCommands.contains { $0.contains("set_status antigravity Idle") }, "Expected Antigravity stop to leave the session idle, saw \(stopCommands)")

        let sessionEndCommands = try await fixture.run(
            "session-end",
            input: #"{"session_id":"\#(sessionId)","cwd":"\#(root.path)","hook_event_name":"SessionEnd"}"#
        )

        #expect(sessionEndCommands.contains { $0.contains("feed.push") }, "Expected Antigravity SessionEnd to emit feed telemetry, saw \(sessionEndCommands)")
        #expect(!sessionEndCommands.contains { $0.hasPrefix("clear_agent_pid antigravity.") }, "Antigravity SessionEnd is a turn boundary and must not clear saved routing, saw \(sessionEndCommands)")

        let duplicateCompletionCommands = try await fixture.run(
            "notification",
            input: #"{"session_id":"\#(sessionId)","cwd":"\#(root.path)","hook_event_name":"Notification","message":"Turn complete in 2.0s."}"#
        )

        #expect(!duplicateCompletionCommands.contains { $0.hasPrefix("notify_target_async ") }, "Antigravity turn-completion notification must not double-notify after stop already did, saw \(duplicateCompletionCommands)")

        let permissionMessage = "Allow shell command?"
        let permissionCommands = try await fixture.run(
            "notification",
            input: #"{"session_id":"\#(sessionId)","cwd":"\#(root.path)","hook_event_name":"Notification","reason":"permission_prompt","message":"\#(permissionMessage)"}"#
        )

        #expect(permissionCommands.contains {
                $0.contains("notify_target_async \(workspaceId) \(surfaceId) Antigravity|Permission|\(permissionMessage)")
            }, "Expected Antigravity permission notifications to publish through bmux, saw \(permissionCommands)")
        #expect(permissionCommands.contains { $0.contains("set_status antigravity Antigravity needs input") }, "Expected Antigravity permission notifications to mark needs-input, saw \(permissionCommands)")

        let stopErrorMessage = "Tool crashed"
        let stopErrorCommands = try await fixture.run(
            "stop",
            input: #"{"conversationId":"\#(sessionId)","workspacePaths":["\#(root.path)"],"hook_event_name":"Stop","terminationReason":"error","error":"\#(stopErrorMessage)","fullyIdle":true}"#
        )

        #expect(stopErrorCommands.contains {
                $0.contains("notify_target_async \(workspaceId) \(surfaceId) Antigravity|Error|\(stopErrorMessage)")
            }, "Expected Antigravity Stop errors to publish through bmux, saw \(stopErrorCommands)")
        #expect(stopErrorCommands.contains { $0.contains("set_status antigravity Antigravity error") }, "Expected Antigravity Stop errors to mark error status, saw \(stopErrorCommands)")

        let errorMessage = "Execution failed"
        let errorCommands = try await fixture.run(
            "notification",
            input: #"{"session_id":"\#(sessionId)","cwd":"\#(root.path)","hook_event_name":"Notification","message":"\#(errorMessage)"}"#
        )

        #expect(errorCommands.contains {
                $0.contains("notify_target_async \(workspaceId) \(surfaceId) Antigravity|Error|\(errorMessage)")
            }, "Expected Antigravity error notifications to publish through bmux, saw \(errorCommands)")
        #expect(errorCommands.contains { $0.contains("set_status antigravity Antigravity error") }, "Expected Antigravity error notifications to mark error status, saw \(errorCommands)")
    }
}
