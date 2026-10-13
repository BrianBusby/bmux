import Testing

@Suite
struct WorkspaceFallbackContractTests {
    @Test(arguments: WorkspaceFallbackFixture.Entry.allCases, WorkspaceFallbackFixture.Scenario.allCases)
    func resolvesOnlyThePermittedTarget(
        entry: WorkspaceFallbackFixture.Entry, scenario: WorkspaceFallbackFixture.Scenario
    ) async throws {
        let cli = try BundledCLITestSupport.bundledCLIPath(for: BundledCLILinkageTests.self)
        let fixture = try WorkspaceFallbackFixture()
        try await fixture.run(cli: cli, entry: entry, scenario: scenario)
    }
}
