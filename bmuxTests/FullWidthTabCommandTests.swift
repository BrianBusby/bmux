import Foundation
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@MainActor
@Suite
struct FullWidthTabCommandTests {
    @Test func toggleFocusedFullWidthTabTogglesFocusedPane() throws {
        let manager = TabManager()
        let workspace = try #require(manager.selectedWorkspace)
        let panelId = try #require(workspace.focusedPanelId)
        let paneId = try #require(workspace.paneId(forPanelId: panelId))

        #expect(manager.toggleFocusedFullWidthTab())
        #expect(workspace.focusedPanelId == panelId)
        #expect(workspace.bonsplitController.isFullWidthTabMode(inPane: paneId))

        #expect(manager.toggleFocusedFullWidthTab())
        #expect(workspace.focusedPanelId == panelId)
        #expect(!workspace.bonsplitController.isFullWidthTabMode(inPane: paneId))
    }
}
