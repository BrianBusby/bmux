import Foundation

/// Retention settings for high-volume provenance observations.
struct WorkProvenanceRetentionPolicy: Equatable, Sendable {
    /// Standard retention used by the live bmux runtime.
    static let standard = WorkProvenanceRetentionPolicy(
        observedEventMaximumAge: 30 * 24 * 60 * 60,
        minimumObservedEventsPerWorktree: 250,
        pruneAfterAppendedEvents: 25
    )

    /// Maximum age for raw observed worktree snapshot events.
    let observedEventMaximumAge: TimeInterval

    /// Minimum number of recent observed worktree events to keep per worktree.
    let minimumObservedEventsPerWorktree: Int

    /// Number of appended events that should trigger an automatic prune pass.
    let pruneAfterAppendedEvents: Int

    /// Creates a provenance retention policy.
    init(
        observedEventMaximumAge: TimeInterval,
        minimumObservedEventsPerWorktree: Int,
        pruneAfterAppendedEvents: Int
    ) {
        self.observedEventMaximumAge = max(0, observedEventMaximumAge)
        self.minimumObservedEventsPerWorktree = max(1, minimumObservedEventsPerWorktree)
        self.pruneAfterAppendedEvents = max(1, pruneAfterAppendedEvents)
    }
}
