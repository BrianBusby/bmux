import Foundation
import Testing

struct GrokHookConnectionTests {
    @Test func stopFallbackCompletionsRemainScopedToTwoConcurrentThreads() async throws {
        let fixture = try GrokHookConnectionFixture()
        for index in 0..<2 {
            let session = "grok-thread-\(index + 1)", surface = fixture.surfaceIDs[index]
            _ = try await fixture.run("session-start", session: session, surface: surface)
            _ = try await fixture.run("prompt-submit", session: session, surface: surface, fields: ["prompt": "thread \(index + 1) prompt"])
            let commands = try await fixture.run("notification", session: session, surface: surface, fields: [
                "message": "SessionNotification { update: HookExecution { event_name: user_prompt_submit } }",
            ])
            #expect(!commands.contains { $0.hasPrefix("notify_target_async ") }, "Prompt bookkeeping must not notify: \(commands)")
        }
        for index in 0..<2 {
            try fixture.writeAssistantTranscript(session: "grok-thread-\(index + 1)", text: "thread \(index + 1) response complete")
        }
        for index in 0..<2 {
            let commands = try await fixture.run("stop", session: "grok-thread-\(index + 1)", surface: fixture.surfaceIDs[index])
            #expect(commands.contains {
                $0.contains("notify_target_async \(fixture.workspaceID) \(fixture.surfaceIDs[index]) Grok|Completed in ")
                    && $0.contains("thread \(index + 1) response complete")
            }, "Expected scoped Stop fallback notification: \(commands)")
            if index == 0 {
                #expect(!commands.contains { $0.contains("set_status grok Idle") }, "First thread must not reset shared running status: \(commands)")
            } else {
                #expect(commands.contains { $0.contains("set_status grok Idle") }, "Final thread must leave Grok idle: \(commands)")
            }
        }
        for index in 0..<2 {
            let commands = try await fixture.run("notification", session: "grok-thread-\(index + 1)", surface: fixture.surfaceIDs[index], fields: [
                "message": "SessionNotification { update: HookExecution { event_name: stop } }",
            ])
            #expect(!commands.contains { $0.hasPrefix("notify_target_async ") }, "Internal notification must not duplicate Stop fallback: \(commands)")
        }
    }

    @Test func repeatedPromptStillNotifiesWithoutFeedTelemetryReply() async throws {
        let fixture = try GrokHookConnectionFixture()
        let session = "grok-session-repeat", surface = fixture.surfaceIDs[0]
        _ = try await fixture.run("session-start", session: session, surface: surface)
        for index in 1...2 {
            _ = try await fixture.run("prompt-submit", session: session, surface: surface, fields: ["prompt": "prompt \(index)"])
            let commands = try await fixture.run("notification", session: session, surface: surface,
                fields: ["message": "Turn complete in \(index).0s."], stallFeed: index == 2)
            #expect(commands.contains {
                $0.contains("notify_target_async \(fixture.workspaceID) \(surface) Grok|Completed|Task completed")
            }, "Expected completion for prompt \(index): \(commands)")
            #expect(commands.contains { $0.contains("set_status grok Idle") }, "Expected idle after prompt \(index): \(commands)")
            let telemetry = commands.filter { $0.contains("feed.push") }
            #expect(!telemetry.isEmpty, "The no-response path must actually receive telemetry")
        }
    }

    @Test func sessionEndPreservesRoutingForLaterChatMessages() async throws {
        let fixture = try GrokHookConnectionFixture()
        let session = "grok-session-multiple-turns", surface = fixture.surfaceIDs[0]
        _ = try await fixture.run("session-start", session: session, surface: surface)
        for index in 1...2 {
            let prompt = try await fixture.run("prompt-submit", session: session, surface: nil,
                fields: ["prompt": "message \(index)"])
            #expect(prompt.contains { $0.contains("set_status grok Running") }, "Expected saved-route running status: \(prompt)")
            #expect(prompt.contains("clear_notifications --tab=\(fixture.workspaceID) --panel=\(surface)"))
            #expect(!prompt.contains("clear_notifications --tab=\(fixture.workspaceID)"))
            for message in ["SessionNotification { update: HookExecution { event_name: user_prompt_submit } }",
                            "HookExecution { event_name: user_prompt_submit }"] {
                let internalCommands = try await fixture.run("notification", session: session, surface: nil,
                    fields: ["message": message])
                #expect(!internalCommands.contains { $0.hasPrefix("notify_target_async ") }, "Internal bookkeeping must not notify: \(internalCommands)")
            }
            let notification = try await fixture.run("notification", session: session, surface: nil,
                fields: ["message": "Turn complete in \(index).0s."])
            #expect(notification.contains {
                $0.contains("notify_target_async \(fixture.workspaceID) \(surface) Grok|Completed|Task completed")
            }, "Expected saved-route completion: \(notification)")
            #expect(notification.contains { $0.contains("set_status grok Idle") })
            let end = try await fixture.run("session-end", session: session, surface: nil)
            let methods = end.compactMap { line -> String? in
                guard let payload = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any] else { return nil }
                return payload["method"] as? String
            }
            #expect(methods == ["feed.push"], "SessionEnd must only emit feed telemetry: \(end)")
            #expect(!end.contains { $0.hasPrefix("clear_agent_pid grok.") }, "A chat-turn boundary must keep routing: \(end)")
        }
        let store = try #require(JSONSerialization.jsonObject(with:
            Data(contentsOf: fixture.root.appendingPathComponent("grok-hook-sessions.json"))) as? [String: Any])
        let sessions = try #require(store["sessions"] as? [String: Any])
        #expect(sessions[session] != nil, "The saved route must remain after both chat turns")
    }

    @Test func stopWithoutTranscriptCwdNotifiesAndDeduplicatesCompletion() async throws {
        let fixture = try GrokHookConnectionFixture(hasWorkingDirectory: false)
        let session = "grok-session-without-cwd", surface = fixture.surfaceIDs[0]
        _ = try await fixture.run("session-start", session: session, surface: surface)
        let stop = try await fixture.run("stop", session: session, surface: surface)
        #expect(stop.contains {
            $0.contains("notify_target_async \(fixture.workspaceID) \(surface) Grok|Completed|Grok session completed")
        }, "Missing cwd must retain generic completion text: \(stop)")
        #expect(stop.contains { $0.contains("set_status grok Idle") })
        let duplicate = try await fixture.run("notification", session: session, surface: surface,
            fields: ["message": "Turn complete in 1.0s."])
        #expect(!duplicate.contains { $0.hasPrefix("notify_target_async ") }, "Stop fallback must not double-notify: \(duplicate)")
    }
}
