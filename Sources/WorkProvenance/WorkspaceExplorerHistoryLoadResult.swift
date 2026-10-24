import Foundation

struct WorkspaceExplorerHistoryLoadResult {
    let items: [WorkspaceExplorerHistoryItem]
    let archiveAvailability: WorkspaceExplorerArchiveAvailability
    let partialLiveActivity: Bool
    let liveMetadataPending: Bool
    let activeWorkspaceID: String?
    let repositoryNamesByID: [String: String]

    init(items: [WorkspaceExplorerHistoryItem],
         archiveAvailability: WorkspaceExplorerArchiveAvailability,
         partialLiveActivity: Bool,
         liveMetadataPending: Bool = false,
         activeWorkspaceID: String? = nil,
         repositoryNamesByID: [String: String] = [:]) {
        self.items = items
        self.archiveAvailability = archiveAvailability
        self.partialLiveActivity = partialLiveActivity
        self.liveMetadataPending = liveMetadataPending
        self.activeWorkspaceID = activeWorkspaceID
        self.repositoryNamesByID = repositoryNamesByID
    }
}
