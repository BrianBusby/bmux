import Foundation
import ProvenanceEngineContracts

enum WorkspaceExplorerHistoryLoadError: Error {
    case archiveUnavailable
}

@MainActor
extension AppDelegate {
    /// Loads archive facts from PE and joins them with current tab presence.
    /// Failed archive reads preserve open cards while marking closed counts unknown.
    func loadWorkspaceExplorerHistory() async throws -> WorkspaceExplorerHistoryLoadResult {
        let service = workProvenanceRuntime?.workspaceArchiveService
        let archived: [ProvenanceArchivedWorkspaceRecord]
        let availability: WorkspaceExplorerArchiveAvailability
        if let service {
            do {
                archived = try await service.archivedWorkspaces()
                availability = .available
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                archived = []
                availability = .unavailable
            }
        } else {
            archived = []
            availability = .unavailable
        }
        var factsByID: [UUID: (display: ProvenanceWorkspaceDisplayRecord?, lastActivityAt: Date?)] = [:]
        var partialLiveActivity = service == nil
        let initialWorkspaces = workspaceExplorerLiveWorkspaces()
        if let service {
            for workspace in initialWorkspaces {
                do {
                    factsByID[workspace.stableId] = try await service.liveFacts(stableWorkspaceID: workspace.stableId)
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    partialLiveActivity = true
                }
            }
        }
        let currentWorkspaces = workspaceExplorerLiveWorkspaces()
        if Set(currentWorkspaces.map(\.stableId)) != Set(initialWorkspaces.map(\.stableId)) {
            partialLiveActivity = true
        }
        let live = currentWorkspaces.map { workspace in
            let facts = factsByID[workspace.stableId]
            return WorkspaceExplorerLiveWorkspace(
                stableID: workspace.stableId,
                runtimeID: workspace.id,
                title: workspace.bmuxEventWorkspaceTitle,
                createdAt: workspace.createdAt,
                colorHex: workspace.customColor,
                display: facts?.display,
                lastActivityAt: facts?.lastActivityAt
            )
        }
        let liveIDs = Set(currentWorkspaces.map(\.stableId))
        let restoreRecords = ClosedItemHistoryStore.shared.workspaceRestoreRecordsByStableID()
        let eligibilityByID = Dictionary(uniqueKeysWithValues: archived.compactMap { record in
            UUID(uuidString: record.id).map { stableID in
                (
                    stableID,
                    workspaceExplorerReopenEligibility(
                        stableID: stableID,
                        liveIDs: liveIDs,
                        candidate: restoreRecords[stableID]
                    )
                )
            }
        })
        return WorkspaceExplorerHistoryLoadResult(
            items: WorkspaceExplorerHistoryAdapter.join(
                live: live,
                archived: archived,
                eligibilityByID: eligibilityByID
            ),
            archiveAvailability: availability,
            partialLiveActivity: partialLiveActivity
        )
    }

    func workspaceExplorerSessions(
        stableID: UUID,
        limit: Int = 50,
        cursor: String? = nil
    ) async throws -> ProvenanceWorkspaceSessionPageResponse {
        guard let service = workProvenanceRuntime?.workspaceArchiveService else {
            throw WorkspaceExplorerHistoryLoadError.archiveUnavailable
        }
        return try await service.workspaceSessions(stableWorkspaceID: stableID, limit: limit, cursor: cursor)
    }

    func clearWorkspaceExplorerHistory() async throws {
        guard let service = workProvenanceRuntime?.workspaceArchiveService else {
            throw WorkspaceExplorerHistoryLoadError.archiveUnavailable
        }
        try await service.clearExplorerHistory()
    }

    func workspaceExplorerLiveWorkspaces() -> [Workspace] {
        var managers: [TabManager] = []
        var seenManagers: Set<ObjectIdentifier> = []
        for manager in mainWindowContexts.values.map(\.tabManager) + [tabManager].compactMap({ $0 }) {
            guard seenManagers.insert(ObjectIdentifier(manager)).inserted else { continue }
            managers.append(manager)
        }
        var seenWorkspaces: Set<UUID> = []
        return managers.flatMap(\.tabs).filter { seenWorkspaces.insert($0.stableId).inserted }
    }
}

