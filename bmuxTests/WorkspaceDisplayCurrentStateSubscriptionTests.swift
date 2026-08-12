import Foundation
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@Suite
struct WorkspaceDisplayCurrentStateSubscriptionTests {
    @MainActor
    @Test
    func refreshesCurrentWorkspaceIDsWhenPEChanges() async throws {
        let fixture = try StoreFixture()
        defer { fixture.remove() }
        let stableWorkspaceID = UUID(uuidString: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")!
        let scheduler = ManualCoalescerScheduler()
        let stream = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        let subscription = WorkspaceDisplayCurrentStateSubscription(
            databaseURL: fixture.databaseURL,
            changeStream: { stream.stream },
            coalescer: NotificationBurstCoalescer(
                delay: 0.05,
                schedule: scheduler.schedule(delay:action:)
            )
        )
        var refreshes: [[UUID]] = []

        subscription.start(
            stableWorkspaceIDs: { [stableWorkspaceID] },
            refresh: { refreshes.append($0) }
        )
        stream.continuation.yield(())
        await scheduler.waitForPendingFlushCount(1)

        #expect(scheduler.delays == [0.05])
        #expect(refreshes.isEmpty)

        scheduler.fire(at: 0)
        #expect(refreshes == [[stableWorkspaceID]])

        subscription.stop()
        stream.continuation.finish()
    }

    @MainActor
    @Test
    func doesNotRetainItselfWhileWaitingForChanges() async throws {
        let fixture = try StoreFixture()
        defer { fixture.remove() }
        let stream = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        var streamRequested = false
        var subscription: WorkspaceDisplayCurrentStateSubscription? = WorkspaceDisplayCurrentStateSubscription(
            databaseURL: fixture.databaseURL,
            changeStream: {
                streamRequested = true
                return stream.stream
            },
            coalescer: NotificationBurstCoalescer(
                delay: 0.05,
                schedule: { _, _ in {} }
            )
        )
        weak var weakSubscription = subscription

        subscription?.start(
            stableWorkspaceIDs: { [] },
            refresh: { _ in }
        )
        await waitForCondition {
            streamRequested
        }

        subscription = nil
        await Task.yield()

        #expect(weakSubscription == nil)
        stream.continuation.finish()
    }

    private struct StoreFixture {
        let directoryURL: URL
        let databaseURL: URL

        init() throws {
            directoryURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("bmux-work-provenance-subscription-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true
            )
            databaseURL = directoryURL.appendingPathComponent("provenance.sqlite")
        }

        func remove() {
            try? FileManager.default.removeItem(at: directoryURL)
        }
    }

    private final class ManualCoalescerScheduler {
        private struct PendingFlush {
            var isCancelled = false
            let action: @MainActor () -> Void
        }

        private var pendingFlushes: [PendingFlush] = []
        private(set) var delays: [TimeInterval] = []

        @MainActor
        func schedule(
            delay: TimeInterval,
            action: @escaping @MainActor () -> Void
        ) -> NotificationBurstCoalescer.Cancellation {
            let index = pendingFlushes.count
            delays.append(delay)
            pendingFlushes.append(PendingFlush(action: action))
            return { [weak self] in
                self?.pendingFlushes[index].isCancelled = true
            }
        }

        @MainActor
        func fire(at index: Int) {
            guard pendingFlushes.indices.contains(index), !pendingFlushes[index].isCancelled else { return }
            pendingFlushes[index].action()
        }

        @MainActor
        func waitForPendingFlushCount(_ count: Int) async {
            for _ in 0..<50 {
                if pendingFlushes.count >= count {
                    return
                }
                await Task.yield()
            }
        }
    }

    @MainActor
    private func waitForCondition(_ condition: @MainActor () -> Bool) async {
        for _ in 0..<50 {
            if condition() {
                return
            }
            await Task.yield()
        }
    }
}
