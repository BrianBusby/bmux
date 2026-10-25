import Foundation
import ProvenanceEngineContracts
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@Suite @MainActor
struct WorkspaceExplorerRootNavigationTests {
    @Test
    func rootShowsWorkspacesAndSupportsGroupingAndFiltering() async {
        let first = WorkspaceExplorerLiveWorkspace(stableID: UUID(), runtimeID: UUID(),
            title: "Maple Street Roof Inspection", createdAt: .now,
            colorHex: nil, display: nil, lastActivityAt: .now, liveStatus: .needsInput)
        let second = WorkspaceExplorerLiveWorkspace(stableID: UUID(), runtimeID: UUID(),
            title: "Cedar Street Roof Inspection", createdAt: .now,
            colorHex: nil, display: nil, lastActivityAt: .now, liveStatus: .idle)
        let items = WorkspaceExplorerHistoryAdapter().join(live: [first, second], archived: [],
            eligibilityByID: [:])
        let model = WorkspaceExplorerCoordinator(
            loadHistory: { WorkspaceExplorerHistoryLoadResult(items: items,
                archiveAvailability: .available, partialLiveActivity: false) },
            reopenHistory: { _ in false }, activateWorkspace: { _ in },
            loadSessions: { id in ProvenanceWorkspaceSessionPageResponse(
                workspaceID: id.uuidString, sessions: [], nextCursor: nil) },
            clearArchive: { })
        await model.load()

        #expect(model.collectionTarget == nil)
        #expect(Set(model.result()?.visibleWorkspaceIDs ?? []) ==
            Set([first.stableID.uuidString, second.stableID.uuidString]))
        #expect(model.result()?.groups.first?.projectIDs.isEmpty == true)

        model.setGroupBy([.bmuxStatus])
        #expect(model.result()?.groups.count == 2)
        model.setFilter(.bmuxStatus, value: .bmuxStatus(.needsInput))
        #expect(model.result()?.visibleWorkspaceIDs == [first.stableID.uuidString])
    }

    @Test
    func openingExplorerResetsToAllWorkspacesWithoutFiltersOrGrouping() {
        let model = WorkspaceExplorerCoordinator(
            loadHistory: { WorkspaceExplorerHistoryLoadResult(items: [],
                archiveAvailability: .available, partialLiveActivity: false) },
            reopenHistory: { _ in false }, activateWorkspace: { _ in },
            loadSessions: { id in ProvenanceWorkspaceSessionPageResponse(
                workspaceID: id.uuidString, sessions: [], nextCursor: nil) },
            clearArchive: { })
        model.showCollection(.all)
        model.setGroupBy([.repository])
        model.setFilter(.bmuxStatus, value: .bmuxStatus(.needsInput))
        model.scope = WorkspaceExplorerScope(state: .open, period: .today)
        model.showCollection(.project("maple-roof"))
        model.showHistory("history")

        model.openAllWorkspacesUnfiltered()

        #expect(model.collectionTarget == nil)
        #expect(model.historyID == nil)
        #expect(model.scope == WorkspaceExplorerScope(state: .all, period: .anyTime))
        #expect(model.activeArrangement.groupBy.isEmpty)
        #expect(model.activeArrangement.filters.isEmpty)
        #expect(!model.activeArrangement.canUndo)

        model.setGroupBy([.project])
        model.setFilter(.repository, value: .value("bmux"))
        model.openAllWorkspacesUnfiltered()
        #expect(model.activeArrangement.groupBy.isEmpty)
        #expect(model.activeArrangement.filters.isEmpty)
    }
    @Test
    func openingLiveWorkspaceKeepsProjectRouteAndArrangement() async {
        let workspace = WorkspaceExplorerLiveWorkspace(stableID: UUID(), runtimeID: UUID(),
            title: "Maple Street Roof Inspection", createdAt: .now,
            colorHex: nil, display: nil, lastActivityAt: nil, liveStatus: .idle)
        let item = WorkspaceExplorerHistoryAdapter().join(live: [workspace], archived: [],
            eligibilityByID: [:])[0]
        var opened: (WorkspaceExplorerHistoryItem, WorkspaceExplorerCollectionTarget?, String)?
        var activated: UUID?
        let model = WorkspaceExplorerCoordinator(
            loadHistory: { WorkspaceExplorerHistoryLoadResult(items: [item],
                archiveAvailability: .available, partialLiveActivity: false) },
            reopenHistory: { _ in false },
            activateWorkspace: { activated = $0 },
            onOpenLive: { opened = ($0, $1, $2) },
            loadSessions: { id in ProvenanceWorkspaceSessionPageResponse(
                workspaceID: id.uuidString, sessions: [], nextCursor: nil) },
            clearArchive: { }
        )
        await model.load()
        model.showCollection(.unassigned)
        model.setGroupBy([.repository])
        model.open(item)
        #expect(opened?.0.id == workspace.stableID.uuidString)
        #expect(opened?.1 == .unassigned)
        #expect(opened?.2 == String(localized: "explorer.unassigned", defaultValue: "Unassigned workspaces"))
        #expect(activated == workspace.runtimeID)
        #expect(model.collectionTarget == .unassigned)
        #expect(model.activeArrangement.groupBy == [.repository])
    }
}
