import Foundation
import Testing
@testable import BmuxSidebar

@Suite struct SidebarBranchOrderingPullRequestTitleTests {
    @Test func freshReportWithoutTitleKeepsKnownTitleForSamePullRequest() throws {
        let firstPanel = UUID()
        let secondPanel = UUID()
        let url = try #require(URL(string: "https://github.com/CompanyCam/Company-Cam-API/pull/29546"))
        let titled = SidebarPullRequestState(
            number: 29546,
            title: "Seeing try search user dash copy text",
            label: "PR",
            url: url,
            status: .open,
            isStale: true
        )
        let fresh = SidebarPullRequestState(
            number: 29546,
            label: "PR",
            url: url,
            status: .open
        )

        let rows = SidebarBranchOrdering().orderedUniquePullRequests(
            orderedPanelIds: [firstPanel, secondPanel],
            panelPullRequests: [firstPanel: titled, secondPanel: fresh],
            fallbackPullRequest: nil
        )

        #expect(rows.count == 1)
        #expect(rows.first?.isStale == false)
        #expect(rows.first?.title == titled.title)
    }
}
