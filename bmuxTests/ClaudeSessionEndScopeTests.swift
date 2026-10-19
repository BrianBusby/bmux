import Foundation
import Testing

@Suite
final class ClaudeSessionEndScopeTests {
    @Test(arguments: [false, true], [false, true])
    func replacedSessionCleanupUsesConsumedWorkspace(perSurfaceState: Bool, explicitSession: Bool) async throws {
        let fixture = try ClaudeSessionEndFixture(perSurfaceState: perSurfaceState)
        let cli = try BundledCLITestSupport.bundledCLIPath(for: Self.self)
        let commands = try await fixture.run(cli: cli, explicitSession: explicitSession)
        let state = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: fixture.stateURL)) as? [String: Any])
        let sessions = try #require(state["sessions"] as? [String: Any])
        #expect(sessions["stale-session"] == nil)
        #expect(sessions["active-session"] != nil)
        #expect(!commands.contains { $0.hasPrefix("clear_status ") || $0.hasPrefix("clear_agent_pid ") || $0.hasPrefix("clear_notifications ") }, "\(commands)")
        for (key, id) in [("activeSessionsByWorkspace", fixture.workspaceID), ("activeSessionsBySurface", fixture.surfaceID)] {
            let active = try #require((state[key] as? [String: [String: Any]])?[id])
            #expect(active["sessionId"] as? String == "active-session")
        }
        let methods = commands.compactMap { line -> String? in
            guard let data = line.data(using: .utf8),
                  let request = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
            return request["method"] as? String
        }
        #expect(methods.filter { $0 == "surface.resume.clear" }.count == 1)
    }
}
