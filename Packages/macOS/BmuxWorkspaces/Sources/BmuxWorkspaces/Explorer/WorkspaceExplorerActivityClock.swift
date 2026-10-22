public import Foundation
public import Observation

/// Publishes time only when an Explorer activity window can change membership.
@MainActor @Observable
public final class WorkspaceExplorerActivityClock {
    /// An Explorer activity period, independent of workspace open or closed state.
    public enum Period: Equatable, Sendable {
        /// Include all retained activity dates.
        case anyTime
        /// Include activity within the rolling previous 24 hours.
        case last24Hours
        /// Include activity since local midnight.
        case today
        /// Include activity within the rolling previous seven days.
        case last7Days
    }

    /// The time used by the current Explorer projection.
    public private(set) var now: Date
    private let currentDate: @MainActor () -> Date
    private let sleep: @MainActor (Duration) async throws -> Void
    private let calendarProvider: @MainActor () -> Calendar
    private let notificationCenter: NotificationCenter
    private var deadlineTask: Task<Void, Never>?

    /// Creates a clock. Inject time and the deadline sleeper for deterministic tests.
    /// - Parameters:
    ///   - currentDate: Supplies the current instant when scheduling and publishing.
    ///   - sleep: Waits until a membership deadline; defaults to a cancellable task sleep.
    ///   - calendarProvider: Supplies the current local calendar when scheduling.
    ///   - notificationCenter: Delivers system calendar change notifications.
    public init(currentDate: @escaping @MainActor () -> Date = { .now },
                sleep: @escaping @MainActor (Duration) async throws -> Void = {
                    // A bounded, cancellable sleep fires at the next membership deadline.
                    try await Task.sleep(for: $0)
                },
                calendarProvider: @escaping @MainActor () -> Calendar = { .current },
                notificationCenter: NotificationCenter = .default) {
        self.currentDate = currentDate
        self.sleep = sleep
        self.calendarProvider = calendarProvider
        self.notificationCenter = notificationCenter
        self.now = currentDate()
    }

    /// Reschedules for the selected period and known meaningful activity dates.
    /// - Parameters:
    ///   - period: The activity window to track.
    ///   - activityDates: Meaningful work events that may cross the window boundary.
    ///   - calendar: Calendar used to find local midnight for Today.
    public func configure(period: Period, activityDates: [Date], calendar: Calendar? = nil) {
        deadlineTask?.cancel()
        now = currentDate()
        let calendar = calendar ?? calendarProvider()
        guard let deadline = Self.nextDeadline(after: now, period: period,
                                               activityDates: activityDates, calendar: calendar) else {
            deadlineTask = nil
            return
        }
        deadlineTask = Task { [weak self, sleep, currentDate] in
            do { try await sleep(.seconds(max(0, deadline.timeIntervalSince(currentDate())))) }
            catch { return }
            guard !Task.isCancelled, let self else { return }
            self.configure(period: period, activityDates: activityDates)
        }
    }

    /// Cancels the current deadline when Explorer closes.
    public func stop() {
        deadlineTask?.cancel()
        deadlineTask = nil
    }

    /// Returns the earliest instant when period membership may change.
    /// - Parameters:
    ///   - now: The currently published instant.
    ///   - period: The activity window to track.
    ///   - activityDates: Meaningful work events that may enter or leave the window.
    ///   - calendar: Calendar used to find local midnight for Today.
    /// - Returns: The next membership deadline, or `nil` when no deadline is needed.
    public static func nextDeadline(after now: Date, period: Period,
                                    activityDates: [Date], calendar: Calendar = .current) -> Date? {
        switch period {
        case .anyTime:
            return nil
        case .today:
            return calendar.dateInterval(of: .day, for: now)?.end
        case .last24Hours, .last7Days:
            let window: TimeInterval = period == .last24Hours ? 24 * 60 * 60 : 7 * 24 * 60 * 60
            return activityDates.compactMap { date in
                let arrival = date > now ? date : nil
                let expiry = date.addingTimeInterval(window + 0.001)
                return [arrival, expiry].compactMap { $0 }.filter { $0 > now }.min()
            }.min()
        }
    }
}
