import XCTest
import Testing
import Foundation

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@Suite(.serialized)
@MainActor
struct OmnibarSuggestionRefreshSchedulerTests {
    @Test func coalescesTypingBurst() async throws {
        let clock = ManualOmnibarSuggestionRefreshClock()
        let scheduler = OmnibarSuggestionRefreshScheduler(debounceDelay: .milliseconds(40), clock: clock)
        let (firstRefresh, signal) = AsyncStream<Void>.makeStream()
        var refreshCount = 0
        let listener = Task { @MainActor in
            for await _ in scheduler.refreshStream {
                refreshCount += 1
                if refreshCount == 1 { signal.yield(()) }
            }
        }
        defer { listener.cancel(); signal.finish() }

        for _ in 0..<20 { scheduler.scheduleRefresh() }
        try await waitForPendingSleep(on: clock)
        await clock.advance()
        _ = try #require(try await withDeadline {
            var iterator = firstRefresh.makeAsyncIterator()
            return await iterator.next()
        })
        await Task.yield()
        listener.cancel()
        await listener.value
        #expect(refreshCount == 1, "A typing burst should emit one debounced refresh.")
    }

    @Test func cancelsPendingRefresh() async throws {
        let clock = ManualOmnibarSuggestionRefreshClock()
        let scheduler = OmnibarSuggestionRefreshScheduler(debounceDelay: .milliseconds(40), clock: clock)
        var refreshCount = 0
        let listener = Task { @MainActor in
            for await _ in scheduler.refreshStream { refreshCount += 1 }
        }
        defer { listener.cancel() }

        scheduler.scheduleRefresh()
        try await waitForPendingSleep(on: clock)
        scheduler.cancelPendingRefresh()
        await clock.advance()
        await Task.yield()
        await Task.yield()
        listener.cancel()
        await listener.value
        #expect(refreshCount == 0)
    }

    @Test func invalidatesQueuedRefreshOnCancel() async throws {
        let clock = ManualOmnibarSuggestionRefreshClock()
        let scheduler = OmnibarSuggestionRefreshScheduler(debounceDelay: .milliseconds(40), clock: clock)
        let stream = scheduler.refreshStream
        scheduler.scheduleRefresh()
        try await waitForPendingSleep(on: clock)
        await clock.advance()
        let generation = try #require(try await withDeadline {
            var iterator = stream.makeAsyncIterator()
            return await iterator.next()
        })
        scheduler.cancelPendingRefresh()
        #expect(!scheduler.shouldProcessRefresh(generation),
                "A refresh queued before cancellation must not run afterward.")
    }

    @Test func cancellingPendingSleepWaitRemovesRegisteredWaiter() async throws {
        let clock = ManualOmnibarSuggestionRefreshClock()
        let waiter = Task { try await clock.waitForPendingSleep() }
        defer { waiter.cancel() }
        try await withDeadline {
            while await clock.pendingWaiterCount == 0 {
                try Task.checkCancellation()
                await Task.yield()
            }
        }
        waiter.cancel()
        try await withDeadline {
            while await clock.pendingWaiterCount != 0 {
                try Task.checkCancellation()
                await Task.yield()
            }
        }
        do {
            try await waiter.value
            Issue.record("A cancelled wait should throw.")
        } catch is CancellationError {
            #expect(await clock.pendingWaiterCount == 0)
        }
    }

    @Test func pendingSleepTimeoutCleansUpWaiter() async throws {
        let clock = ManualOmnibarSuggestionRefreshClock()
        do {
            try await withDeadline(timeout: .milliseconds(10)) {
                try await clock.waitForPendingSleep()
            }
            Issue.record("Waiting for a sleep that was never scheduled should time out.")
        } catch is ClockWaitTimeout {
            #expect(await clock.pendingWaiterCount == 0)
        }
    }

    private func waitForPendingSleep(on clock: ManualOmnibarSuggestionRefreshClock) async throws {
        try await withDeadline { try await clock.waitForPendingSleep() }
    }

    private func withDeadline<T: Sendable>(
        timeout: Duration = .seconds(30),
        _ operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(for: timeout)
                throw ClockWaitTimeout()
            }
            defer { group.cancelAll() }
            guard let result = try await group.next() else { throw ClockWaitTimeout() }
            return result
        }
    }

    private struct ClockWaitTimeout: Error {}
}

final class BrowserOmnibarPerformanceSupportTests: XCTestCase {
    func testOmnibarBufferChangeClearsInlineCompletionBeforeDebouncedRefresh() {
        var state = OmnibarState(
            isFocused: true,
            currentURLString: "",
            buffer: "g",
            suggestions: [],
            selectedSuggestionIndex: 0,
            selectedSuggestionID: nil,
            isUserEditing: true
        )

        let effects = omnibarReduce(state: &state, event: .bufferChanged("go"))

        XCTAssertTrue(effects.shouldRefreshSuggestions)
        XCTAssertTrue(effects.shouldClearInlineCompletion)
    }

