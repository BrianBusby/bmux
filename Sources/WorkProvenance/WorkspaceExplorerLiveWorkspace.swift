import Foundation
import ProvenanceEngineContracts

/// Immutable input captured from bmux's live workspace owner on the main actor.
struct WorkspaceExplorerLiveWorkspace {
    let stableID: UUID
    let runtimeID: UUID
    let title: String
    let createdAt: Date
    let colorHex: String?
    let display: ProvenanceWorkspaceDisplayRecord?
    let lastActivityAt: Date?
    let liveStatus: WorkspaceExplorerStatus

    init(stableID: UUID, runtimeID: UUID, title: String, createdAt: Date,
         colorHex: String?, display: ProvenanceWorkspaceDisplayRecord?, lastActivityAt: Date?,
         liveStatus: WorkspaceExplorerStatus = .disconnected) {
        self.stableID = stableID
        self.runtimeID = runtimeID
        self.title = title
        self.createdAt = createdAt
        self.colorHex = colorHex
        self.display = display
        self.lastActivityAt = lastActivityAt
        self.liveStatus = liveStatus
    }
}
