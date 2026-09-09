import Foundation

enum NotificationPushRuntimeOperationResult: Equatable {
    case ready
    case disabled(reason: String)
    case degraded(reason: String)
    case failed(reason: String)
}
