import BMUXMobileCore
import BmuxMobileRPC
import Foundation
import Testing

final class CountingSlowIgnoringCancellationTransportFactory: CmxByteTransportFactory, @unchecked Sendable {
    let transport: CountingSlowIgnoringCancellationTransport
    private let lock = NSLock()
    private var invocations = 0
    private var waiters: [(UUID, Int, CheckedContinuation<Void, Never>)] = []

    init(transport: CountingSlowIgnoringCancellationTransport) {
        self.transport = transport
    }

    func makeTransport(for route: CmxAttachRoute) throws -> any CmxByteTransport {
        let satisfied = lock.withLock {
            invocations += 1
            return removeSatisfiedWaitersLocked()
        }
        for continuation in satisfied {
            continuation.resume()
        }
        return transport
    }

    func makeTransportCount() -> Int {
        lock.withLock { invocations }
    }

    @discardableResult
    func waitForMakeTransportCount(
        atLeast expectedCount: Int,
        timeoutNanoseconds: UInt64 = 3_000_000_000,
        recordIssueOnTimeout: Bool = true
    ) async -> Bool {
        let reached = await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                await self.waitUntilMakeTransportCount(atLeast: expectedCount)
                return true
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: timeoutNanoseconds)
                return false
            }
            let reached = await group.next() ?? false
            group.cancelAll()
            return reached
        }
        if !reached, recordIssueOnTimeout {
            Issue.record("timed out waiting for transport factory count >= \(expectedCount)")
        }
        return reached
    }

    private func waitUntilMakeTransportCount(atLeast expectedCount: Int) async {
        if makeTransportCount() >= expectedCount { return }
        let waiterID = UUID()
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                let satisfied = lock.withLock {
                    waiters.append((waiterID, expectedCount, continuation))
                    return removeSatisfiedWaitersLocked()
                }
                for continuation in satisfied {
                    continuation.resume()
                }
            }
        } onCancel: {
            self.cancelWaiter(id: waiterID)
        }
    }

    private func cancelWaiter(id: UUID) {
        let continuation: CheckedContinuation<Void, Never>? = lock.withLock {
            guard let index = waiters.firstIndex(where: { $0.0 == id }) else { return nil }
            return waiters.remove(at: index).2
        }
        continuation?.resume()
    }

    private func removeSatisfiedWaitersLocked() -> [CheckedContinuation<Void, Never>] {
        var remaining: [(UUID, Int, CheckedContinuation<Void, Never>)] = []
        var satisfied: [CheckedContinuation<Void, Never>] = []
        for waiter in waiters {
            if invocations >= waiter.1 {
                satisfied.append(waiter.2)
            } else {
                remaining.append(waiter)
            }
        }
        waiters = remaining
        return satisfied
    }
}
