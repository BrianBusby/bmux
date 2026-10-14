import Foundation
import Testing

@Suite
final class CloudAttachRetryContractTests {
    @Test(arguments: CloudAttachRetryFixture.Entry.allCases, CloudAttachRetryFixture.Scenario.allCases)
    func attachPreservesRetryBoundsAndFinalErrors(
        entry: CloudAttachRetryFixture.Entry, scenario: CloudAttachRetryFixture.Scenario
    ) async throws {
        let fixture = try CloudAttachRetryFixture()
        let cli = try BundledCLITestSupport.bundledCLIPath(for: Self.self)
        let result = try await fixture.run(cli: cli, entry: entry, scenario: scenario)
        let retries = scenario == .genericOverride || scenario == .legacyFallback || scenario == .reconnect
        #expect(result.commands.count == (retries ? 2 : 1), "\(result.commands)")
        #expect(result.stderr.contains("[bmux]") == (retries && scenario != .reconnect), "\(result.stderr)")
        if retries && scenario != .reconnect {
            #expect(result.stderr.contains("(attempt 1/1)"), "\(result.stderr)")
            // The zero-delay label is localized "now", not the obsolete hardcoded "0s".
            let now = String(localized: "cli.vm.sshInfo.retry.now", defaultValue: "now")
            #expect(result.stderr.contains("\(now) (attempt 1/1)"), "\(result.stderr)")
        }
        if scenario == .missingVM {
            #expect(result.stderr.contains("The Cloud VM attached to this workspace no longer exists."))
            #expect(result.stderr.contains("bmux will not recreate the VM"))
        } else {
            #expect(result.stderr.hasSuffix("Error: \(result.error)\n"), "\(result.stderr)")
        }
        let ids = try result.commands.map { line in
            let request = try #require(JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any])
            return try #require(request["id"] as? String)
        }
        #expect(Set(ids).count == result.commands.count)
    }
}
