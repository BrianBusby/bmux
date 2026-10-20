import Foundation

extension WorkProvenanceRuntime {
    /// Captures remaining workspaces after a user-initiated window close commits.
    func recordWindowClosure(_ workspaces: [Workspace], at closedAt: Date = Date()) {
        for workspace in workspaces {
            recordWorkspaceClosure(workspace, at: closedAt)
        }
    }

    /// Captures a user-closed workspace through PE's public archive contract.
    func recordWorkspaceClosure(_ workspace: Workspace, at closedAt: Date = Date()) {
        guard acceptsLifecycleProducerWork, let workspaceArchiveService else { return }
        let stableID = workspace.stableId
        let title = workspace.bmuxEventWorkspaceTitle
        let createdAt = workspace.createdAt
        let colorHex = workspace.customColor
        trackBackgroundTask(Task {
            do {
                try await workspaceArchiveService.recordClosure(
                    stableWorkspaceID: stableID,
                    title: title,
                    createdAt: createdAt,
                    closedAt: closedAt,
                    colorHex: colorHex
                )
            } catch {
                sentryCaptureError(
                    "Workspace archive write failed",
                    category: "provenance",
                    data: [
                        "workspace_id": stableID.uuidString,
                        "error_type": String(reflecting: type(of: error)),
                    ]
                )
            }
        })
    }
}
