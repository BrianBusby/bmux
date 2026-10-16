import BmuxGit
import BmuxSidebarGit
import Foundation

actor BlockingWorkspaceGitMetadataReader: WorkspaceGitMetadataReading {
    struct Observation: Sendable {
        let id: UUID
        let counts: AsyncStream<Int>
    }
    private enum Failure: Error { case observationEnded }

    private let metadata: GitWorkspaceMetadata
    private(set) var observedCallCount = 0
    private(set) var observedMaxActiveCallCount = 0
    private(set) var activeCallCount = 0
    private var observations: [UUID: AsyncStream<Int>.Continuation] = [:]
    private var gates: [UUID: AsyncStream<Void>.Continuation] = [:]
    private var isReleased = false
    private var drainWaiters: [CheckedContinuation<Void, Never>] = []

    init(metadata: GitWorkspaceMetadata) {
        self.metadata = metadata
    }

    func workspaceMetadata(for directory: String) async -> GitWorkspaceMetadata {
        observedCallCount += 1
        activeCallCount += 1
        observedMaxActiveCallCount = max(observedMaxActiveCallCount, activeCallCount)
        for continuation in observations.values { continuation.yield(observedCallCount) }
        let id = UUID()
        defer {
            gates.removeValue(forKey: id)?.finish()
            activeCallCount -= 1
            if activeCallCount == 0 {
                let waiters = drainWaiters
                drainWaiters.removeAll()
                for waiter in waiters { waiter.resume() }
            }
        }
        if !isReleased {
            let (events, continuation) = AsyncStream<Void>.makeStream()
            gates[id] = continuation
            // Cancellation ends this read's iterator; releaseAll also finishes it.
            for await _ in events { break }
        }
        return metadata
    }

    func observeCallCounts() -> Observation {
        let id = UUID()
        let (events, continuation) = AsyncStream<Int>.makeStream(bufferingPolicy: .bufferingNewest(1))
        observations[id] = continuation
        continuation.yield(observedCallCount)
        return Observation(id: id, counts: events)
    }

    func waitForCallCount(
        _ expected: Int,
        observation: Observation,
        until deadline: ContinuousClock.Instant
    ) async throws -> Bool {
        defer { observations.removeValue(forKey: observation.id)?.finish() }
        return try await withThrowingTaskGroup(of: Bool.self) { group in
            group.addTask {
                for await count in observation.counts {
                    if count >= expected { return true }
                }
                try Task.checkCancellation()
                throw Failure.observationEnded
            }
            group.addTask {
                // A genuine bounded first-read/absence window, never settling or polling.
                try await ContinuousClock().sleep(until: deadline)
                return false
            }
            defer { group.cancelAll() }
            return try await group.next() ?? false
        }
    }

    func releaseAll() {
        isReleased = true
        for continuation in gates.values { continuation.finish() }
    }

    func releaseAllAndDrain() async {
        releaseAll()
        if activeCallCount > 0 {
            // Every active reader now has a finished gate; its defer resumes this
            // drain even if this cleanup caller was already cancelled.
            await withCheckedContinuation { drainWaiters.append($0) }
        }
        for continuation in observations.values { continuation.finish() }
        observations.removeAll()
    }

    var observationCount: Int { observations.count }
}
