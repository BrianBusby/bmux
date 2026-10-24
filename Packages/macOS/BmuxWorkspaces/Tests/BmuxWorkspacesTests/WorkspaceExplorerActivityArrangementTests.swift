import Foundation
import Testing
@testable import BmuxWorkspaces

@Suite @MainActor
struct WorkspaceExplorerActivityArrangementTests {
    @Test
    func deadlineHoldsHoveredCardUntilExplicitUpdate() {
        let initial = Date(timeIntervalSince1970: 1_000_000)
        var current = initial
        let clock = WorkspaceExplorerActivityClock(currentDate: { current }, sleep: { _ in
            throw CancellationError()
        })
        let arrangement = WorkspaceExplorerActivityArrangement(clock: clock)
        clock.configure(period: .today, activityDates: [])
        arrangement.cardInteractionChanged(id: "workspace:a", active: true)
        current.addTimeInterval(1)
        clock.configure(period: .today, activityDates: [])
        #expect(!arrangement.hasPendingUpdate)
        current.addTimeInterval(60)
        clock.resampleForAutomaticChange()
        #expect(arrangement.now == initial)
        #expect(arrangement.hasPendingUpdate)

        arrangement.cardInteractionChanged(id: "workspace:a", active: false)
        #expect(arrangement.now == initial)
        arrangement.applyPending()
        #expect(arrangement.now == current)
        #expect(!arrangement.hasPendingUpdate)
    }

    @Test
    func unrelatedCardLeavingDoesNotReleaseTheHold() {
        let initial = Date(timeIntervalSince1970: 1_000_000)
        var current = initial
        let clock = WorkspaceExplorerActivityClock(currentDate: { current }, sleep: { _ in
            throw CancellationError()
        })
        let arrangement = WorkspaceExplorerActivityArrangement(clock: clock)
        clock.configure(period: .today, activityDates: [])
        arrangement.cardInteractionChanged(id: "project:a", active: true)
        arrangement.cardInteractionChanged(id: "workspace:b", active: true)
        arrangement.cardInteractionChanged(id: "project:a", active: false)
        current.addTimeInterval(60)
        clock.resampleForAutomaticChange()
        #expect(arrangement.now == initial)
        arrangement.scopeChanged()
        #expect(arrangement.now == current)
        arrangement.stop()
        #expect(!arrangement.hasPendingUpdate)
    }

    @Test
    func timeZoneChangeHoldsTheCalendarUntilUpdate() {
        let instant = Date(timeIntervalSince1970: 1_000_000)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let clock = WorkspaceExplorerActivityClock(currentDate: { instant }, sleep: { _ in
            throw CancellationError()
        }, calendarProvider: { calendar })
        clock.configure(period: .today, activityDates: [])
        let arrangement = WorkspaceExplorerActivityArrangement(clock: clock)
        arrangement.cardInteractionChanged(id: "project:a", active: true)
        calendar.timeZone = TimeZone(secondsFromGMT: 3600)!
        clock.resampleForAutomaticChange()
        #expect(arrangement.calendar.timeZone.secondsFromGMT() == 0)
        #expect(arrangement.hasPendingUpdate)
        arrangement.applyPending()
        #expect(arrangement.calendar.timeZone.secondsFromGMT() == 3600)
    }
}
