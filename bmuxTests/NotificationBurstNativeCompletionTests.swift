import Foundation
import Testing
#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@MainActor
struct NotificationBurstNativeCompletionTests {
    @Test func latestActionWinsWithinBurst() async throws {
        let coalescer = NotificationBurstCoalescer(delay: 0.01)
        let (events, signal) = AsyncStream<Int>.makeStream()
        // Cancel the owned native timer before finishing its callback stream, even on failure.
        defer { coalescer.flushNow(); signal.finish() }
        let deadline = ContinuousClock.now.advanced(by: .seconds(1))
        coalescer.signal { signal.yield(1) }
        coalescer.signal { signal.yield(2) }
        let values = try await callbacks(events, count: 1, until: deadline)
        #expect(values == [2])
    }

    @Test func signalsAcrossBurstsFlushMultipleTimes() async throws {
        let coalescer = NotificationBurstCoalescer(delay: 0.01)
        let (events, signal) = AsyncStream<Int>.makeStream()
        defer { coalescer.flushNow(); signal.finish() }
        var flushCount = 0
        let deadline = ContinuousClock.now.advanced(by: .seconds(1))
        coalescer.signal { flushCount += 1; signal.yield(flushCount) }
        let values = try await callbacks(events, count: 2, until: deadline) {
            // A completed first native flush establishes a distinct second burst.
            coalescer.signal { flushCount += 1; signal.yield(flushCount) }
        }
        #expect(values == [1, 2])
        #expect(flushCount == 2)
    }

    private func callbacks(
        _ events: AsyncStream<Int>, count: Int, until deadline: ContinuousClock.Instant,
        afterFirst: @escaping @MainActor @Sendable () -> Void = {}
    ) async throws -> [Int] {
        try await withThrowingTaskGroup(of: [Int].self) { group in
            defer { group.cancelAll() }
            group.addTask { try await consume(events, count: count, afterFirst: afterFirst) }
            group.addTask {
                // The original one-second total failure bound contains real native timer delivery.
                try await ContinuousClock().sleep(until: deadline)
                throw Failure.callbackTimedOut
            }
            let result = try await group.next()
            return try #require(result)
        }
    }

    private func consume(
        _ events: AsyncStream<Int>, count: Int, afterFirst: @MainActor @Sendable () -> Void
    ) async throws -> [Int] {
        var values: [Int] = []
        for await value in events {
            values.append(value)
            if values.count == count { return values }
            if values.count == 1 { afterFirst() }
        }
        throw CancellationError()
    }

    private enum Failure: Error { case callbackTimedOut }
}
