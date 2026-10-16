import Foundation

/// Observes the FIFO event boundary after TabManager queues selection effects.
@MainActor
struct WorkspaceStressQueueDelivery {
    func wait(timeout: Duration = .seconds(1)) async throws {
        let deadline = ContinuousClock.now.advanced(by: timeout)
        let delivery = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        defer { delivery.continuation.finish() }
        // TabManager delivers selection effects on this queue. This callback observes that
        // concrete FIFO boundary; it does not poll or pretend all descendant work is settled.
        DispatchQueue.main.async {
            delivery.continuation.yield(())
            delivery.continuation.finish()
        }
        try await withThrowingTaskGroup(of: Void.self) { group in
            defer { group.cancelAll() }
            group.addTask {
                for await _ in delivery.stream { return }
                throw CancellationError()
            }
            group.addTask {
                // Original one-second failure bound, canceled/joined after actual delivery.
                try await ContinuousClock().sleep(until: deadline)
                throw DeliveryFailure.timedOut
            }
            try await group.next()
        }
        try Task.checkCancellation()
    }

    private enum DeliveryFailure: Error { case timedOut }
}
