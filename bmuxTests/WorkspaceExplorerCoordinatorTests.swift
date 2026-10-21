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

    @Test
    func removingStatusGroupingOrFilterReconcilesPendingMembership() async {
        let id = UUID()
        let model = WorkspaceExplorerCoordinator(
            loadHistory: {
                let live = WorkspaceExplorerLiveWorkspace(stableID: id, runtimeID: UUID(),
                    title: "Maple Street Roof Inspection", createdAt: .now,
                    colorHex: nil, display: nil, lastActivityAt: .now,
                    liveStatus: .needsInput)
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
        model.observeLiveStatus(id: id.uuidString, status: .running)
        #expect(model.pendingStatusChangeCount == 1)
        model.setGroupBy([])
        #expect(model.pendingStatusChangeCount == 0)
        #expect(model.catalog?.workspaces.first?.arrangedStatus == .running)

        model.setFilter(.bmuxStatus, value: .bmuxStatus(.running))
        model.observeLiveStatus(id: id.uuidString, status: .idle)
        #expect(model.pendingStatusChangeCount == 1)
        model.clearFilters()
        #expect(model.pendingStatusChangeCount == 0)
        #expect(model.catalog?.workspaces.first?.arrangedStatus == .idle)

        model.setFilter(.bmuxStatus, value: .bmuxStatus(.idle))
        model.observeLiveStatus(id: id.uuidString, status: .error)
        #expect(model.pendingStatusChangeCount == 1)
        model.undo()
        #expect(model.pendingStatusChangeCount == 0)
        #expect(model.catalog?.workspaces.first?.arrangedStatus == .error)
    }

    @Test
    func liveCardsStayUsableWhileArchiveLoadsAndArrangementSurvives() async {
        let liveID = UUID()
        let live = WorkspaceExplorerLiveWorkspace(stableID: liveID, runtimeID: UUID(),
            title: "Maple Street Roof Inspection", createdAt: .now,
            colorHex: nil, display: nil, lastActivityAt: nil, liveStatus: .idle)
        let openItems = WorkspaceExplorerHistoryAdapter().join(live: [live], archived: [], eligibilityByID: [:])
        let pending = WorkspaceExplorerHistoryLoadResult(items: openItems,
            archiveAvailability: .pending, partialLiveActivity: true,
            activeWorkspaceID: liveID.uuidString)
        let closedID = UUID()
        let closedAt = Date()
        let archived = ProvenanceArchivedWorkspaceRecord(id: closedID.uuidString,
            title: "Cedar Street Roof Inspection", createdAt: closedAt.addingTimeInterval(-3600),
            closedAt: closedAt, lastActivityAt: closedAt, displayAtClose: nil,
            colorHex: nil, coverageCode: nil)
        let final = WorkspaceExplorerHistoryLoadResult(
            items: WorkspaceExplorerHistoryAdapter().join(live: [live], archived: [archived],
                eligibilityByID: [:]), archiveAvailability: .available,
            partialLiveActivity: false, activeWorkspaceID: liveID.uuidString)
        var activatedID: UUID?
        let started = AsyncStream<Void>.makeStream()
        let release = AsyncStream<Void>.makeStream()
        let model = WorkspaceExplorerCoordinator(
            loadHistory: {
                started.continuation.yield()
                var iterator = release.stream.makeAsyncIterator()
                _ = await iterator.next()
                return final
            }, loadPresence: { pending },
            reopenHistory: { _ in false }, activateWorkspace: { activatedID = $0 },
            loadSessions: { id in ProvenanceWorkspaceSessionPageResponse(
                workspaceID: id.uuidString, sessions: [], nextCursor: nil) }, clearArchive: { })
        let task = Task { await model.load() }
        var startedIterator = started.stream.makeAsyncIterator()
        _ = await startedIterator.next()
        #expect(model.catalog?.archiveAvailability == .pending)
        #expect(model.result()?.counts.closedKnown == false)
        model.open(openItems[0])
        #expect(activatedID == live.runtimeID)
        model.scope.state = .all
        model.showCollection(.all)
        model.setGroupBy([.workspaceState])
        model.setScrollAnchor("workspace:" + liveID.uuidString)
        release.continuation.yield()
        await task.value
        #expect(model.catalog?.items.count == 2)
        #expect(model.result()?.counts.open == 1)
        #expect(model.result()?.counts.closed == 1)
        #expect(model.catalog?.archiveAvailability == .available)
        #expect(model.activeArrangement.groupBy == [.workspaceState])
        #expect(model.activeArrangement.scrollAnchorID == "workspace:" + liveID.uuidString)
        #expect(model.scope.state == .all)
    }

    @Test
    func refreshingKnownArchiveKeepsClosedCardsUntilReplacementArrives() async {
        let liveID = UUID()
        let closedID = UUID()
        let live = WorkspaceExplorerLiveWorkspace(stableID: liveID, runtimeID: UUID(),
            title: "Maple Street Roof Inspection", createdAt: .now,
            colorHex: nil, display: nil, lastActivityAt: .now)
        let archived = ProvenanceArchivedWorkspaceRecord(id: closedID.uuidString,
            title: "Cedar Street Roof Inspection", createdAt: .now,
            closedAt: .now, lastActivityAt: .now, displayAtClose: nil,
            colorHex: nil, coverageCode: nil)
        let joined = WorkspaceExplorerHistoryAdapter().join(live: [live], archived: [archived],
            eligibilityByID: [:])
        let known = WorkspaceExplorerHistoryLoadResult(items: joined,
            archiveAvailability: .available, partialLiveActivity: false)
        let pending = WorkspaceExplorerHistoryLoadResult(items: Array(joined.filter(\.isOpen)),
            archiveAvailability: .pending, partialLiveActivity: true)
        let started = AsyncStream<Void>.makeStream()
        let release = AsyncStream<Void>.makeStream()
        var loadCount = 0
        let model = WorkspaceExplorerCoordinator(loadHistory: {
            loadCount += 1
            if loadCount == 2 {
                started.continuation.yield()
                var iterator = release.stream.makeAsyncIterator()
                _ = await iterator.next()
            }
            return known
        }, loadPresence: { pending }, reopenHistory: { _ in false },
            activateWorkspace: { _ in }, loadSessions: { id in
                ProvenanceWorkspaceSessionPageResponse(workspaceID: id.uuidString,
                    sessions: [], nextCursor: nil)
            }, clearArchive: { })
        await model.load()
        let refresh = Task { await model.load() }
        var startedIterator = started.stream.makeAsyncIterator()
        _ = await startedIterator.next()
        #expect(model.catalog?.archiveAvailability == .available)
        #expect(model.catalog?.items.count == 2)
        release.continuation.yield()
        await refresh.value
        #expect(model.catalog?.items.count == 2)
    }

    @Test
    func failedArchiveLoadKeepsOpenCardsAndMarksClosedCountUnknown() async {
        let liveID = UUID()
        let live = WorkspaceExplorerLiveWorkspace(stableID: liveID, runtimeID: UUID(),
            title: "Maple Street Roof Inspection", createdAt: .now,
            colorHex: nil, display: nil, lastActivityAt: nil)
        let pending = WorkspaceExplorerHistoryLoadResult(
            items: WorkspaceExplorerHistoryAdapter().join(live: [live], archived: [], eligibilityByID: [:]),
            archiveAvailability: .pending, partialLiveActivity: true)
        let model = WorkspaceExplorerCoordinator(
            loadHistory: { throw WorkspaceExplorerTestError.unavailable }, loadPresence: { pending },
            reopenHistory: { _ in false }, activateWorkspace: { _ in },
            loadSessions: { id in ProvenanceWorkspaceSessionPageResponse(
                workspaceID: id.uuidString, sessions: [], nextCursor: nil) }, clearArchive: { })

        await model.load()
        #expect(model.loadFailed)
        #expect(model.catalog?.archiveAvailability == .unavailable)
        #expect(model.catalog?.items.map(\.id) == [liveID.uuidString])
        #expect(model.result()?.counts.closedKnown == false)
    }

    private func session(_ id: String) -> ProvenanceSessionRecord {
        ProvenanceSessionRecord(id: id, agentKind: "codex", status: "completed", updatedAt: .now)
    }

}

private enum WorkspaceExplorerTestError: Error { case unavailable }
