import Foundation
import ProvenanceEngineContracts

/// One logical workspace, even when a retained archive also exists for a live tab.
struct WorkspaceExplorerHistoryItem: Identifiable {
    let id: String
    let title: String
    let createdAt: Date?
    let closedAt: Date?
    let lastActivityAt: Date?
    let colorHex: String?
    let display: ProvenanceWorkspaceDisplayRecord?
    let liveWorkspaceID: UUID?
    let liveStatus: WorkspaceExplorerStatus
    let archive: ProvenanceArchivedWorkspaceRecord?
    let reopenEligibility: WorkspaceExplorerReopenEligibility

    var isOpen: Bool { liveWorkspaceID != nil }

    func withLiveStatus(_ status: WorkspaceExplorerStatus) -> Self {
        Self(id: id, title: title, createdAt: createdAt, closedAt: closedAt,
            lastActivityAt: lastActivityAt, colorHex: colorHex, display: display,
            liveWorkspaceID: liveWorkspaceID, liveStatus: status,
            archive: archive, reopenEligibility: reopenEligibility)
    }
}
