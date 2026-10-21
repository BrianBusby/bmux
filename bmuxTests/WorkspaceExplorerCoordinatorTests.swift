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
    func openingLiveWorkspaceKeepsProjectRouteAndArrangement() async {
        let workspace = WorkspaceExplorerLiveWorkspace(stableID: UUID(), runtimeID: UUID(),
            title: "Maple Street Roof Inspection", createdAt: .now,
            colorHex: nil, display: nil, lastActivityAt: nil, liveStatus: .idle)
        let item = WorkspaceExplorerHistoryAdapter().join(live: [workspace], archived: [],
            eligibilityByID: [:])[0]
        var opened: (UUID, String)?
        var activated: UUID?
        let model = WorkspaceExplorerCoordinator(
            loadHistory: { WorkspaceExplorerHistoryLoadResult(items: [item],
                archiveAvailability: .available, partialLiveActivity: false) },
            reopenHistory: { _ in false },
            activateWorkspace: { activated = $0 },
            onOpenLive: { opened = ($0, $1) },
            loadSessions: { id in ProvenanceWorkspaceSessionPageResponse(
                workspaceID: id.uuidString, sessions: [], nextCursor: nil) },
            clearArchive: { }
        )
        await model.load()
        model.showCollection(.unassigned)
        model.setGroupBy([.repository])
        model.open(item)
        #expect(opened?.0 == workspace.runtimeID)
        #expect(opened?.1 == String(localized: "explorer.unassigned", defaultValue: "Unassigned workspaces"))
        #expect(activated == workspace.runtimeID)
        #expect(model.collectionTarget == .unassigned)
        #expect(model.activeArrangement.groupBy == [.repository])
    }

    @Test
    func newWorkspaceAppearsWhileExplorerRefreshes() async {
        let first = WorkspaceExplorerLiveWorkspace(stableID: UUID(), runtimeID: UUID(),
            title: "Maple Street Roof Inspection", createdAt: .now,
            colorHex: nil, display: nil, lastActivityAt: nil, liveStatus: .disconnected)
        let second = WorkspaceExplorerLiveWorkspace(stableID: UUID(), runtimeID: UUID(),
            title: "Cedar Street Roof Inspection", createdAt: .now,
            colorHex: nil, display: nil, lastActivityAt: nil, liveStatus: .disconnected)
        let adapter = WorkspaceExplorerHistoryAdapter()
        var live = [first]
        var loads = 0
        let started = AsyncStream<Void>.makeStream()
        let release = AsyncStream<Void>.makeStream()
        let model = WorkspaceExplorerCoordinator(loadHistory: {
            loads += 1
            if loads == 2 {
                started.continuation.yield()
                var iterator = release.stream.makeAsyncIterator()
                _ = await iterator.next()
            }
            return WorkspaceExplorerHistoryLoadResult(
                items: adapter.join(live: live, archived: [], eligibilityByID: [:]),
                archiveAvailability: .available, partialLiveActivity: false)
        }, loadPresence: {
            WorkspaceExplorerHistoryLoadResult(
                items: adapter.join(live: live, archived: [], eligibilityByID: [:]),
                archiveAvailability: .pending, partialLiveActivity: true,
                liveMetadataPending: true)
        }, reopenHistory: { _ in false }, activateWorkspace: { _ in },
           loadSessions: { id in ProvenanceWorkspaceSessionPageResponse(
               workspaceID: id.uuidString, sessions: [], nextCursor: nil) }, clearArchive: { })
        await model.load()
        model.setGroupBy([.repository])
        live.append(second)
        let refresh = Task { await model.refreshForTopologyChange() }
        var iterator = started.stream.makeAsyncIterator()
        _ = await iterator.next()
        #expect(model.pendingWorkspaceItems.map(\.id) == [second.stableID.uuidString])
        #expect(model.visiblePendingWorkspaceItems.count == 1)
        model.observeLiveStatus(id: second.stableID.uuidString, status: .running)
        #expect(model.pendingWorkspaceItems.first?.liveStatus == .running)
        model.scope.state = .closed
        #expect(model.visiblePendingWorkspaceItems.isEmpty)
        model.scope.state = .open
        model.setFilter(.repository, value: .value("unknown"))
        #expect(model.visiblePendingWorkspaceItems.isEmpty)
        model.clearFilters()
        #expect(model.catalog?.items.map(\.id) == [first.stableID.uuidString])
        #expect(model.activeArrangement.groupBy == [.repository])
        release.continuation.yield()
        await refresh.value
        #expect(model.pendingWorkspaceItems.isEmpty)
        #expect(Set(model.catalog?.items.map(\.id) ?? []) ==
            [first.stableID.uuidString, second.stableID.uuidString])
    }

    @Test
    func workspaceListMutationNotifiesExplorerWithoutPolling() async {
        let manager = TabManager()
        let monitor = WorkspaceExplorerWorkspaceChangeMonitor(tabManagers: { [manager] })
        let changes = AsyncStream<Void>.makeStream()
        monitor.start { changes.continuation.yield() }
        _ = manager.addWorkspace()
        var iterator = changes.stream.makeAsyncIterator()
        #expect(await iterator.next() != nil)
        monitor.stop()
    }

    @Test
    func workspaceMonitorRebindsWhenWindowContextsChange() async {
        let first = TabManager()
        let second = TabManager()
        var managers = [first]
        let monitor = WorkspaceExplorerWorkspaceChangeMonitor(tabManagers: { managers })
        let changes = AsyncStream<Void>.makeStream()
        monitor.start { changes.continuation.yield() }
        var iterator = changes.stream.makeAsyncIterator()
        managers.append(second)
        monitor.windowContextsChanged()
        #expect(await iterator.next() != nil)
        managers.removeLast()
        monitor.windowContextsChanged()
        #expect(await iterator.next() != nil)
        monitor.stop()
    }

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
    func refreshKeepsKnownProjectMembershipWhenArchiveIsUnavailable() async {
        let liveID = UUID()
        let display = ProvenanceWorkspaceDisplayRecord(
            id: "known-display", workspaceID: liveID.uuidString,
            projectLinks: [.init(id: "maple-roof", title: "Maple Street Roof Inspection")],
            observedAt: .now, updatedAt: .now)
        let knownLive = WorkspaceExplorerLiveWorkspace(stableID: liveID, runtimeID: UUID(),
            title: "Roof review", createdAt: .now, colorHex: nil,
            display: display, lastActivityAt: .now)
        let provisionalLive = WorkspaceExplorerLiveWorkspace(stableID: liveID, runtimeID: UUID(),
            title: "Roof review", createdAt: .now, colorHex: nil,
            display: nil, lastActivityAt: nil)
        let adapter = WorkspaceExplorerHistoryAdapter()
        let known = WorkspaceExplorerHistoryLoadResult(
            items: adapter.join(live: [knownLive], archived: [], eligibilityByID: [:]),
            archiveAvailability: .unavailable, partialLiveActivity: false)
        let pending = WorkspaceExplorerHistoryLoadResult(
            items: adapter.join(live: [provisionalLive], archived: [], eligibilityByID: [:]),
            archiveAvailability: .pending, partialLiveActivity: true, liveMetadataPending: true)
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
        model.showCollection(.project("maple-roof"))
        let refresh = Task { await model.load() }
        var startedIterator = started.stream.makeAsyncIterator()
        _ = await startedIterator.next()
        #expect(model.catalog?.liveMetadataPending == false)
        #expect(model.result()?.visibleWorkspaceIDs == [liveID.uuidString])
        #expect(model.catalog?.workspaces.first?.projectIDs == ["maple-roof"])
        release.continuation.yield()
        await refresh.value
    }

    @Test
    func pendingAllCollectionDoesNotAssignUnknownProjectsOrShowFalseProjectResults() async {
        let liveID = UUID()
        let live = WorkspaceExplorerLiveWorkspace(stableID: liveID, runtimeID: UUID(),
            title: "Roof review", createdAt: .now, colorHex: nil,
            display: nil, lastActivityAt: nil)
        let pending = WorkspaceExplorerHistoryLoadResult(
            items: WorkspaceExplorerHistoryAdapter().join(live: [live], archived: [],
                eligibilityByID: [:]), archiveAvailability: .pending,
            partialLiveActivity: true, liveMetadataPending: true)
        let started = AsyncStream<Void>.makeStream()
        let release = AsyncStream<Void>.makeStream()
        let model = WorkspaceExplorerCoordinator(loadHistory: {
            started.continuation.yield()
            var iterator = release.stream.makeAsyncIterator()
            _ = await iterator.next()
            return pending
        }, loadPresence: { pending }, reopenHistory: { _ in false },
            activateWorkspace: { _ in }, loadSessions: { id in
                ProvenanceWorkspaceSessionPageResponse(workspaceID: id.uuidString,
                    sessions: [], nextCursor: nil)
            }, clearArchive: { })
        let load = Task { await model.load() }
        var startedIterator = started.stream.makeAsyncIterator()
        _ = await startedIterator.next()
        model.showCollection(.all)
        model.setGroupBy([.project])
        #expect(model.result()?.visibleWorkspaceIDs == [liveID.uuidString])
        #expect(model.result()?.groups.count == 1)
        #expect(model.result()?.groups.first?.dimension == nil)
        model.showCollection(.unassigned)
        #expect(model.result() == nil)
        model.showCollection(.project("maple-roof"))
        #expect(model.result() == nil)
        release.continuation.yield()
        await load.value
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
