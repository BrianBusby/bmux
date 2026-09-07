import Foundation

enum BrowserDevToolsRuntimeOperationResult: Equatable {
    case ready
    case disabled(reason: String)
    case degraded(reason: String)
    case failed(reason: String)
}
