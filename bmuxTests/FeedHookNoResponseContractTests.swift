import Foundation
import Testing

@Suite(.serialized)
struct FeedHookNoResponseContractTests {
    final class BundleProbe {}

    @Test(arguments: [
        ("gemini", "PreToolUse", "read", "BMUX_GEMINI_PID"),
        ("kiro", "postToolUse", "fs_write", "BMUX_KIRO_PID"),
        ("hermes-agent", "pre_tool_call", "terminal", "BMUX_HERMES_AGENT_PID"),
        ("antigravity", "PostToolUse", "run_command", "BMUX_ANTIGRAVITY_PID"),
    ])
    func nonActionableFeedHooksDoNotWaitForSocketResponse(
        source: String, event: String, tool: String, pidKey: String
    ) async throws {
        let fixture = try FeedHookNoResponseFixture(cli: BundledCLITestSupport.bundledCLIPath(for: BundleProbe.self))
        // The original no-timeout assertion is enforced by the throwing three-second
        // process boundary; socket observation retains its separate five-second bound.
        let result = try await fixture.run(source: source, event: event, tool: tool, pidKey: pidKey)
        #expect(result.observed, "\(source): socket server did not observe feed.push")
        #expect(result.output.status == 0, "\(source): \(result.output.stderr)")
        #expect(result.output.stdout == "{}\n")
        #expect(result.feeds.filter { $0.contains(#""method":"feed.push""#) }.count == 1)
    }
}
