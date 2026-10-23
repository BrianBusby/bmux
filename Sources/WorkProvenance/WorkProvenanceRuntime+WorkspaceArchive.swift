import Foundation
import BmuxWorkspaces

extension WorkProvenanceRuntime {
    func trackArchiveTask(_ task: Task<Void, Never>) {
        let id = UUID()
        archiveTasksByID[id] = task
        trackBackgroundTask(task)
        Task { @MainActor [weak self] in
            await task.value
            self?.archiveTasksByID[id] = nil
        }
    }

    func waitForArchiveTasks() async {
        let tasks = Array(archiveTasksByID.values)
        for task in tasks {
            await task.value
        }
    }

    /// Captures remaining workspaces after a user-initiated window close commits.
    func recordWindowClosure(_ workspaces: [Workspace], at closedAt: Date = Date()) {
        for workspace in workspaces {
            recordWorkspaceClosure(workspace, at: closedAt)
        }
    }

    /// Captures a user-closed workspace through PE's public archive contract.
    func recordWorkspaceClosure(_ workspace: Workspace, at closedAt: Date = Date()) {
        guard acceptsLifecycleProducerWork else { return }
        let stableID = workspace.stableId
        let title = workspace.bmuxEventWorkspaceTitle
        let createdAt = workspace.createdAt
        let colorHex = workspace.customColor
        let statusCode = WorkspaceExplorerStatus.verified(of: workspace).archiveCode
        do {
            try workspaceCloseJournal?.record(WorkspaceExplorerCloseRecord(
                stableID: stableID, title: title, closedAt: closedAt, colorHex: colorHex
            ))
        } catch {
            sentryCaptureError(
                "Workspace close recovery write failed",
                category: "provenance",
                data: ["workspace_id": stableID.uuidString,
                       "error_type": String(reflecting: type(of: error))]
            )
        }
        guard let workspaceArchiveService else { return }
        trackArchiveTask(Task {
            do {
                try await workspaceArchiveService.recordClosure(
                    stableWorkspaceID: stableID,
                    title: title,
                    createdAt: createdAt,
                    closedAt: closedAt,
                    colorHex: colorHex,
                    lastRecordedStatusCode: statusCode
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
