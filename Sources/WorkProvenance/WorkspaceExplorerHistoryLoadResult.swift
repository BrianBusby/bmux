import Foundation
import ProvenanceEngineContracts

struct WorkspaceExplorerHistoryLoadResult {
    let items: [WorkspaceExplorerHistoryItem]
    let archiveAvailability: WorkspaceExplorerArchiveAvailability
    let partialLiveActivity: Bool
    let liveMetadataPending: Bool
    let activeWorkspaceID: String?
    let repositoryNamesByID: [String: String]
    let nextHistoryCursor: String?
    let filterFacets: [ProvenanceWorkspaceHistoryFacet]

    init(items: [WorkspaceExplorerHistoryItem],
         archiveAvailability: WorkspaceExplorerArchiveAvailability,
         partialLiveActivity: Bool,
         liveMetadataPending: Bool = false,
         activeWorkspaceID: String? = nil,
         repositoryNamesByID: [String: String] = [:],
         nextHistoryCursor: String? = nil,
         filterFacets: [ProvenanceWorkspaceHistoryFacet] = []) {
        self.items = items
        self.archiveAvailability = archiveAvailability
        self.partialLiveActivity = partialLiveActivity
        self.liveMetadataPending = liveMetadataPending
        self.activeWorkspaceID = activeWorkspaceID
        self.repositoryNamesByID = repositoryNamesByID
        self.nextHistoryCursor = nextHistoryCursor
        self.filterFacets = filterFacets
    }

    func withArchiveAvailability(_ availability: WorkspaceExplorerArchiveAvailability) -> Self {
        Self(items: items, archiveAvailability: availability,
            partialLiveActivity: partialLiveActivity, liveMetadataPending: liveMetadataPending,
            activeWorkspaceID: activeWorkspaceID, repositoryNamesByID: repositoryNamesByID,
            nextHistoryCursor: nextHistoryCursor, filterFacets: filterFacets)
    }

    func appendingHistoryPage(_ page: Self) -> Self {
        let incomingByID = Dictionary(page.items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let knownIDs = Set(items.map(\.id))
        let appended = items.map { item in
            item.withSessionHistory(incomingByID[item.id])
        } + page.items.filter { !knownIDs.contains($0.id) }
        let open = appended.filter(\.isOpen)
        let past = appended.filter { !$0.isOpen }.sorted { left, right in
            let leftDate = left.lastActivityAt ?? left.closedAt ?? left.createdAt ?? .distantPast
            let rightDate = right.lastActivityAt ?? right.closedAt ?? right.createdAt ?? .distantPast
            return leftDate == rightDate ? left.id > right.id : leftDate > rightDate
        }
        return Self(items: open + past, archiveAvailability: archiveAvailability,
            partialLiveActivity: partialLiveActivity, liveMetadataPending: liveMetadataPending,
            activeWorkspaceID: activeWorkspaceID,
            repositoryNamesByID: repositoryNamesByID.merging(page.repositoryNamesByID) { current, _ in current },
            nextHistoryCursor: page.nextHistoryCursor, filterFacets: filterFacets)
    }
}
