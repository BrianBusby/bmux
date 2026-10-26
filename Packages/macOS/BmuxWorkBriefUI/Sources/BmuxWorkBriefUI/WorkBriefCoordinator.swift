import BmuxWorkBrief
import Foundation
import Observation

/// Owns refresh state for the built-in Work Brief without navigating during refresh.
@MainActor @Observable
public final class WorkBriefCoordinator {
    /// Produces a bounded snapshot from current sources.
    public typealias Loader = @MainActor () async -> WorkBriefSnapshot

    /// Latest source facts.
    public private(set) var snapshot: WorkBriefSnapshot?
    /// Whether a refresh is in progress.
    public private(set) var isLoading = false
    private let load: Loader
    private var refreshAgain = false

    /// Creates the coordinator with an injected source loader.
    public init(initialSnapshot: WorkBriefSnapshot? = nil, load: @escaping Loader) {
        snapshot = initialSnapshot
        self.load = load
    }

    /// Coalesces source notifications while one refresh is in progress.
    public func refresh() async {
        if isLoading {
            refreshAgain = true
            return
        }
        isLoading = true
        repeat {
            refreshAgain = false
            snapshot = await load()
        } while refreshAgain
        isLoading = false
    }
}
