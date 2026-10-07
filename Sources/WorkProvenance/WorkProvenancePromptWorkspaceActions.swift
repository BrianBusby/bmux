import Foundation

/// Exact live workspace/panel actions for a persisted prompt, resolved outside rendering.
@MainActor
struct WorkProvenancePromptWorkspaceActions {
    let stableWorkspaceID: UUID
    let surfaceID: UUID
    let isCurrent: () -> Bool
    let applyResources: (String) -> Bool
}
