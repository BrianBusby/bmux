import SwiftUI

/// Uncounted live cards while Explorer resolves project and activity metadata.
struct WorkspaceExplorerPendingWorkspaceSection: View {
    let items: [WorkspaceExplorerHistoryItem]
    let activeWorkspaceID: String?
    let onOpen: (WorkspaceExplorerHistoryItem) -> Void

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "explorer.newWorkspacesLoading", defaultValue:
                    "New workspaces — loading details"))
                    .font(.system(size: 13, weight: .semibold))
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 236), spacing: 10)], spacing: 10) {
                    ForEach(items) { item in
                        WorkspaceExplorerWorkspaceCard(item: item,
                            isActive: activeWorkspaceID == item.id, isReopened: false,
                            metadataPending: true, arrangedStatus: item.liveStatus,
                            hiddenDimensions: [], onOpen: { onOpen(item) },
                            onHistory: {}, onReopen: {}, onFilter: { _, _ in },
                            onInteractionChanged: { _ in })
                    }
                }
            }
        }
    }
}
