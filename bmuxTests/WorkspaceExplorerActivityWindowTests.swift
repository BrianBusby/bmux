import BmuxWorkspaces
import Foundation
import Observation
import ProvenanceEngineContracts
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@Suite @MainActor
struct WorkspaceExplorerActivityWindowTests {
    @Test
    func rollingScopeExpiresWithoutAnotherWorkspaceEvent() async throws {
        let id = UUID()
        let initialNow = Date(timeIntervalSince1970: 1_000_000)
        var currentNow = initialNow
        let deadline = AsyncStream<Void>.makeStream()
        let scheduled = AsyncStream<Void>.makeStream()
        let clock = WorkspaceExplorerActivityClock(currentDate: { currentNow }, sleep: { _ in
            scheduled.continuation.yield()
            var iterator = deadline.stream.makeAsyncIterator()
            guard await iterator.next() != nil else { throw CancellationError() }
        })
        let activity = initialNow.addingTimeInterval(-24 * 60 * 60 + 0.4)
        let live = WorkspaceExplorerLiveWorkspace(stableID: id, runtimeID: UUID(),
            title: "Maple Street Roof Inspection", createdAt: activity,
            colorHex: nil, display: nil, lastActivityAt: activity)
        let item = WorkspaceExplorerHistoryAdapter().join(live: [live], archived: [],
            eligibilityByID: [:])[0]
        let model = WorkspaceExplorerCoordinator(loadHistory: {
            WorkspaceExplorerHistoryLoadResult(items: [item], archiveAvailability: .available,
                partialLiveActivity: false)
        }, reopenHistory: { _ in false }, activateWorkspace: { _ in },
           loadSessions: { id in ProvenanceWorkspaceSessionPageResponse(
               workspaceID: id.uuidString, sessions: [], nextCursor: nil) },
           clearArchive: { }, activityClock: clock)
        await model.load()
        model.showCollection(.all)
        model.setScopePeriod(.last24Hours)
        #expect(model.result()?.visibleWorkspaceIDs == [id.uuidString])
        let didSchedule = await receivesSignal(scheduled.stream)
        #expect(didSchedule)
        guard didSchedule else { return }
        let changed = AsyncStream<Void>.makeStream()
        withObservationTracking({ _ = model.result() }, onChange: { changed.continuation.yield() })
        currentNow = initialNow.addingTimeInterval(0.402)
        deadline.continuation.yield()
        #expect(await receivesSignal(changed.stream))
        #expect(model.result()?.visibleWorkspaceIDs.isEmpty == true)
    }

    @Test
    func hoveredCardKeepsPeriodMembershipAndCountsUntilUpdate() async {
        let id = UUID()
        let initialNow = Date(timeIntervalSince1970: 1_000_000)
        var currentNow = initialNow
        let deadline = AsyncStream<Void>.makeStream()
        let scheduled = AsyncStream<Void>.makeStream()
        let clock = WorkspaceExplorerActivityClock(currentDate: { currentNow }, sleep: { _ in
            scheduled.continuation.yield()
            var iterator = deadline.stream.makeAsyncIterator()
            guard await iterator.next() != nil else { throw CancellationError() }
        })
        let activity = initialNow.addingTimeInterval(-24 * 60 * 60 + 0.4)
        let live = WorkspaceExplorerLiveWorkspace(stableID: id, runtimeID: UUID(),
            title: "Maple Street Roof Inspection", createdAt: activity,
            colorHex: nil, display: nil, lastActivityAt: activity)
        let item = WorkspaceExplorerHistoryAdapter().join(live: [live], archived: [],
            eligibilityByID: [:])[0]
        let model = WorkspaceExplorerCoordinator(loadHistory: {
            WorkspaceExplorerHistoryLoadResult(items: [item], archiveAvailability: .available,
                partialLiveActivity: false)
        }, reopenHistory: { _ in false }, activateWorkspace: { _ in },
           loadSessions: { id in ProvenanceWorkspaceSessionPageResponse(
               workspaceID: id.uuidString, sessions: [], nextCursor: nil) },
           clearArchive: { }, activityClock: clock)
        await model.load()
        model.showCollection(.all)
        model.setScopePeriod(.last24Hours)
        model.activityArrangement.cardInteractionChanged(id: "workspace:\(id.uuidString)", active: true)
        let didSchedule = await receivesSignal(scheduled.stream)
        #expect(didSchedule)
        guard didSchedule else { return }
        let changed = AsyncStream<Void>.makeStream()
        withObservationTracking({ _ = model.activityArrangement.hasPendingUpdate },
            onChange: { changed.continuation.yield() })
        currentNow.addTimeInterval(0.402)
        deadline.continuation.yield()
        #expect(await receivesSignal(changed.stream))
        #expect(model.activityArrangement.hasPendingUpdate)
        #expect(model.result()?.visibleWorkspaceIDs == [id.uuidString])
        #expect(model.result()?.visibleCounts.workspaces == 1)
        model.activityArrangement.applyPending()
        #expect(model.result()?.visibleWorkspaceIDs.isEmpty == true)
        #expect(model.result()?.visibleCounts.workspaces == 0)
    }

