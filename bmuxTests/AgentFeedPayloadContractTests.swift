import Foundation
import Testing

final class AgentFeedPayloadContractTests {
    @Test func kiroDenyAndCodexLatePullRequestPreserveFeedContracts() async throws {
        let cli = try BundledCLITestSupport.bundledCLIPath(for: Self.self)
        let kiro = try AgentFeedContractFixture(cli: cli, phase: .kiro)
        let denied = try await kiro.run(payload: [
            "hook_event_name": "preToolUse", "session_id": "kiro-session-123", "cwd": kiro.root.path,
            "tool_name": "fs_write", "tool_input": ["operations": [[
                "mode": "Line", "path": kiro.root.appendingPathComponent("README.md").path,
            ]]],
        ])
        // Throwing, joined runs preserve both original no-timeout assertions (local5/CI20).
        #expect(denied.output.status == 2, Comment(rawValue: denied.output.stderr))
        #expect(denied.output.stderr.contains("User denied permission via bmux Feed."))
        let kiroEvents = try feedEvents(denied.feeds)
        #expect(kiroEvents.count == 1)
        #expect(kiroEvents.first?["hook_event_name"] as? String == "PermissionRequest")
        #expect(kiroEvents.first?["_source"] as? String == "kiro")
        #expect(kiroEvents.first?["_ppid"] as? Int == 525252)

        let codex = try AgentFeedContractFixture(cli: cli, phase: .codex)
        let pullRequestURL = "https://github.com/CompanyCam/Company-Cam-API/pull/26096"
        let prefix = String(repeating: "review comment context ", count: 16)
        #expect(prefix.count > 240)
        let prompt = "\(prefix)on this pr: \(pullRequestURL)"
        let submitted = try await codex.run(payload: [
            "session_id": "codex-late-pr-session", "cwd": codex.root.path,
            "hook_event_name": "UserPromptSubmit", "prompt": prompt,
        ])
        #expect(submitted.output.status == 0, Comment(rawValue: submitted.output.stderr))
        #expect(submitted.output.stdout == "{}\n")
        let codexEvent = try #require(try feedEvents(submitted.feeds).last {
            $0["hook_event_name"] as? String == "UserPromptSubmit"
        })
        let toolInput = try #require(codexEvent["tool_input"] as? [String: Any])
        let toolPrompt = try #require(toolInput["prompt"] as? String)
        #expect(toolPrompt.contains(pullRequestURL))
        let context = try #require(codexEvent["context"] as? [String: Any])
        let lastUserMessage = try #require(context["lastUserMessage"] as? String)
        #expect(lastUserMessage.contains(pullRequestURL))
    }

    private func feedEvents(_ commands: [String]) throws -> [[String: Any]] {
        try commands.compactMap { line in
            let request = try #require(JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any])
            guard request["method"] as? String == "feed.push" else { return nil }
            let parameters = try #require(request["params"] as? [String: Any])
            return try #require(parameters["event"] as? [String: Any])
        }
    }
}
