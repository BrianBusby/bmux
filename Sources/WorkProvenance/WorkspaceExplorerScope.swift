import Foundation

/// Explorer-wide presence and meaningful-activity eligibility.
struct WorkspaceExplorerScope: Equatable {
    enum State: Equatable {
        case open, all, closed
    }

    enum Period: Equatable {
        case anyTime, last24Hours, today, last7Days
    }

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
}
