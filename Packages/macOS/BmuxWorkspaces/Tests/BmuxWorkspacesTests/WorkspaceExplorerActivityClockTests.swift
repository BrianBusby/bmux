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
}
