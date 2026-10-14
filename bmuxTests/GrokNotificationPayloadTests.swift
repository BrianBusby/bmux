import Foundation
import Testing

struct GrokNotificationPayloadTests {
    @Test func notificationsPreservePayloadTranscriptScopeAndCompletionState() async throws {
        let fixture = try GrokHookConnectionFixture()
        let root = fixture.root, workspaceId = fixture.workspaceID, surfaceId = fixture.surfaceIDs[0]
        let sessionId = "grok-session-123"
        func runGrokHook(_ action: String, input: String) async throws -> [String] {
            let payload = try #require(JSONSerialization.jsonObject(with: Data(input.utf8)) as? [String: Any])
            return try await fixture.run(action, session: payload["sessionId"] as? String,
                surface: surfaceId, fields: payload)
        }
        let start = try await runGrokHook(
            "session-start",
            input: #"{"sessionId":"\#(sessionId)","cwd":"\#(root.path)","hookEventName":"SessionStart"}"#
        )
        #expect(!(start.contains { $0.contains("set_status grok") || $0.hasPrefix("notify_target_async ") }), "Grok SessionStart should only establish routing state, saw \(start)")

        let stopCommands = try await runGrokHook(
            "stop",
            input: #"{"sessionId":"\#(sessionId)","cwd":"\#(root.path)","hookEventName":"Stop"}"#
        )

        #expect(!(stopCommands.contains { $0.hasPrefix("notify_target_async ") }), "Grok Stop should not publish a generic completion notification; Notification carries the real message. Saw \(stopCommands)")
        #expect(stopCommands.contains { $0.contains("set_status grok Idle") }, "Expected Grok Stop to keep task-manager status idle, saw \(stopCommands)")

        let notificationCommands = try await runGrokHook(
            "notification",
            input: #"{"sessionId":"\#(sessionId)","cwd":"\#(root.path)","hookEventName":"Notification","message":"Grok finished updating docs"}"#
        )

        #expect(notificationCommands.contains {
                $0.contains("notify_target_async \(workspaceId) \(surfaceId) Grok|Completed|Grok finished updating docs")
            }, "Expected Grok Notification to forward the payload message, saw \(notificationCommands)")
        #expect(notificationCommands.contains { $0.contains("set_status grok Idle") }, "Expected completion notification to leave Grok idle, saw \(notificationCommands)")

        let storeURL = root.appendingPathComponent("grok-hook-sessions.json", isDirectory: false)
        var json = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: storeURL)) as? [String: Any])
        var sessions = try #require(json["sessions"] as? [String: Any])
        var session = try #require(sessions[sessionId] as? [String: Any])
        #expect(session["lastSubtitle"] as? String == "Completed")
        #expect(session["lastBody"] as? String == "Grok finished updating docs")
        #expect(session["lastNotificationStatus"] as? String == "idle")

        let preAssistantInternalCommands = try await runGrokHook(
            "notification",
            input: #"{"sessionId":"grok-before-assistant","cwd":"\#(root.path)","hookEventName":"Notification","message":"SessionNotification { update: HookExecution { event_name: session_start } }"}"#
        )

        #expect(!(preAssistantInternalCommands.contains { $0.hasPrefix("notify_target_async ") }), "Grok internal session notifications should not notify before there is an assistant response, saw \(preAssistantInternalCommands)")

        let preAssistantGenericCommands = try await runGrokHook(
            "notification",
            input: #"{"sessionId":"grok-generic-before-assistant","cwd":"\#(root.path)","hookEventName":"Notification","message":"Turn complete in 3.8s."}"#
        )

        #expect(preAssistantGenericCommands.contains {
                $0.contains("notify_target_async \(workspaceId) \(surfaceId) Grok|Completed|Task completed")
            }, "Grok generic completion notifications should still fire before there is an assistant response, saw \(preAssistantGenericCommands)")
        #expect(preAssistantGenericCommands.contains { $0.contains("set_status grok Idle") }, "Expected generic completion without an assistant response to leave Grok idle, saw \(preAssistantGenericCommands)")
        json = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: storeURL)) as? [String: Any])
        sessions = try #require(json["sessions"] as? [String: Any])
        let preAssistantGenericSession = try #require(sessions["grok-generic-before-assistant"] as? [String: Any])
        #expect(preAssistantGenericSession["lastSubtitle"] as? String == "Completed")
        #expect(preAssistantGenericSession["lastBody"] as? String == "Task completed")
        #expect(preAssistantGenericSession["lastNotificationStatus"] as? String == "idle")

        let assistantMessage = "**42.** That's the answer, according to Deep Thought."
        _ = try await runGrokHook(
            "prompt-submit",
            input: #"{"sessionId":"\#(sessionId)","cwd":"\#(root.path)","hookEventName":"UserPromptSubmit","prompt":"next turn"}"#
        )

        try fixture.writeAssistantTranscript(session: sessionId, text: assistantMessage, cwd: root.path)
        let enrichedStopCommands = try await runGrokHook(
            "stop",
            input: #"{"sessionId":"\#(sessionId)","cwd":"\#(root.path)","hookEventName":"Stop"}"#
        )

        #expect(enrichedStopCommands.contains {
                $0.contains("notify_target_async \(workspaceId) \(surfaceId) Grok|Completed in ")
                    && $0.contains(assistantMessage)
            }, "Expected Grok Stop fallback to publish the cwd-scoped assistant response when Grok only emits internal Notification events, saw \(enrichedStopCommands)")
        #expect(enrichedStopCommands.contains { $0.contains("set_status grok Idle") }, "Expected enriched Grok Stop to leave Grok idle, saw \(enrichedStopCommands)")

        let oversizedSessionId = "grok-oversized-final"
        let oversizedAssistantMessage = "Oversized Grok assistant response " + String(repeating: "g", count: 300_000)
        _ = try await runGrokHook(
            "session-start",
            input: #"{"sessionId":"\#(oversizedSessionId)","cwd":"\#(root.path)","hookEventName":"SessionStart"}"#
        )

        _ = try await runGrokHook(
            "prompt-submit",
            input: #"{"sessionId":"\#(oversizedSessionId)","cwd":"\#(root.path)","hookEventName":"UserPromptSubmit","prompt":"oversized turn"}"#
        )

        let oversizedSessionURL = fixture.transcriptDirectory(session: oversizedSessionId)
        try FileManager.default.createDirectory(at: oversizedSessionURL, withIntermediateDirectories: true)
        let oversizedPayload: [String: Any] = ["type": "assistant", "content": oversizedAssistantMessage]
        let oversizedData = try JSONSerialization.data(withJSONObject: oversizedPayload, options: [.sortedKeys])
        try oversizedData.write(to: oversizedSessionURL.appendingPathComponent("chat_history.jsonl", isDirectory: false))

        let oversizedStopCommands = try await runGrokHook(
            "stop",
            input: #"{"sessionId":"\#(oversizedSessionId)","cwd":"\#(root.path)","hookEventName":"Stop"}"#
        )

        #expect(oversizedStopCommands.contains {
                $0.contains("notify_target_async \(workspaceId) \(surfaceId) Grok|Completed in ")
                    && $0.contains("Oversized Grok assistant response")
            }, "Expected Grok Stop fallback to parse the oversized final chat-history line, saw \(oversizedStopCommands)")

        let multibyteSessionId = "grok-multibyte-boundary"
        _ = try await runGrokHook(
            "session-start",
            input: #"{"sessionId":"\#(multibyteSessionId)","cwd":"\#(root.path)","hookEventName":"SessionStart"}"#
        )

        _ = try await runGrokHook(
            "prompt-submit",
            input: #"{"sessionId":"\#(multibyteSessionId)","cwd":"\#(root.path)","hookEventName":"UserPromptSubmit","prompt":"multibyte boundary"}"#
        )

        let multibyteSessionURL = fixture.transcriptDirectory(session: multibyteSessionId)
        try FileManager.default.createDirectory(at: multibyteSessionURL, withIntermediateDirectories: true)
        let leadingPrefix = #"{"type":"assistant","content":""#
        let leadingContent = String(repeating: "あ", count: 90_000)
        let leadingLine = leadingPrefix + leadingContent + #""}"#
        let leadingPrefixByteCount = Data(leadingPrefix.utf8).count
        let leadingLineByteCount = Data(leadingLine.utf8).count
        var multibyteAssistantMessage = "Grok final after multibyte boundary"
        var multibyteHistoryData: Data?
        for suffixLength in 0..<3 {
            multibyteAssistantMessage = "Grok final after multibyte boundary" + String(repeating: "x", count: suffixLength)
            let finalLine = #"{"type":"assistant","content":"\#(multibyteAssistantMessage)"}"#
            let history = leadingLine + "\n" + finalLine + "\n"
            let data = Data(history.utf8)
            let readStart = data.count - min(data.count, 256 * 1024)
            if readStart > leadingPrefixByteCount,
               readStart < leadingLineByteCount,
               (readStart - leadingPrefixByteCount) % 3 != 0 {
                multibyteHistoryData = data
                break
            }
        }
        let historyData = try #require(multibyteHistoryData)
        try historyData.write(to: multibyteSessionURL.appendingPathComponent("chat_history.jsonl", isDirectory: false))

        let multibyteStopCommands = try await runGrokHook(
            "stop",
            input: #"{"sessionId":"\#(multibyteSessionId)","cwd":"\#(root.path)","hookEventName":"Stop"}"#
        )

        #expect(multibyteStopCommands.contains {
                $0.contains("notify_target_async \(workspaceId) \(surfaceId) Grok|Completed in ")
                    && $0.contains(multibyteAssistantMessage)
            }, "Expected Grok Stop fallback to skip the partial multibyte leading line, saw \(multibyteStopCommands)")

        let genericCompletionCommands = try await runGrokHook(
            "notification",
            input: #"{"sessionId":"\#(sessionId)","cwd":"\#(root.path)","hookEventName":"Notification","message":"Turn complete in 3.8s."}"#
        )

        #expect(!(genericCompletionCommands.contains { $0.hasPrefix("notify_target_async ") }), "Grok completion Notification must not double-notify after Stop fallback already published the completion, saw \(genericCompletionCommands)")
        #expect(genericCompletionCommands.contains { $0.contains("set_status grok Idle") }, "Expected enriched completion notification to leave Grok idle, saw \(genericCompletionCommands)")

        let sameCwdMissingSessionId = "grok-session-without-own-history"
        let sameCwdMissingCommands = try await runGrokHook(
            "notification",
            input: #"{"sessionId":"\#(sameCwdMissingSessionId)","cwd":"\#(root.path)","hookEventName":"Notification","message":"Turn complete in 4.0s."}"#
        )

        #expect(sameCwdMissingCommands.contains {
                $0.contains("notify_target_async \(workspaceId) \(surfaceId) Grok|Completed|Task completed")
            }, "Grok completion without a matching session transcript should still fire a generic completion notification, saw \(sameCwdMissingCommands)")
        #expect(!(sameCwdMissingCommands.contains { $0.contains(assistantMessage) }), "Grok completion notifications must not read another session from the same cwd, saw \(sameCwdMissingCommands)")

        let envResolvedMessage = "This message belongs to the env-resolved session."
        let unrelatedLatestMessage = "This message belongs to a newer unrelated session."
        try fixture.writeAssistantTranscript(session: surfaceId, text: envResolvedMessage, cwd: root.path)
        try fixture.writeAssistantTranscript(session: "latest-unrelated-grok-session", text: unrelatedLatestMessage, cwd: root.path)
        let unrelatedLatestHistoryURL = fixture.transcriptDirectory(session: "latest-unrelated-grok-session")
            .appendingPathComponent("chat_history.jsonl", isDirectory: false)
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSince1970: 2_000_000_000)],
            ofItemAtPath: unrelatedLatestHistoryURL.path
        )
        let envResolvedCommands = try await runGrokHook(
            "notification",
            input: #"{"cwd":"\#(root.path)","hookEventName":"Notification","message":"Turn complete in 4.2s."}"#
        )

        #expect(envResolvedCommands.contains {
                $0.contains("notify_target_async \(workspaceId) \(surfaceId) Grok|Completed|\(envResolvedMessage)")
            }, "Grok completion without a payload session id should use the resolved hook session id, saw \(envResolvedCommands)")
        #expect(!(envResolvedCommands.contains { $0.contains(unrelatedLatestMessage) }), "Grok completion without a payload session id must not fall back to the latest unrelated cwd session, saw \(envResolvedCommands)")

        let hookExecutionCommands = try await runGrokHook(
            "notification",
            input: #"{"sessionId":"\#(sessionId)","cwd":"\#(root.path)","hookEventName":"Notification","message":"SessionNotification { update: MemoryFlushCompleted { result: written } }"}"#
        )

        #expect(!(hookExecutionCommands.contains { $0.hasPrefix("notify_target_async ") }), "Grok internal session notifications must not replay the last assistant response as a fresh notification, saw \(hookExecutionCommands)")

        let otherCwd = root.appendingPathComponent("other-project", isDirectory: true)
        let missingCwd = root.appendingPathComponent("missing-project", isDirectory: true)
        let otherProjectMessage = "This message belongs to a different project."
        try FileManager.default.createDirectory(at: missingCwd, withIntermediateDirectories: true)
        try fixture.writeAssistantTranscript(session: "other-grok-session", text: otherProjectMessage, cwd: otherCwd.path)
        let scopedMissSessionId = "grok-session-without-project-history"
        let scopedMissCommands = try await runGrokHook(
            "notification",
            input: #"{"sessionId":"\#(scopedMissSessionId)","cwd":"\#(missingCwd.path)","hookEventName":"Notification","message":"Turn complete in 4.0s."}"#
        )

        #expect(scopedMissCommands.contains {
                $0.contains("notify_target_async \(workspaceId) \(surfaceId) Grok|Completed|Task completed")
            }, "Grok completion without a cwd-scoped transcript should still fire a generic completion notification, saw \(scopedMissCommands)")
        #expect(!(scopedMissCommands.contains { $0.contains(otherProjectMessage) }), "Grok completion notifications must not read another cwd's latest session, saw \(scopedMissCommands)")
        #expect(scopedMissCommands.contains { $0.contains("set_status grok Idle") }, "Expected scoped completion without transcript to leave Grok idle, saw \(scopedMissCommands)")

        let waitingMessage = "Choose docs section"
        let waitingCommands = try await runGrokHook(
            "notification",
            input: #"{"sessionId":"\#(sessionId)","cwd":"\#(root.path)","hookEventName":"Notification","reason":"idle_prompt","message":"\#(waitingMessage)"}"#
        )

        #expect(waitingCommands.contains {
                $0.contains("notify_target_async \(workspaceId) \(surfaceId) Grok|Waiting|\(waitingMessage)")
            }, "Expected waiting notification to forward the payload message, saw \(waitingCommands)")
        #expect(waitingCommands.contains { $0.contains("set_status grok Grok needs input") }, "Expected waiting notification to mark Grok as needing input, saw \(waitingCommands)")

        let fallbackCommands = try await runGrokHook(
            "notification",
            input: #"{"sessionId":"\#(sessionId)","cwd":"\#(root.path)","hookEventName":"Notification"}"#
        )

        #expect(fallbackCommands.contains {
                $0.contains("notify_target_async \(workspaceId) \(surfaceId) Grok|Waiting|\(waitingMessage)")
            }, "Expected empty Grok Notification payload to reuse the saved message, saw \(fallbackCommands)")
        #expect(fallbackCommands.contains { $0.contains("set_status grok Grok needs input") }, "Expected fallback notification to preserve the saved needs-input status, saw \(fallbackCommands)")

        json = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: storeURL)) as? [String: Any])
        sessions = try #require(json["sessions"] as? [String: Any])
        session = try #require(sessions[sessionId] as? [String: Any])
        #expect(session["lastSubtitle"] as? String == "Waiting")
        #expect(session["lastBody"] as? String == waitingMessage)
        #expect(session["lastNotificationStatus"] as? String == "needsInput")

        for neutralMessage in ["Invalid input format", "Question mark rendered"] {
                let neutralCommands = try await runGrokHook(
                "notification",
                input: #"{"sessionId":"\#(sessionId)","cwd":"\#(root.path)","hookEventName":"Notification","message":"\#(neutralMessage)"}"#
            )

            #expect(!(neutralCommands.contains { $0.hasPrefix("notify_target_async ") }), "Neutral classifier text should not alert as needs-input, saw \(neutralCommands)")
            #expect(!(neutralCommands.contains { $0.contains("set_status grok ") }), "Neutral classifier text should not replace the saved status, saw \(neutralCommands)")
        }

        let incompleteWaitingMessage = "Task incomplete and undone, waiting for input"
        let incompleteWaitingCommands = try await runGrokHook(
            "notification",
            input: #"{"sessionId":"\#(sessionId)","cwd":"\#(root.path)","hookEventName":"Notification","message":"\#(incompleteWaitingMessage)"}"#
        )

        #expect(incompleteWaitingCommands.contains {
                $0.contains("notify_target_async \(workspaceId) \(surfaceId) Grok|Waiting|\(incompleteWaitingMessage)")
            }, "Incomplete/undone waiting text should not be classified as a completion, saw \(incompleteWaitingCommands)")
        #expect(!(incompleteWaitingCommands.contains { $0.contains("Grok|Completed|") }), "Incomplete/undone waiting text must not emit a completed notification, saw \(incompleteWaitingCommands)")

        let progressMessage = "Working through more changes"
        let progressCommands = try await runGrokHook(
            "notification",
            input: #"{"sessionId":"\#(sessionId)","cwd":"\#(root.path)","hookEventName":"Notification","message":"\#(progressMessage)"}"#
        )

        #expect(!(progressCommands.contains { $0.hasPrefix("notify_target_async ") }), "Unclassified Grok notifications are progress/bookkeeping and should not alert, saw \(progressCommands)")
        #expect(!(progressCommands.contains { $0.contains("set_status grok ") }), "Unclassified Grok notifications should not clear or replace active status, saw \(progressCommands)")

        json = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: storeURL)) as? [String: Any])
        sessions = try #require(json["sessions"] as? [String: Any])
        session = try #require(sessions[sessionId] as? [String: Any])
        #expect(session["lastSubtitle"] as? String == "Waiting")
        #expect(session["lastBody"] as? String == incompleteWaitingMessage)
        #expect(session["lastNotificationStatus"] as? String == "needsInput")

        let neutralFallbackCommands = try await runGrokHook(
            "notification",
            input: #"{"sessionId":"\#(sessionId)","cwd":"\#(root.path)","hookEventName":"Notification"}"#
        )

        #expect(neutralFallbackCommands.contains {
                $0.contains("notify_target_async \(workspaceId) \(surfaceId) Grok|Waiting|\(incompleteWaitingMessage)")
            }, "Expected empty payload to reuse the last terminal saved notification, saw \(neutralFallbackCommands)")
        #expect(neutralFallbackCommands.contains { $0.contains("set_status grok Grok needs input") }, "Fallback notifications should preserve the saved needs-input status, saw \(neutralFallbackCommands)")
    }
}
