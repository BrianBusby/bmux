import Foundation
import ProvenanceEngineContracts

/// Main-actor cache of PE workspace display Current State for tab rendering.
@MainActor
final class WorkspaceDisplayCurrentStateStore {
    private let client: any ProvenanceEngineClient
    private var snapshotsByStableWorkspaceID: [UUID: WorkspaceDisplayCurrentStateSnapshot] = [:]
    private var refreshTasksByStableWorkspaceID: [UUID: Task<Void, Never>] = [:]

    init(client: any ProvenanceEngineClient) {
        self.client = client
    }

    func snapshot(for workspace: Workspace) -> WorkspaceDisplayCurrentStateSnapshot? {
        snapshotsByStableWorkspaceID[workspace.stableId]
    }

    func refresh(
        stableWorkspaceIDs: [UUID],
        notify: @escaping @MainActor (UUID) -> Void
    ) {
        for stableWorkspaceID in stableWorkspaceIDs {
            refresh(stableWorkspaceID: stableWorkspaceID, notify: notify)
        }
    }

    func refresh(
        stableWorkspaceID: UUID,
        notify: @escaping @MainActor (UUID) -> Void
    ) {
        refreshTasksByStableWorkspaceID[stableWorkspaceID]?.cancel()
        refreshTasksByStableWorkspaceID[stableWorkspaceID] = Task { [weak self] in
            guard let self else { return }
            let response: ProvenanceWorkspaceDisplayResponse
            do {
                response = try await client.workspaceDisplay(ProvenanceWorkspaceDisplayRequest(
                    workspaceID: stableWorkspaceID.uuidString
                ))
            } catch {
                StartupBreadcrumbLog.append("workProvenance.displayCurrentState.refreshFailed", fields: [
                    "workspace": stableWorkspaceID.uuidString,
                    "error": String(describing: error)
                ])
                return
            }
            guard !Task.isCancelled,
                  let display = response.display,
                  let snapshot = WorkspaceDisplayCurrentStateSnapshot(display) else {
                return
            }
            await MainActor.run {
                guard snapshot.isNewerThan(snapshotsByStableWorkspaceID[stableWorkspaceID]) else {
                    return
                }
                snapshotsByStableWorkspaceID[stableWorkspaceID] = snapshot
                notify(stableWorkspaceID)
            }
        }
    }
}
