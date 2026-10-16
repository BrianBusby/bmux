import Foundation
import Testing

struct HermesHookProcessContractTests {
    @Test
    func notificationsUseShellHookExtraPayload() async throws {
        let cli = try BundledCLITestSupport.bundledCLIPath(for: HermesHookProcessFixture.self)
        let fixture = try HermesHookProcessFixture(cli: cli)
        let root = fixture.root
        let workspaceId = fixture.workspace, surfaceId = fixture.surface
        let sessionId = "hermes-session-123"

        func storedHermesSession() throws -> [String: Any] {
            let storeURL = root.appendingPathComponent("hermes-agent-hook-sessions.json", isDirectory: false)
            let json = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: storeURL)) as? [String: Any])
            let sessions = try #require(json["sessions"] as? [String: Any])
            return try #require(sessions[sessionId] as? [String: Any])
        }

        // Every throwing run preserves the original no-timeout assertion and five-second bound.
        let start = try await fixture.run(
            "session-start",
            input: #"{"session_id":"\#(sessionId)","cwd":"\#(root.path)","hook_event_name":"on_session_start"}"#
        )
        #expect(start.output.status == 0, "\(start.output.stderr)")
        #expect(start.output.stdout == "{}\n")

        let assistantResponse = "Updated README.md and added usage notes."
        let stop = try await fixture.run(
            "agent-response",
            input: #"{"session_id":"\#(sessionId)","cwd":"\#(root.path)","hook_event_name":"post_llm_call","extra":{"user_message":"make the docs clearer","assistant_response":"\#(assistantResponse)","model":"gpt-4","platform":"cli"}}"#
        )
        #expect(stop.output.status == 0, "\(stop.output.stderr)")
        #expect(stop.output.stdout == "{}\n")
        #expect(stop.commands.contains {
            $0.contains("notify_target_async \(workspaceId) \(surfaceId) Hermes Agent|Completed in ")
                && $0.contains("|\(assistantResponse)")
        }, "Expected completion notification to use extra.assistant_response: \(stop.commands)")
        #expect(stop.commands.contains { $0.contains("set_status hermes-agent Idle") })

        let approval = try await fixture.run(
            "notification",
            input: #"{"session_id":"\#(sessionId)","cwd":"\#(root.path)","hook_event_name":"pre_approval_request","extra":{"command":"rm -rf build","description":"recursive delete","pattern_key":"recursive delete","surface":"cli"}}"#
        )
        #expect(approval.output.status == 0, "\(approval.output.stderr)")
        #expect(approval.output.stdout == "{}\n")
        #expect(approval.commands.contains {
            $0.contains("notify_target_async \(workspaceId) \(surfaceId) Hermes Agent|Permission|recursive delete: rm -rf build")
        })
        #expect(approval.commands.contains { $0.contains("set_status hermes-agent Hermes Agent needs input") })
        #expect(!approval.commands.contains { $0.contains(#""method":"feed.push""#) },
                "Approval has its own feed hook; do not emit duplicate feed events")

        let session = try storedHermesSession()
        #expect(session["lastSubtitle"] as? String == "Permission")
        #expect(session["lastBody"] as? String == "recursive delete: rm -rf build")
        #expect(session["lastNotificationStatus"] as? String == "needsInput")

        let response = try await fixture.run(
            "approval-response",
            input: #"{"session_id":"\#(sessionId)","cwd":"\#(root.path)","hook_event_name":"post_approval_response","extra":{"approved":true}}"#
        )
        #expect(response.output.status == 0, "\(response.output.stderr)")
        #expect(response.output.stdout == "{}\n")
        #expect(response.commands.contains { $0.contains("clear_notifications --tab=\(workspaceId) --panel=\(surfaceId)") })
        #expect(response.commands.contains { $0.contains("set_status hermes-agent Running") })
        #expect(!response.commands.contains { $0.contains(#""method":"feed.push""#) },
                "Approval response has its own feed hook; do not emit duplicate feed events")

        let responseSession = try storedHermesSession()
        #expect(responseSession["lastSubtitle"] == nil)
        #expect(responseSession["lastBody"] == nil)
        #expect(responseSession["lastNotificationStatus"] == nil)
        #expect(responseSession["runtimeStatus"] as? String == "running")
    }

    @Test
    func sessionEndIsTurnBoundaryButFinalizeTearsDown() async throws {
        let cli = try BundledCLITestSupport.bundledCLIPath(for: HermesHookProcessFixture.self)
        let fixture = try HermesHookProcessFixture(cli: cli)
        let root = fixture.root
        let sessionId = "hermes-session-end-123"

        func storedHermesSessionIfPresent() throws -> [String: Any]? {
            let storeURL = root.appendingPathComponent("hermes-agent-hook-sessions.json", isDirectory: false)
            let data: Data
            do { data = try Data(contentsOf: storeURL) }
            catch let error as CocoaError where error.code == .fileReadNoSuchFile { return nil }
            let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
            let sessions = try #require(json["sessions"] as? [String: Any])
            guard let record = sessions[sessionId] else { return nil }
            return try #require(record as? [String: Any])
        }

        let start = try await fixture.run(
            "session-start",
            input: #"{"session_id":"\#(sessionId)","cwd":"\#(root.path)","hook_event_name":"on_session_start"}"#
        )
        #expect(start.output.status == 0, "\(start.output.stderr)")
        let stop = try await fixture.run(
            "agent-response",
            input: #"{"session_id":"\#(sessionId)","cwd":"\#(root.path)","hook_event_name":"post_llm_call","extra":{"user_message":"do the thing","assistant_response":"done","model":"gpt-4","platform":"cli"}}"#
        )
        #expect(stop.output.status == 0, "\(stop.output.stderr)")
        #expect(try storedHermesSessionIfPresent() != nil)

        // Hermes on_session_end fires per turn; only on_session_finalize tears down routing.
        let sessionEnd = try await fixture.run(
            "session-end",
            input: #"{"session_id":"\#(sessionId)","cwd":"\#(root.path)","hook_event_name":"on_session_end"}"#
        )
        #expect(sessionEnd.output.status == 0, "\(sessionEnd.output.stderr)")
        #expect(sessionEnd.output.stdout == "{}\n")
        #expect(sessionEnd.commands.contains { $0.contains("feed.push") })
        #expect(!sessionEnd.commands.contains { $0.hasPrefix("clear_agent_pid hermes-agent.") })
        #expect(!sessionEnd.commands.contains { $0.contains("surface.resume.clear") })
        #expect(try storedHermesSessionIfPresent() != nil)

        let finalize = try await fixture.run(
            "session-finalize",
            input: #"{"session_id":"\#(sessionId)","cwd":"\#(root.path)","hook_event_name":"on_session_finalize"}"#
        )
        #expect(finalize.output.status == 0, "\(finalize.output.stderr)")
        #expect(finalize.output.stdout == "{}\n")
        #expect(finalize.commands.contains { $0.hasPrefix("clear_agent_pid hermes-agent.") })
        #expect(finalize.commands.contains { $0.contains("surface.resume.clear") })
        #expect(try storedHermesSessionIfPresent() == nil)
    }
}
