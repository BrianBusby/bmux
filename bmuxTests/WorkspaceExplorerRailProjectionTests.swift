import Foundation
import ProvenanceEngineContracts
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@Suite @MainActor
struct WorkspaceExplorerRailProjectionTests {
    @Test
    func liveRailFollowsExplorerFiltersAndScope() async {
        let running = WorkspaceExplorerLiveWorkspace(stableID: UUID(), runtimeID: UUID(),
            title: "Maple Street Roof Inspection", createdAt: .now,
            colorHex: nil, display: nil, lastActivityAt: .now, liveStatus: .running)
        let idle = WorkspaceExplorerLiveWorkspace(stableID: UUID(), runtimeID: UUID(),
            title: "Cedar Street Roof Inspection", createdAt: .now,
            colorHex: nil, display: nil, lastActivityAt: .now, liveStatus: .idle)
        let items = WorkspaceExplorerHistoryAdapter().join(live: [running, idle], archived: [], eligibilityByID: [:])
        let model = WorkspaceExplorerCoordinator(
            loadHistory: { WorkspaceExplorerHistoryLoadResult(items: items,
                archiveAvailability: .available, partialLiveActivity: false) },
            reopenHistory: { _ in false }, activateWorkspace: { _ in },
            loadSessions: { id in ProvenanceWorkspaceSessionPageResponse(
                workspaceID: id.uuidString, sessions: [], nextCursor: nil) },
            clearArchive: { }
        )
        await model.load()
        #expect(Set(model.visibleLiveWorkspaceIDs ?? []) == [running.runtimeID, idle.runtimeID])
        model.setFilter(.bmuxStatus, value: .bmuxStatus(.running))
        #expect(model.visibleLiveWorkspaceIDs == [running.runtimeID])
        model.scope.state = .closed
        #expect(model.visibleLiveWorkspaceIDs == [])
        model.scope.state = .open
        model.showCollection(.all)
        #expect(Set(model.visibleLiveWorkspaceIDs ?? []) == [running.runtimeID, idle.runtimeID])
    }

}
