import Foundation
import Testing

@Suite
struct HermesResumeExecutionTests {
    @Test(arguments: HermesResumeExecutionFixture.Scenario.allCases)
    func generatedStartupExecutesOrderedBootstrapAndResume(scenario: HermesResumeExecutionFixture.Scenario) async throws {
        let fixture = try HermesResumeExecutionFixture(scenario: scenario)
        let records = try await fixture.run()
        var expectedArguments: [[String]] = scenario == .explicitProvider ? [] : [
            ["config", "set", "model.provider", "custom"],
            ["config", "set", "model.base_url", fixture.baseURL],
            ["config", "set", "model.api_mode", "codex_responses"],
            ["config", "set", "model.default", "gpt-5.5"],
        ]
        expectedArguments.append(["--provider", scenario == .explicitProvider ? "anthropic" : "custom",
                                  "--resume", "hermes-session-123"])
        #expect(records.map(\.arguments) == expectedArguments)
        for invocation in records {
            #expect(invocation.executable == fixture.executable.path)
            #expect(invocation.directory == fixture.project.path)
            #expect(invocation.baseURL == fixture.baseURL)
            #expect(invocation.codexHome == fixture.codexHome.path)
        }
    }
}
