import AppKit
import BmuxTerminal
import Testing
#if canImport(bmux_DEV)
@testable import bmux_DEV
#else
@testable import bmux
#endif

@MainActor
struct WorkspacePullRequestPublicationTests {
    private enum PublicationEvent: Sendable { case published, firstUpdateCompleted }

    @Test func updatingFocusedPanelPullRequestWithSameStateDoesNotRepublishWorkspace() async throws {
        let workspace = Workspace()
        defer { workspace.teardownRemoteConnection(); workspace.teardownAllPanels() }
        let panelId = try #require(workspace.focusedPanelId)

        workspace.updatePanelGitBranch(panelId: panelId, branch: "feature/sidebar-pr", isDirty: false)

        let events = AsyncStream<PublicationEvent>.makeStream()
        let observer = NotificationCenter.default.addObserver(
            forName: .workspaceDisplayMetadataDidChange, object: workspace, queue: nil
        ) { _ in events.continuation.yield(.published) }
        defer {
            NotificationCenter.default.removeObserver(observer)
            events.continuation.finish()
        }

        let pullRequestURL = URL(string: "https://github.com/manaflow-ai/bmux/pull/2388")!
        workspace.updatePanelPullRequest(
            panelId: panelId,
            number: 2388,
            label: "PR",
            url: pullRequestURL,
            status: .open,
            branch: "feature/sidebar-pr"
        )
        events.continuation.yield(.firstUpdateCompleted)

        workspace.updatePanelPullRequest(
            panelId: panelId,
            number: 2388,
            label: "PR",
            url: pullRequestURL,
            status: .open,
            branch: "feature/sidebar-pr"
        )

        events.continuation.finish()
        var publishCount = 0
        var baselinePublishCount = 0
        for await event in events.stream {
            switch event {
            case .published:
                publishCount += 1
            case .firstUpdateCompleted:
                baselinePublishCount = publishCount
                #expect(baselinePublishCount > 0, "Expected the first focused pull request update to publish workspace changes")
            }
        }
        #expect(publishCount == baselinePublishCount, "Expected identical focused pull request refreshes to avoid extra workspace publishes")
    }
}
