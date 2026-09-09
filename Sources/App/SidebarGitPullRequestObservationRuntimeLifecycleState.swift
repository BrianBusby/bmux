import Foundation

enum SidebarGitPullRequestObservationRuntimeLifecycleState: Equatable {
    case disabled(reason: String)
    case notStarted
    case starting
    case ready
    case degraded(reason: String)
    case failed(reason: String)
    case stopping
    case stopped

    /// Observation is usable once the runtime owner is installed and can accept
    /// workspace events. Individual repositories may still be loading or stale.
    var canAcceptWorkspaceEvents: Bool {
        switch self {
        case .ready, .degraded:
            return true
        case .disabled, .notStarted, .starting, .failed, .stopping, .stopped:
            return false
        }
    }
}
