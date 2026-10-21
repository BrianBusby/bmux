public import Foundation
public import Observation

/// Supplies a sampled instant for Explorer activity projections.
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

    /// Creates a clock. Inject time and the deadline sleeper for deterministic tests.
    /// - Parameters:
    ///   - currentDate: Supplies the current instant when scheduling and publishing.
    ///   - sleep: Waits for a deadline when scheduling is enabled.
    public init(currentDate: @escaping @MainActor () -> Date = { .now },
                sleep: @escaping @MainActor (Duration) async throws -> Void = {
                    // A bounded, cancellable sleep will fire at the next membership deadline.
                    try await Task.sleep(for: $0)
                }) {
        self.currentDate = currentDate
        self.sleep = sleep
        self.now = currentDate()
    }

    /// Resamples time when activity dates or the selected period change.
    /// - Parameters:
    ///   - period: The activity window to track.
    ///   - activityDates: Meaningful work events that may cross the window boundary.
    ///   - calendar: Calendar used to find local midnight for Today.
    public func configure(period: Period, activityDates: [Date], calendar: Calendar = .current) {
        now = currentDate()
    }

    /// Stops deadline work when Explorer closes.
    public func stop() {}
}
