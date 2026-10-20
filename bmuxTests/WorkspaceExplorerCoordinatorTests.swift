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

    @Test
    func sessionPaginationDeduplicatesAndKeepsContinuation() async {
        let stableID = UUID()
        let first = ProvenanceWorkspaceSessionSummary(session: session("one"), lastActivityAt: .now)
        let second = ProvenanceWorkspaceSessionSummary(session: session("two"), lastActivityAt: .now)
        let model = WorkspaceExplorerCoordinator(
            loadHistory: { WorkspaceExplorerHistoryLoadResult(items: [],
                archiveAvailability: .available, partialLiveActivity: false) },
            reopenHistory: { _ in false }, activateWorkspace: { _ in },
            loadSessions: { id in ProvenanceWorkspaceSessionPageResponse(
                workspaceID: id.uuidString, sessions: [first], nextCursor: "next") },
            loadMoreSessions: { id, cursor in
                #expect(cursor == "next")
                return ProvenanceWorkspaceSessionPageResponse(
                    workspaceID: id.uuidString, sessions: [first, second], nextCursor: nil)
            },
            clearArchive: { }
        )
        await model.loadHistorySessions(for: stableID.uuidString)
        await model.loadMoreHistorySessions(for: stableID.uuidString)
        #expect(model.sessionsByWorkspaceID[stableID.uuidString]?.sessions.map(\.id) == ["one", "two"])
        #expect(model.sessionsByWorkspaceID[stableID.uuidString]?.nextCursor == nil)
    }

    @Test
    func scrollAnchorIsKeptPerCollection() {
        let model = WorkspaceExplorerCoordinator(
            loadHistory: { WorkspaceExplorerHistoryLoadResult(items: [],
                archiveAvailability: .available, partialLiveActivity: false) },
            reopenHistory: { _ in false }, activateWorkspace: { _ in },
            loadSessions: { id in ProvenanceWorkspaceSessionPageResponse(
                workspaceID: id.uuidString, sessions: [], nextCursor: nil) },
            clearArchive: { }
        )
        model.setScrollAnchor("project:p1")
        model.showCollection(.project("p1"))
        model.setScrollAnchor("workspace:w1")
        model.showOverview()
        #expect(model.activeArrangement.scrollAnchorID == "project:p1")
        model.showCollection(.project("p1"))
        #expect(model.activeArrangement.scrollAnchorID == "workspace:w1")
    }

    @Test
    func statusRefreshHoldsGroupedMembershipUntilApplied() async {
        let id = UUID()
        var currentStatus: WorkspaceExplorerStatus = .needsInput
        let model = WorkspaceExplorerCoordinator(
            loadHistory: {
                let live = WorkspaceExplorerLiveWorkspace(stableID: id, runtimeID: UUID(),
                    title: "Maple Street Roof Inspection", createdAt: .now,
                    colorHex: nil, display: nil, lastActivityAt: .now,
                    liveStatus: currentStatus)
                return WorkspaceExplorerHistoryLoadResult(
                    items: WorkspaceExplorerHistoryAdapter().join(live: [live], archived: [],
                        eligibilityByID: [:]),
                    archiveAvailability: .available, partialLiveActivity: false)
            },
            reopenHistory: { _ in false }, activateWorkspace: { _ in },
            loadSessions: { id in ProvenanceWorkspaceSessionPageResponse(
                workspaceID: id.uuidString, sessions: [], nextCursor: nil) },
            clearArchive: { }
        )
        model.showCollection(.all)
        model.setGroupBy([.bmuxStatus])
        await model.load()
        currentStatus = .running
        await model.load()
        #expect(model.pendingStatusChangeCount == 1)
        #expect(model.catalog?.workspaces.first?.liveStatus == .running)
        #expect(model.catalog?.workspaces.first?.arrangedStatus == .needsInput)
        model.applyPendingStatusArrangement()
        #expect(model.pendingStatusChangeCount == 0)
        #expect(model.catalog?.workspaces.first?.arrangedStatus == .running)
    }

    private func session(_ id: String) -> ProvenanceSessionRecord {
        ProvenanceSessionRecord(id: id, agentKind: "codex", status: "completed", updatedAt: .now)
    }

}
