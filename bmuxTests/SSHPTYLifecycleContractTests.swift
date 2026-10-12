import Testing

@Suite
struct SSHPTYLifecycleContractTests {
    @Test(arguments: SSHPTYLifecycleFixture.Scenario.allCases, [false, true])
    func immediateClosurePreservesCleanup(scenario: SSHPTYLifecycleFixture.Scenario, terminal: Bool) async throws {
        let cli = try BundledCLITestSupport.bundledCLIPath(for: BundledCLILinkageTests.self)
        try await SSHPTYLifecycleFixture().run(cli: cli, scenario: scenario, terminal: terminal, waitsForResize: false)
    }

    @Test(arguments: SSHPTYLifecycleFixture.Scenario.allCases, [false, true])
    func acknowledgedResizePrecedesCleanup(scenario: SSHPTYLifecycleFixture.Scenario, terminal: Bool) async throws {
        let cli = try BundledCLITestSupport.bundledCLIPath(for: BundledCLILinkageTests.self)
        try await SSHPTYLifecycleFixture().run(cli: cli, scenario: scenario, terminal: terminal, waitsForResize: true)
    }
}
