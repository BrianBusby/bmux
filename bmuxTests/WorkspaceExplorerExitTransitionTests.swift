import Foundation
import ProvenanceEngineContracts
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@Suite @MainActor
struct WorkspaceExplorerExitTransitionTests {
    @Test
    func filterExitKeepsOldCountsUntilRapidReplacementCommitsLatestResult() async {
        let needingInput = WorkspaceExplorerLiveWorkspace(stableID: UUID(), runtimeID: UUID(),
            title: "Maple Street Roof Inspection", createdAt: .now,
            colorHex: nil, display: nil, lastActivityAt: .now, liveStatus: .needsInput)
        let idle = WorkspaceExplorerLiveWorkspace(stableID: UUID(), runtimeID: UUID(),
            title: "Cedar Street Roof Inspection", createdAt: .now,
            colorHex: nil, display: nil, lastActivityAt: .now, liveStatus: .idle)
        let items = WorkspaceExplorerHistoryAdapter().join(live: [needingInput, idle],
            archived: [], eligibilityByID: [:])
        let model = WorkspaceExplorerCoordinator(loadHistory: {
            WorkspaceExplorerHistoryLoadResult(items: items, archiveAvailability: .available,
                partialLiveActivity: false)
        }, reopenHistory: { _ in false }, activateWorkspace: { _ in },
           loadSessions: { id in ProvenanceWorkspaceSessionPageResponse(
               workspaceID: id.uuidString, sessions: [], nextCursor: nil) },
           clearArchive: { }, feedbackDelay: { duration in
               #expect(duration == .milliseconds(170))
               try await Task.sleep(for: .seconds(60))
           })
        model.showCollection(.all)
        await model.load()

        model.setFilter(.bmuxStatus, value: .bmuxStatus(.needsInput), animated: true)
        #expect(model.result()?.visibleCounts.workspaces == 2)
        #expect(model.exitingWorkspaceIDs == [idle.stableID.uuidString])
        #expect(model.presentedFilters.isEmpty)
        #expect(model.activeArrangement.filters[.bmuxStatus] == .bmuxStatus(.needsInput))
        model.setScrollAnchor("workspace:\(needingInput.stableID.uuidString)")
        #expect(model.exitingWorkspaceIDs == [idle.stableID.uuidString])

        model.setFilter(.bmuxStatus, value: .bmuxStatus(.idle), animated: false)
        #expect(model.result()?.visibleWorkspaceIDs == [idle.stableID.uuidString])
        #expect(model.exitingWorkspaceIDs.isEmpty)
        #expect(model.presentedFilters[.bmuxStatus] == .bmuxStatus(.idle))

        model.clearFilters()
        model.setScopeState(.closed, animated: true)
        #expect(model.scope.state == .closed)
        #expect(model.presentedScope.state == .open)
        #expect(model.result()?.visibleCounts.workspaces == 2)
        #expect(model.exitingWorkspaceIDs == Set([needingInput.stableID.uuidString,
            idle.stableID.uuidString]))
        model.setScopeState(.open, animated: false)
        #expect(model.exitingWorkspaceIDs.isEmpty)
        #expect(model.result()?.visibleCounts.workspaces == 2)
    }

}
