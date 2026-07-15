import Foundation

/// Sendable workspace state needed by work provenance observation.
struct WorkProvenanceWorkspaceSnapshot: Equatable, Sendable {
    /// Runtime workspace identifier.
    let workspaceID: UUID

    /// Restart-stable workspace identifier.
    let stableWorkspaceID: UUID

    /// Workspace title at observation time.
    let title: String

    /// Workspace current directory at observation time.
    let currentDirectory: String

    /// Creates a workspace snapshot.
    init(
        workspaceID: UUID,
        stableWorkspaceID: UUID,
        title: String,
        currentDirectory: String
    ) {
        self.workspaceID = workspaceID
        self.stableWorkspaceID = stableWorkspaceID
        self.title = title
        self.currentDirectory = currentDirectory
    }

    /// Creates a workspace snapshot from the live workspace model.
    @MainActor
    init(workspace: Workspace) {
        self.init(
            workspaceID: workspace.id,
            stableWorkspaceID: workspace.stableId,
            title: workspace.customTitle ?? workspace.title,
            currentDirectory: workspace.currentDirectory
        )
    }
}
