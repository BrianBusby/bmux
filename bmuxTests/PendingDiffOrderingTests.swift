import Foundation
import Testing

@Suite("Pending diff viewer ordering")
@MainActor
struct PendingDiffOrderingTests {
    @Test func opensPendingViewerBeforeGitDiffCompletes() async throws {
        let snapshot = try await PendingDiffOrderingFixture().run()
        #expect(!snapshot.diffStartedBeforeOpen)
        #expect(snapshot.pendingHTML.contains("data-bmux-diff-pending=\"true\""))
        #expect(!snapshot.pendingHTML.contains("data-status-only=\"true\""))
        #expect(snapshot.pendingHTML.contains("<div id=\"root\"></div>"))
        let marker = "<script id=\"bmux-diff-viewer-config\" type=\"application/json\">"
        let start = try #require(snapshot.pendingHTML.range(of: marker)?.upperBound)
        let end = try #require(snapshot.pendingHTML[start...].range(of: "</script>")?.lowerBound)
        let config = try #require(JSONSerialization.jsonObject(with: Data(snapshot.pendingHTML[start..<end].utf8)) as? [String: Any])
        let payload = try #require(config["payload"] as? [String: Any])
        #expect(payload["pendingReplacement"] as? Bool == true)
        #expect(payload["title"] as? String == "Slow diff")
        #expect(payload["statusIsError"] as? Bool == false)
        #expect(!snapshot.selectedReleasedBeforeOpen)
        #expect(snapshot.selectedRedirected)
        #expect(!snapshot.alternateReleasedBeforeRedirect)
        #expect(snapshot.cliAliveAtRedirect)
        #expect(snapshot.result.status == 0, "\(snapshot.result.stderr)")
        #expect(snapshot.result.stdout.contains("OK surface=surface-id pane=pane-id"))
        #expect(snapshot.diffStarted)
        #expect(!snapshot.finalHTML.contains("data-bmux-diff-pending=\"true\""))
        #expect(snapshot.finalHTML.contains("Slow diff"))
        #expect(snapshot.patch.contains("+new line"))
    }
}
