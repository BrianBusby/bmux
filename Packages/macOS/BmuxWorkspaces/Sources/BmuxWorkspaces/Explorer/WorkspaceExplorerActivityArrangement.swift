public import Foundation
public import Observation

/// Holds an activity-window projection while a visible card is under pointer or keyboard focus.
@MainActor @Observable
public final class WorkspaceExplorerActivityArrangement {
    private let clock: WorkspaceExplorerActivityClock
    private var interactingCardIDs: Set<String> = []
    private var heldNow: Date?
    private var heldCalendar: Calendar?
    private var heldRevision: Int?

    /// The single time sample used for cards, groups, and counts.
    public var now: Date { heldNow ?? clock.now }
    /// The calendar sampled with the held activity time.
    public var calendar: Calendar { heldCalendar ?? clock.calendar }
    /// Whether a deadline has passed while the visible arrangement was held.
    public var hasPendingUpdate: Bool { heldRevision.map { $0 != clock.automaticRevision } ?? false }

    /// Creates an arrangement around Explorer's existing deadline clock.
    public init(clock: WorkspaceExplorerActivityClock) { self.clock = clock }

    /// Tracks a card's hover or keyboard focus without moving it on an automatic deadline.
    public func cardInteractionChanged(id: String, active: Bool) {
        if active {
            if interactingCardIDs.insert(id).inserted && heldNow == nil { capture() }
        } else {
            interactingCardIDs.remove(id)
            if interactingCardIDs.isEmpty && !hasPendingUpdate { release() }
        }
    }

    /// Applies the latest time only after the user requests the pending arrangement update.
    public func applyPending() {
        if interactingCardIDs.isEmpty { release() } else { capture() }
    }

    /// Explicit scope changes use the current clock even if a card is still hovered.
    public func scopeChanged() { applyPending() }

    /// Clears interaction state when the Explorer window closes.
    public func stop() {
        interactingCardIDs.removeAll()
        release()
    }

    private func capture() {
        heldNow = clock.now
        heldCalendar = clock.calendar
        heldRevision = clock.automaticRevision
    }

    private func release() {
        heldNow = nil
        heldCalendar = nil
        heldRevision = nil
    }
}
