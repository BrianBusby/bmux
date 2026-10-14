import Foundation
import Testing

@Suite
struct NoGitWatchShellIntegrationTests {
    @Test(arguments: ["bash", "zsh"])
    func disabledGitWatchClearsHeadTrackingAndPendingPRAction(shell: String) async throws {
        let fixture = try NoGitWatchShellFixture()
        let output = try await fixture.run(shell: shell)
        #expect(!output.contains(fixture.root.appendingPathComponent("repo-a/.git/HEAD").path), "\(output)")
        #expect(output.contains("HEAD_PATH=\n"), "\(output)")
        #expect(output.contains("HEAD_LAST_PWD=\n"), "\(output)")
        #expect(output.contains("LAST_PR_ACTION=\n"), "\(output)")
        #expect(!output.contains("clear_pr"), "\(output)")
        #expect(!output.contains("report_pr_action"), "\(output)")
    }
}
