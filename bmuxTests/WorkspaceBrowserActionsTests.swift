import Foundation
import Testing
#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@MainActor
@Suite(.serialized)
struct WorkspaceBrowserActionsTests {
    @Test func openBrowserSplitForActionReusesRightSiblingPane() throws {
        let workspace = Workspace()
        let sourcePanelId = try #require(workspace.focusedPanelId)
        let firstOpen = try #require(workspace.openBrowserSplitForAction(
            from: sourcePanelId,
            url: URL(string: "https://example.com"),
            focus: false,
            creationPolicy: .automationPreload
        ))

        #expect(firstOpen.createdSplit)
        #expect(firstOpen.placementStrategy == "split_right")
        let paneCountAfterSplit = workspace.bonsplitController.allPaneIds.count
        let firstBrowserPane = try #require(workspace.paneId(forPanelId: firstOpen.panel.id))

        let secondOpen = try #require(workspace.openBrowserSplitForAction(
            from: sourcePanelId,
            url: URL(string: "https://example.test"),
            focus: false,
            creationPolicy: .automationPreload
        ))

        #expect(!secondOpen.createdSplit)
        #expect(secondOpen.placementStrategy == "reuse_right_sibling")
        #expect(workspace.bonsplitController.allPaneIds.count == paneCountAfterSplit)
        #expect(workspace.paneId(forPanelId: secondOpen.panel.id) == firstBrowserPane)
    }
}
