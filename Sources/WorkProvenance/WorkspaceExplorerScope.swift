import BmuxWorkspaces
import Foundation

/// Explorer-wide presence and meaningful-activity eligibility.
struct WorkspaceExplorerScope: Equatable {
    enum State: Equatable {
        case open, all, closed
    }

    typealias Period = WorkspaceExplorerActivityClock.Period

    var state: State = .open
    var period: Period = .anyTime

    func includes(_ workspace: WorkspaceExplorerWorkspace, now: Date, calendar: Calendar) -> Bool {
        switch state {
        case .open where workspace.isClosed, .closed where !workspace.isClosed:
            return false
        default:
            break
        }
        guard period != .anyTime else { return true }
        guard let activity = workspace.lastActivityAt else { return false }
        let start: Date
        switch period {
        case .anyTime: return true
        case .last24Hours: start = now.addingTimeInterval(-24 * 60 * 60)
        case .today: start = calendar.startOfDay(for: now)
        case .last7Days: start = now.addingTimeInterval(-7 * 24 * 60 * 60)
        }
        return activity >= start && activity <= now
    }

    var stateLabel: String {
        switch state {
        case .open: String(localized: "explorer.open", defaultValue: "Open")
        case .all: String(localized: "explorer.all", defaultValue: "All")
        case .closed: String(localized: "explorer.closed", defaultValue: "Closed")
        }
    }

    var periodLabel: String {
        switch period {
        case .anyTime: String(localized: "explorer.anyTime", defaultValue: "Any time")
        case .last24Hours: String(localized: "explorer.activeLast24Hours", defaultValue: "Active in last 24 hours")
        case .today: String(localized: "explorer.activeToday", defaultValue: "Active today")
        case .last7Days: String(localized: "explorer.activeLast7Days", defaultValue: "Active in last 7 days")
        }
    }

    var summary: String { stateLabel + " · " + periodLabel }
}
