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
}
