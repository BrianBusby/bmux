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

    func snapshot(stableWorkspaceID: UUID) -> WorkspaceDisplayCurrentStateSnapshot? {
        snapshotsByStableWorkspaceID[stableWorkspaceID]
    }

    func refreshedSnapshot(stableWorkspaceID: UUID) async -> WorkspaceDisplayCurrentStateSnapshot? {
        do {
            return try await freshSnapshot(stableWorkspaceID: stableWorkspaceID)
                ?? snapshotsByStableWorkspaceID[stableWorkspaceID]
        } catch {
            if !Task.isCancelled {
                StartupBreadcrumbLog.append("workProvenance.displayCurrentState.refreshFailed", fields: [
                    "workspace": stableWorkspaceID.uuidString, "error": String(describing: error)
                ])
            }
            return snapshotsByStableWorkspaceID[stableWorkspaceID]
        }
    }

    /// Requires a successful PE read; absence and failure stay distinct for resource authorization.
    func freshSnapshot(stableWorkspaceID: UUID) async throws -> WorkspaceDisplayCurrentStateSnapshot? {
        let response = try await client.workspaceDisplay(ProvenanceWorkspaceDisplayRequest(
            workspaceID: stableWorkspaceID.uuidString
        ))
        guard let display = response.display,
              let snapshot = await displaySnapshot(display, stableWorkspaceID: stableWorkspaceID) else { return nil }
        try Task.checkCancellation()
        guard snapshot.isNewerThan(snapshotsByStableWorkspaceID[stableWorkspaceID]) else {
            return snapshotsByStableWorkspaceID[stableWorkspaceID]
        }
        snapshotsByStableWorkspaceID[stableWorkspaceID] = snapshot
        return snapshot
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
                  let snapshot = await self.displaySnapshot(display, stableWorkspaceID: stableWorkspaceID) else {
                return
            }
            await MainActor.run {
                guard !Task.isCancelled, snapshot.isNewerThan(self.snapshotsByStableWorkspaceID[stableWorkspaceID]) else {
                    return
                }
                self.snapshotsByStableWorkspaceID[stableWorkspaceID] = snapshot
                notify(stableWorkspaceID)
            }
        }
    }

    func cancelRefreshes() {
        refreshTasksByStableWorkspaceID.values.forEach { $0.cancel() }
        refreshTasksByStableWorkspaceID.removeAll()
    }

    /// Uses PE's coding-agent association rather than the terminal's ambient repository context.
    private func displaySnapshot(
        _ display: ProvenanceWorkspaceDisplayRecord, stableWorkspaceID: UUID
    ) async -> WorkspaceDisplayCurrentStateSnapshot? {
        guard UUID(uuidString: display.workspaceID) == stableWorkspaceID else { return nil }
        var agentWorktree: ProvenanceWorktreeRecord?
        do {
            let response = try await client.workspaceCodingAgentSessionAssociation(.init(workspaceID: stableWorkspaceID.uuidString))
            if let association = response.association,
               association.sourcePath != "display",
               UUID(uuidString: association.workspaceID) == stableWorkspaceID,
               let worktreeID = association.worktreeID, let directory = association.currentDirectory {
                let expectedSession = display.lastSubmittedPromptSessionID?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                guard expectedSession == nil || [association.sessionID, association.canonicalSessionID, association.rawSessionID].contains(expectedSession) else {
                    return WorkspaceDisplayCurrentStateSnapshot(display)
                }
                // Session CWD can be below the Git root; only PE's associated ID can confirm a match.
                var path = directory
                while !path.isEmpty, !Task.isCancelled {
                    let context = try await client.currentContext(.init(
                        repositoryPath: path, activeSessionLimit: 0, dirtyFileLimit: 0,
                        unattributedChangeLimit: 0, recentCheckpointLimit: 0, validationRunLimit: 0, conflictLimit: 0
                    ))
                    if context.worktree?.id == worktreeID { agentWorktree = context.worktree; break }
                    guard path != "/", let separator = path.lastIndex(of: "/") else { break }
                    path = separator == path.startIndex ? "/" : String(path[..<separator])
                }
            }
        } catch {
            StartupBreadcrumbLog.append("workProvenance.displayCurrentState.agentWorktreeReadFailed", fields: [
                "workspace": stableWorkspaceID.uuidString, "error": String(describing: error)
            ])
        }
        return WorkspaceDisplayCurrentStateSnapshot(display, agentWorktree: agentWorktree)
    }
}
