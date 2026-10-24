import BmuxWorkspaces
import Observation

/// Keeps the visible catalog fixed while a card is hovered or keyboard-focused.
@MainActor @Observable
final class WorkspaceExplorerActivityPresentation {
    let arrangement: WorkspaceExplorerActivityArrangement
    private var heldCatalog: WorkspaceExplorerCatalog?

    init(clock: WorkspaceExplorerActivityClock) {
        arrangement = WorkspaceExplorerActivityArrangement(clock: clock)
    }

    var isHolding: Bool { heldCatalog != nil }

    func catalog(current: WorkspaceExplorerCatalog?) -> WorkspaceExplorerCatalog? {
        guard let heldCatalog else { return current }
        return heldCatalog.withCurrentLiveStatuses(from: current)
    }

    func cardInteractionChanged(id: String, active: Bool, current: WorkspaceExplorerCatalog?) {
        if active && !arrangement.hasInteractingCards && heldCatalog == nil {
            heldCatalog = current
        }
        arrangement.cardInteractionChanged(id: id, active: active)
        if !arrangement.hasInteractingCards && !arrangement.hasPendingUpdate {
            heldCatalog = nil
        }
    }

    func captureInteractionIfNeeded(current: WorkspaceExplorerCatalog?) {
        if arrangement.hasInteractingCards && heldCatalog == nil { heldCatalog = current }
    }

    func markDataChangePending() { arrangement.markDataChangePending() }

    func applyPending(current: WorkspaceExplorerCatalog?) {
        arrangement.applyPending()
        heldCatalog = arrangement.hasInteractingCards ? current : nil
    }

    func resetForExplicitChange() {
        arrangement.stop()
        heldCatalog = nil
    }

    func stop() { resetForExplicitChange() }
}
