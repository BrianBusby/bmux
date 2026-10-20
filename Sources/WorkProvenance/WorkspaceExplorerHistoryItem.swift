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
    let archive: ProvenanceArchivedWorkspaceRecord?
    let reopenEligibility: WorkspaceExplorerReopenEligibility

    var isOpen: Bool { liveWorkspaceID != nil }
}
