#if os(iOS)
import Foundation

public enum MobilePushLifecycleState: Equatable, Sendable {
    case notStarted
    case starting
    case ready
    case stopping
    case stopped
}
#endif
