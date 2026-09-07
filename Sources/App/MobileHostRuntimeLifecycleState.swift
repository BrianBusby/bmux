import Foundation

enum MobileHostRuntimeLifecycleState: Equatable {
    case disabled(reason: String)
    case notStarted
    case starting
    case ready
    case degraded(reason: String)
    case failed(reason: String)
    case stopping
    case stopped

    var isListenerReady: Bool {
        switch self {
        case .ready, .degraded:
            return true
        case .disabled, .notStarted, .starting, .failed, .stopping, .stopped:
            return false
        }
    }
}