    @Test
    func hoveredCardStaysVisibleWhenItsActivityRefreshes() async {
        let id = UUID()
        let initialNow = Date(timeIntervalSince1970: 1_000_000)
        var currentNow = initialNow
        let clock = WorkspaceExplorerActivityClock(currentDate: { currentNow }, sleep: { _ in
            throw CancellationError()
        })
        func historyItem(activity: Date) -> WorkspaceExplorerHistoryItem {
            let live = WorkspaceExplorerLiveWorkspace(stableID: id, runtimeID: UUID(),
                title: "Maple Street Roof Inspection", createdAt: initialNow,
                colorHex: nil, display: nil, lastActivityAt: activity)
            return WorkspaceExplorerHistoryAdapter().join(live: [live], archived: [],
                eligibilityByID: [:])[0]
        }
        var loadedItem = historyItem(activity: initialNow)
        let model = WorkspaceExplorerCoordinator(loadHistory: {
            WorkspaceExplorerHistoryLoadResult(items: [loadedItem], archiveAvailability: .available,
                partialLiveActivity: false)
        }, reopenHistory: { _ in false }, activateWorkspace: { _ in },
           loadSessions: { id in ProvenanceWorkspaceSessionPageResponse(
               workspaceID: id.uuidString, sessions: [], nextCursor: nil) },
           clearArchive: { }, activityClock: clock)
        await model.load()
        model.showCollection(.all)
        model.setScopePeriod(.today)
        model.activityArrangement.cardInteractionChanged(id: "workspace:\(id.uuidString)", active: true)
        #expect(model.result()?.visibleWorkspaceIDs == [id.uuidString])

        currentNow.addTimeInterval(60)
        loadedItem = historyItem(activity: currentNow)
        await model.load()
        #expect(model.result()?.visibleWorkspaceIDs == [id.uuidString])
        #expect(model.result()?.visibleCounts.workspaces == 1)
    }

    @Test
    func closingExplorerInvalidatesLateArchiveLoad() async {
        let initialNow = Date(timeIntervalSince1970: 1_000_000)
        var currentNow = initialNow
        let clock = WorkspaceExplorerActivityClock(currentDate: { currentNow }, sleep: { _ in })
        var completeLoad: CheckedContinuation<WorkspaceExplorerHistoryLoadResult, Never>?
        var loadStarted: CheckedContinuation<Void, Never>?
        let model = WorkspaceExplorerCoordinator(loadHistory: {
            await withCheckedContinuation { continuation in
                completeLoad = continuation
                loadStarted?.resume()
            }
        }, reopenHistory: { _ in false }, activateWorkspace: { _ in },
           loadSessions: { id in ProvenanceWorkspaceSessionPageResponse(
               workspaceID: id.uuidString, sessions: [], nextCursor: nil) },
           clearArchive: { }, activityClock: clock)
        let loading = Task { await model.load() }
        await withCheckedContinuation { continuation in
            if completeLoad != nil { continuation.resume() } else { loadStarted = continuation }
        }
        model.stopLiveStatusMonitoring()
        currentNow = initialNow.addingTimeInterval(5)
        completeLoad?.resume(returning: WorkspaceExplorerHistoryLoadResult(items: [],
            archiveAvailability: .available, partialLiveActivity: false))
        await loading.value
        #expect(model.catalog == nil)
        #expect(clock.now == initialNow)
    }

    @Test
    func closingExplorerDoesNotResampleAfterLateSessionPage() async {
        let initialNow = Date(timeIntervalSince1970: 1_000_000)
        var currentNow = initialNow
        let clock = WorkspaceExplorerActivityClock(currentDate: { currentNow }, sleep: { _ in })
        let started = AsyncStream<Void>.makeStream()
        let release = AsyncStream<Void>.makeStream()
        let model = WorkspaceExplorerCoordinator(loadHistory: {
            WorkspaceExplorerHistoryLoadResult(items: [], archiveAvailability: .available,
                partialLiveActivity: false)
        }, reopenHistory: { _ in false }, activateWorkspace: { _ in },
           loadSessions: { id in
               started.continuation.yield()
               var iterator = release.stream.makeAsyncIterator()
               _ = await iterator.next()
               return ProvenanceWorkspaceSessionPageResponse(
                   workspaceID: id.uuidString, sessions: [], nextCursor: nil)
           }, clearArchive: { }, activityClock: clock)
        let id = UUID().uuidString
        model.showHistory(id)
        let loading = Task { await model.loadHistorySessions(for: id) }
        let didStart = await receivesSignal(started.stream)
        #expect(didStart)
        guard didStart else { return }
        model.stopLiveStatusMonitoring()
        currentNow = initialNow.addingTimeInterval(5)
        release.continuation.yield()
        await loading.value
        #expect(clock.now == initialNow)
    }

    private func receivesSignal(_ stream: AsyncStream<Void>) async -> Bool {
        await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                var iterator = stream.makeAsyncIterator()
                return await iterator.next() != nil
            }
            group.addTask {
                // A bounded failure deadline; correctness waits on the stream signal.
                try? await ContinuousClock().sleep(for: .seconds(5))
                return false
            }
            let arrived = await group.next() ?? false
            group.cancelAll()
            return arrived
        }
    }
}
