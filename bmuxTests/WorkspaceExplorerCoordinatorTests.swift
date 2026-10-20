import Foundation
import ProvenanceEngineContracts
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@Suite @MainActor
struct WorkspaceExplorerCoordinatorTests {
    @Test
    func overviewAndProjectKeepIndependentArrangementsWhileScopeTravels() async {
        let model = WorkspaceExplorerCoordinator(
            loadHistory: { WorkspaceExplorerHistoryLoadResult(items: [],
                archiveAvailability: .available, partialLiveActivity: false) },
            reopenHistory: { _ in false },
            activateWorkspace: { _ in },
            loadSessions: { id in ProvenanceWorkspaceSessionPageResponse(
                workspaceID: id.uuidString, sessions: [], nextCursor: nil) },
            clearArchive: { }
        )
        await model.load()
        model.setGroupBy([.repository])
        model.scope.state = .all
        model.showCollection(.project("p1"))
        model.setGroupBy([.ticket, .pullRequestOwner])
        model.setFilter(.ticket, value: .value("BMUX-1"))
        model.showHistory("closed")
        model.backFromHistory()
        #expect(model.activeArrangement.groupBy == [.ticket, .pullRequestOwner])
        model.showOverview()
        #expect(model.scope.state == .all)
        #expect(model.activeArrangement.groupBy == [.repository])
        #expect(model.activeArrangement.filters.isEmpty)
        model.showCollection(.project("p1"))
        #expect(model.activeArrangement.filters[.ticket] == .value("BMUX-1"))
    }
}
