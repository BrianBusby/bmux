import Foundation

enum WorkspaceExplorerReopenEligibility: Equatable {
    case eligible(recordID: UUID)
    case unavailable(WorkspaceExplorerReopenReason)
}