    func testOmnibarUnchangedBufferKeepsInlineCompletionStable() {
        var state = OmnibarState(
            isFocused: true,
            currentURLString: "",
            buffer: "go",
            suggestions: [],
            selectedSuggestionIndex: 0,
            selectedSuggestionID: nil,
            isUserEditing: true
        )

        let effects = omnibarReduce(state: &state, event: .bufferChanged("go"))

        XCTAssertTrue(effects.shouldRefreshSuggestions)
        XCTAssertFalse(effects.shouldClearInlineCompletion)
    }

    func testOmnibarEscapeCancelsPendingSuggestionRefresh() {
        var state = OmnibarState(
            isFocused: true,
            currentURLString: "",
            buffer: "go",
            suggestions: [],
            selectedSuggestionIndex: 0,
            selectedSuggestionID: nil,
            isUserEditing: true
        )

        let effects = omnibarReduce(state: &state, event: .escape)

        XCTAssertTrue(effects.shouldSelectAll)
        XCTAssertTrue(effects.shouldCancelPendingSuggestionRefresh)
        XCTAssertEqual(state.buffer, "")
        XCTAssertFalse(state.isUserEditing)
    }

    func testOpenTabSuggestionSeedSnapshotsAreEvaluatedOnlyOnce() {
        let workspaceId = UUID()
        let panelId = UUID()
        let snapshot = BrowserOpenTabSuggestionSnapshot(
            workspaceId: workspaceId,
            panelId: panelId,
            url: "https://example.com/docs",
            title: "Example Docs"
        )
        XCTAssertNotNil(snapshot)

        let index = BrowserOpenTabSuggestionIndex()
        var seedCallCount = 0

        func matches(for query: String) -> [OmnibarOpenTabMatch] {
            index.matching(
                for: query,
                currentWorkspaceId: UUID(),
                currentPanelId: UUID(),
                currentPanelSnapshot: nil,
                includeCurrentPanelForSingleCharacterQuery: false,
                limit: 5,
                seedSnapshots: {
                    seedCallCount += 1
                    return [snapshot!]
                }
            )
        }

        XCTAssertEqual(matches(for: "example").map(\.url), ["https://example.com/docs"])
        XCTAssertEqual(matches(for: "docs").map(\.url), ["https://example.com/docs"])
        XCTAssertEqual(seedCallCount, 1)
    }

    func testNonMatchingCurrentSnapshotDoesNotDedupeIndexedMatch() {
        let workspaceId = UUID()
        let panelId = UUID()
        let url = "https://example.com/"
        let currentSnapshot = BrowserOpenTabSuggestionSnapshot(
            workspaceId: workspaceId,
            panelId: panelId,
            url: url,
            title: nil
        )
        let indexedSnapshot = BrowserOpenTabSuggestionSnapshot(
            workspaceId: workspaceId,
            panelId: panelId,
            url: url,
            title: "Docs"
        )
        XCTAssertNotNil(currentSnapshot)
        XCTAssertNotNil(indexedSnapshot)

        let index = BrowserOpenTabSuggestionIndex()
        let matches = index.matching(
            for: "d",
            currentWorkspaceId: workspaceId,
            currentPanelId: panelId,
            currentPanelSnapshot: currentSnapshot,
            includeCurrentPanelForSingleCharacterQuery: true,
            limit: 5,
            seedSnapshots: { [indexedSnapshot!] }
        )

        XCTAssertEqual(matches.map(\.title), ["Docs"])
        XCTAssertEqual(matches.map(\.url), [url])
    }


}

private actor ManualOmnibarSuggestionRefreshClock: OmnibarSuggestionRefreshClock {
    private var continuations: [UUID: CheckedContinuation<Void, Error>] = [:]
    private var pendingSleepWaiters: [UUID: CheckedContinuation<Void, Error>] = [:]
    var pendingWaiterCount: Int { pendingSleepWaiters.count }

    func sleep(for duration: Duration) async throws {
        let id = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                continuations[id] = continuation
                resumePendingSleepWaiters()
            }
        } onCancel: {
            Task {
                await self.cancel(id)
            }
        }
    }

    func waitForPendingSleep() async throws {
        guard continuations.isEmpty else { return }
        let id = UUID()
        try await withTaskCancellationHandler {
            try Task.checkCancellation()
            try await withCheckedThrowingContinuation { continuation in
                pendingSleepWaiters[id] = continuation
            }
        } onCancel: {
            Task { await self.cancelWaiter(id) }
        }
    }

    private func cancelWaiter(_ id: UUID) {
        pendingSleepWaiters.removeValue(forKey: id)?.resume(throwing: CancellationError())
    }

    func advance() {
        let pendingContinuations = Array(continuations.values)
        continuations.removeAll(keepingCapacity: true)
        for continuation in pendingContinuations {
            continuation.resume()
        }
    }

    private func cancel(_ id: UUID) {
        continuations.removeValue(forKey: id)?.resume(throwing: CancellationError())
    }

    private func resumePendingSleepWaiters() {
        let waiters = Array(pendingSleepWaiters.values)
        pendingSleepWaiters.removeAll(keepingCapacity: true)
        for waiter in waiters {
            waiter.resume()
        }
    }
}
