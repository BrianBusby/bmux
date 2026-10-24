import Foundation
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@MainActor
struct NotificationBurstCoalescerTests {
    @Test func signalsInSameBurstFlushOnce() {
        var scheduledFlush: (@MainActor () -> Void)?
        var scheduleCount = 0
        // Native timer delivery is covered separately; this test controls the scheduling boundary.
        let coalescer = NotificationBurstCoalescer(delay: 0.01) { _, action in
            scheduleCount += 1
            scheduledFlush = action
            return {}
        }
        var flushCount = 0

        for _ in 0..<8 {
            coalescer.signal { flushCount += 1 }
        }

        #expect(scheduleCount == 1)
        #expect(flushCount == 0)
        #expect(scheduledFlush != nil)
        scheduledFlush?()
        #expect(flushCount == 1)
    }
}
