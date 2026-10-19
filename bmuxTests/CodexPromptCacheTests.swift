import Foundation
import Testing
@MainActor struct CodexPromptCacheTests {
    @Test func cachesPromptAndLaunchesFallback() async throws {
        let fixture = try CodexPromptCacheFixture(cli: BundledCLITestSupport.bundledCLIPath(for: CodexPromptCacheFixture.self))
        defer { fixture.cleanup() }
        let result = try await fixture.run()
        #expect(result.status == 0)
        #expect(result.stdout == "{}\n")
        #expect(FileManager.default.fileExists(atPath: fixture.root.appendingPathComponent("launch.log").path))
        let log = try String(contentsOf: fixture.root.appendingPathComponent("launch.log"), encoding: .utf8)
        #expect(log.contains("hooks") && log.contains("codex") && log.contains("auto-name"))
        #expect(log.contains("--trigger") && log.contains("prompt-submit"))
        let state = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: fixture.root.appendingPathComponent("codex-hook-sessions.json"))) as? [String: Any])
        let sessions = try #require(state["sessions"] as? [String: Any])
        let session = try #require(sessions[fixture.session] as? [String: Any])
        let messages = try #require(session["autoNameRecentMessages"] as? [[String: Any]])
        #expect(messages.contains { $0["role"] as? String == "user" && $0["text"] as? String == fixture.prompt })
        #expect(session["autoNameMessageSequence"] as? Int == 1)
        #expect(!FileManager.default.fileExists(atPath: fixture.root.appendingPathComponent("codex-monitor-leases").path))
    }
}
