import Foundation
import os

/// Chooses a probe outcome synchronously before asynchronous consumption or publication can lag.
final class OpenCodeProbeCompletion: Sendable {
    enum Outcome: Sendable {
        case exited(ContinuousClock.Instant)
        case deadline
    }

    // One-shot native callback/deadline claim; an actor hop would reorder arrival.
    private let claimed = OSAllocatedUnfairLock(initialState: false)
    let results: AsyncStream<Outcome>
    private let signal: AsyncStream<Outcome>.Continuation

    init() {
        (results, signal) = AsyncStream.makeStream(bufferingPolicy: .bufferingOldest(1))
    }

    func recordExit() {
        let outcome: Outcome? = claimed.withLock { claimed in
            guard !claimed else { return nil }
            claimed = true
            return .exited(.now)
        }
        publish(outcome)
    }

    func recordDeadline() {
        let outcome: Outcome? = claimed.withLock { claimed in
            guard !claimed else { return nil }
            claimed = true
            return .deadline
        }
        publish(outcome)
    }

    private func publish(_ outcome: Outcome?) {
        guard let outcome else { return }
        signal.yield(outcome)
        signal.finish()
    }
}
