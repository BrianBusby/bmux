import Foundation
import Testing
#if canImport(bmux_DEV)
@testable import bmux_DEV
#else
@testable import bmux
#endif

@MainActor
struct WorkspacePullRequestFocusContractTests {
    @Test func focusedProjectionRemainsIndependentOfSidebarAggregate() throws {
        let workspace = Workspace()
        defer { workspace.teardownRemoteConnection(); workspace.teardownAllPanels() }
        let firstPanelId = try #require(workspace.focusedPanelId)
        let paneId = try #require(workspace.paneId(forPanelId: firstPanelId))
        let secondPanel = try #require(workspace.newTerminalSurface(inPane: paneId, focus: false))

        workspace.updatePanelGitBranch(panelId: firstPanelId, branch: "main", isDirty: false)
        workspace.updatePanelGitBranch(panelId: secondPanel.id, branch: "feature/sidebar-pr", isDirty: false)
        workspace.updatePanelPullRequest(
            panelId: secondPanel.id,
            number: 1629,
            label: "PR",
            url: URL(string: "https://github.com/manaflow-ai/bmux/pull/1629")!,
            status: .open
        )

        #expect(workspace.focusedPanelId == firstPanelId)
        #expect(workspace.pullRequest == nil)
        #expect(workspace.sidebarPullRequestsInDisplayOrder().map(\.number) == [1629])

        workspace.focusPanel(secondPanel.id)

        #expect(workspace.focusedPanelId == secondPanel.id)
        #expect(workspace.pullRequest?.number == 1629)
        #expect(workspace.sidebarPullRequestsInDisplayOrder().map(\.number) == [1629])

        workspace.focusPanel(firstPanelId)

        #expect(workspace.focusedPanelId == firstPanelId)
        #expect(workspace.pullRequest == nil)
        #expect(workspace.sidebarPullRequestsInDisplayOrder().map(\.number) == [1629])
    }
}
