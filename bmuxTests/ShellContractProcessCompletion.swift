import Foundation
import os

/// Chooses one native process outcome before asynchronous result consumption can be delayed.
final class ShellContractProcessCompletion: Sendable {
    private typealias Outcome = Swift.Result<Exit, any Error>
    // One-shot synchronous Process/deadline compare-and-set; an actor hop would reorder arrival.
    private let claimed = OSAllocatedUnfairLock(initialState: false)
    let results: AsyncStream<Swift.Result<Exit, any Error>>
    private let signal: AsyncStream<Swift.Result<Exit, any Error>>.Continuation

    init() {
        (results, signal) = AsyncStream.makeStream(bufferingPolicy: .bufferingOldest(1))
    }

    func record(status: Int32) {
        let outcome: Outcome? = claimed.withLock { claimed in
            guard !claimed else { return nil }
            claimed = true
            return .success(Exit(status: status, observedAt: .now))
        }
        publish(outcome)
    }

    func fail(_ error: any Error) {
        let outcome: Outcome? = claimed.withLock { claimed in
            guard !claimed else { return nil }
            claimed = true
            return .failure(error)
        }
        publish(outcome)
    }

    private func publish(_ outcome: Outcome?) {
        guard let outcome else { return }
        signal.yield(outcome)
        signal.finish()
    }
}
