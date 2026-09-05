import Foundation

enum WorkProvenanceRuntimeLifecycleState: Equatable, Sendable {
    case notStarted
    case starting
    case ready
    case degraded(reason: String)
    case stopping
    case stopped
    case failed(reason: String)
}
