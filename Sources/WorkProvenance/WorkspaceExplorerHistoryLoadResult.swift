import Foundation

struct WorkspaceExplorerHistoryLoadResult {
    let items: [WorkspaceExplorerHistoryItem]
    let archiveAvailability: WorkspaceExplorerArchiveAvailability
    let partialLiveActivity: Bool
}
