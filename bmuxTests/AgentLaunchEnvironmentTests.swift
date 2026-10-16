import Foundation
import Testing

@Suite
final class AgentLaunchEnvironmentTests {
    @Test(arguments: ["/tmp/codex home", "/tmp/codex-home"])
    func sessionStartPersistsOnlyAllowedLaunchEnvironment(codexHome: String) async throws {
        let fixture = try AgentLaunchEnvironmentFixture()
        let cli = try BundledCLITestSupport.bundledCLIPath(for: Self.self)
        let launch = try await fixture.run(cli: cli, codexHome: codexHome)
        let environment = try #require(launch["environment"] as? [String: String])
        #expect(environment == ["CODEX_HOME": codexHome])
        #expect(launch["arguments"] as? [String] == ["/usr/local/bin/codex", "--model", "gpt-5.4"])
        #expect(launch["executablePath"] as? String == "/usr/local/bin/codex")
        #expect(launch["workingDirectory"] as? String == "/tmp/repo")
        #expect(launch["source"] as? String == "environment")
    }
}
