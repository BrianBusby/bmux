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
    func liveRailFollowsExplorerFiltersAndScope() async throws {
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
        // Group-card Focus uses the same setFilter path as the Explorer filter bar.
        model.setFilter(.bmuxStatus, value: .bmuxStatus(.running))
        #expect(model.visibleLiveWorkspaceIDs == [running.runtimeID])
        let groupChip = try #require(model.activeRailFilters.first {
            if case .dimension(.bmuxStatus, _) = $0.kind { return true }
            return false
        })
        model.removeRailFilter(groupChip)
        #expect(model.activeArrangement.filters[.bmuxStatus] == nil)
        #expect(Set(model.visibleLiveWorkspaceIDs ?? []) == [running.runtimeID, idle.runtimeID])

        model.setScopeState(.closed)
        #expect(model.visibleLiveWorkspaceIDs == [])
        let stateChip = try #require(model.activeRailFilters.first { $0.id == "state" })
        model.removeRailFilter(stateChip)
        #expect(model.scope.state == .open)

        model.setScopePeriod(.today)
        let periodChip = try #require(model.activeRailFilters.first { $0.id == "period" })
        model.removeRailFilter(periodChip)
        #expect(model.scope.period == .anyTime)

        model.showCollection(.unassigned)
        let collectionChip = try #require(model.activeRailFilters.first { $0.id == "collection" })
        model.removeRailFilter(collectionChip)
        #expect(model.collectionTarget == nil)
        #expect(Set(model.visibleLiveWorkspaceIDs ?? []) == [running.runtimeID, idle.runtimeID])
    }

}
