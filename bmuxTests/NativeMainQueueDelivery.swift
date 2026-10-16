import Foundation

/// Observes one native main-queue FIFO delivery, preserving its arrival across delayed async consumption.
/// This does not wait for work that the native mutation schedules later.
@MainActor
struct NativeMainQueueDelivery {
    private let duration: Duration

    init(duration: Duration) {
        self.duration = duration
    }

    func deliver(
        phase: String = #function,
        line: UInt = #line,
        action: @MainActor () -> Void = {}
    ) async throws {
        let start = ContinuousClock.now
        let deadline = start.advanced(by: duration)
        let (events, signal) = AsyncStream<Delivery>.makeStream(bufferingPolicy: .bufferingOldest(1))
        defer { signal.finish() }
        action()
        // The action must synchronously enqueue its native mutation before this FIFO marker.
        // Preserve producer arrival even if the async consumer resumes after the deadline.
        DispatchQueue.main.async { signal.yield(.producer(.now)); signal.finish() }
        let delivery = await withTaskGroup(of: Void.self) { group in
            defer { group.cancelAll() }
            group.addTask { await expireDelivery(at: deadline, signal: signal) }
            var iterator = events.makeAsyncIterator()
            return await iterator.next()
        }
        try Task.checkCancellation()
        guard let delivery else { throw CancellationError() }
        let arrival: ContinuousClock.Instant
        let source: String
        switch delivery {
        case .producer(let timestamp):
            if timestamp < deadline { return }
            arrival = timestamp
            source = "producer"
        case .deadline(let timestamp):
            arrival = timestamp
            source = "deadline"
        case .failed(let error):
            throw error
        }
        throw Failure.deliveryTimedOut(
            phase: phase, line: line, source: source,
            arrivalMilliseconds: milliseconds(start.duration(to: arrival)),
            observedMilliseconds: milliseconds(start.duration(to: .now)),
            deadlineMilliseconds: milliseconds(duration)
        )
    }

    private func expireDelivery(
        at deadline: ContinuousClock.Instant,
        signal: AsyncStream<Delivery>.Continuation
    ) async {
        // The caller owns the failure bound; this group cancels and joins its timer.
        do { try await ContinuousClock().sleep(until: deadline) }
        catch is CancellationError { return }
        catch {
            signal.yield(.failed(error))
            signal.finish()
            return
        }
        // Serialize deadline publication with the native MainActor producer, not its consumer.
        signal.yield(.deadline(.now))
        signal.finish()
    }

    private func milliseconds(_ duration: Duration) -> Double {
        Double(duration.components.seconds) * 1000 + Double(duration.components.attoseconds) / 1e15
    }

    private enum Delivery: Sendable {
        case producer(ContinuousClock.Instant)
        case deadline(ContinuousClock.Instant)
        case failed(any Error)
    }

    private enum Failure: Error, CustomStringConvertible {
        case deliveryTimedOut(
            phase: String, line: UInt, source: String,
            arrivalMilliseconds: Double, observedMilliseconds: Double, deadlineMilliseconds: Double
        )

        var description: String {
            switch self {
            case let .deliveryTimedOut(phase, line, source, arrival, observed, deadline):
                return "event=native_main_queue_delivery_timeout phase=\(phase) line=\(line) source=\(source) "
                    + "arrival_ms=\(arrival) observed_ms=\(observed) deadline_ms=\(deadline)"
            }
        }
    }
}
