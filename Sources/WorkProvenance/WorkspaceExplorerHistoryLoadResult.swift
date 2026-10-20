import Foundation

struct WorkspaceExplorerHistoryLoadResult {
    let items: [WorkspaceExplorerHistoryItem]
    let archiveAvailability: WorkspaceExplorerArchiveAvailability
    let partialLiveActivity: Bool
    let activeWorkspaceID: String?

    init(items: [WorkspaceExplorerHistoryItem],
         archiveAvailability: WorkspaceExplorerArchiveAvailability,
         partialLiveActivity: Bool,
         activeWorkspaceID: String? = nil) {
        self.items = items
        self.archiveAvailability = archiveAvailability
        self.partialLiveActivity = partialLiveActivity
        self.activeWorkspaceID = activeWorkspaceID
    }
}
