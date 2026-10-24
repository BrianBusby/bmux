import BmuxWorkspaces
import Foundation
import Testing

@Suite @MainActor
struct WorkspaceExplorerActivityClockTests {
    @Test
    func rollingDeadlineUsesMeaningfulActivityAndSkipsExpiredItems() throws {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let expiring = now.addingTimeInterval(-24 * 60 * 60 + 60)
        let expired = now.addingTimeInterval(-24 * 60 * 60 - 10)
        let deadline = try #require(WorkspaceExplorerActivityClock.nextDeadline(
            after: now, period: .last24Hours, activityDates: [expired, expiring]))
        #expect(abs(deadline.timeIntervalSince(now) - 60.001) < 0.001)
        #expect(WorkspaceExplorerActivityClock.nextDeadline(
            after: now, period: .anyTime, activityDates: [expiring]) == nil)
    }

    @Test
    func todayRefreshesAtLocalMidnightAcrossDaylightSavingChange() throws {
        let formatter = ISO8601DateFormatter()
        let now = try #require(formatter.date(from: "2026-03-08T00:30:00-05:00"))
        let nextMidnight = try #require(formatter.date(from: "2026-03-09T00:00:00-04:00"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/New_York"))
        #expect(WorkspaceExplorerActivityClock.nextDeadline(
            after: now, period: .today, activityDates: [], calendar: calendar) == nextMidnight)
    }

    @Test
    func todayReschedulesWhenSystemTimeZoneChanges() async throws {
        let now = Date(timeIntervalSince1970: 1_767_268_800) // 2026-01-01 12:00 UTC
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let notifications = NotificationCenter()
        let scheduled = AsyncStream<Duration>.makeStream()
        let release = AsyncStream<Void>.makeStream()
        let clock = WorkspaceExplorerActivityClock(currentDate: { now }, sleep: { duration in
            scheduled.continuation.yield(duration)
            var iterator = release.stream.makeAsyncIterator()
            guard await iterator.next() != nil else { throw CancellationError() }
        }, calendarProvider: { calendar }, notificationCenter: notifications)
        clock.configure(period: .today, activityDates: [])
        let first = try #require(await nextDuration(scheduled.stream))
        #expect(first == .seconds(12 * 60 * 60))

        calendar.timeZone = try #require(TimeZone(identifier: "America/Los_Angeles"))
        notifications.post(name: .NSSystemTimeZoneDidChange, object: nil)
        let updated = try #require(await nextDuration(scheduled.stream))
        #expect(updated == .seconds(20 * 60 * 60))
        clock.stop()
        release.continuation.finish()
    }

    private func nextDuration(_ stream: AsyncStream<Duration>) async -> Duration? {
        await withTaskGroup(of: Duration?.self) { group in
            group.addTask {
                var iterator = stream.makeAsyncIterator()
                return await iterator.next()
            }
            group.addTask {
                // A bounded test failure deadline; correctness waits on the scheduling signal.
                try? await ContinuousClock().sleep(for: .seconds(5))
                return nil
            }
            let value = await group.next() ?? nil
            group.cancelAll()
            return value
        }
    }
}
