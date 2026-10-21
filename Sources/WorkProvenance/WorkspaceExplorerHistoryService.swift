import Foundation
import ProvenanceEngineContracts

/// Joins PE archive facts with bmux-owned live presence for one Explorer load.
@MainActor
final class WorkspaceExplorerHistoryService {
    typealias TabManagers = @MainActor () -> [TabManager]
    typealias ActiveWorkspaceID = @MainActor () -> String?
    typealias RestoreRecords = @MainActor () -> [UUID: ClosedItemHistoryRecord]
    typealias ReopenEligibility = @MainActor (
        UUID, Set<UUID>, ClosedItemHistoryRecord?
    ) -> WorkspaceExplorerReopenEligibility

    struct LiveSnapshot {
        let workspaces: [WorkspaceExplorerLiveWorkspace]
        let partialActivity: Bool
        let activeWorkspaceID: String?
    }

    struct ArchiveSnapshot {
        let records: [ProvenanceArchivedWorkspaceRecord]
        let availability: WorkspaceExplorerArchiveAvailability
    }

    private let archiveService: WorkProvenanceWorkspaceArchiveService?
    private let tabManagers: TabManagers
    private let activeWorkspaceID: ActiveWorkspaceID
    private let restoreRecords: RestoreRecords
    private let reopenEligibility: ReopenEligibility

    init(archiveService: WorkProvenanceWorkspaceArchiveService?,
         tabManagers: @escaping TabManagers,
         activeWorkspaceID: @escaping ActiveWorkspaceID,
         restoreRecords: @escaping RestoreRecords,
         reopenEligibility: @escaping ReopenEligibility) {
        self.archiveService = archiveService
        self.tabManagers = tabManagers
        self.activeWorkspaceID = activeWorkspaceID
        self.restoreRecords = restoreRecords
        self.reopenEligibility = reopenEligibility
    }

    /// Enriched live facts and retained history complete after the immediate presence snapshot.
    func load() async throws -> WorkspaceExplorerHistoryLoadResult {
        async let archived = archiveSnapshot()
        let live = try await liveSnapshot()
        return combine(live: live, archived: try await archived)
    }

    /// Shows current tabs before any PE query can delay the first Explorer render.
    func presenceSnapshot() -> WorkspaceExplorerHistoryLoadResult {
        let live = LiveSnapshot(workspaces: liveWorkspaces().map { workspace in
            WorkspaceExplorerLiveWorkspace(stableID: workspace.stableId, runtimeID: workspace.id,
                title: workspace.bmuxEventWorkspaceTitle, createdAt: workspace.createdAt,
                colorHex: workspace.customColor, display: nil, lastActivityAt: nil,
                liveStatus: WorkspaceExplorerLiveWorkspace.verifiedStatus(of: workspace))
        }, partialActivity: true, activeWorkspaceID: activeWorkspaceID())
        return combine(live: live, archived: ArchiveSnapshot(records: [],
            availability: archiveService == nil ? .unavailable : .pending),
            liveMetadataPending: true)
    }

    func archiveSnapshot() async throws -> ArchiveSnapshot {
        guard let archiveService else {
            return ArchiveSnapshot(records: [], availability: .unavailable)
        }
        do {
            return ArchiveSnapshot(records: try await archiveService.archivedWorkspaces(),
                availability: .available)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return ArchiveSnapshot(records: [], availability: .unavailable)
        }
    }

    func liveSnapshot() async throws -> LiveSnapshot {
        let initialWorkspaces = liveWorkspaces()
        var factsByID: [UUID: (display: ProvenanceWorkspaceDisplayRecord?, lastActivityAt: Date?)] = [:]
        var partialActivity = archiveService == nil
        if let archiveService {
            for workspace in initialWorkspaces {
                do {
                    factsByID[workspace.stableId] = try await archiveService.liveFacts(
                        stableWorkspaceID: workspace.stableId)
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    partialActivity = true
                }
            }
        }
        let currentWorkspaces = liveWorkspaces()
        if Set(currentWorkspaces.map(\.stableId)) != Set(initialWorkspaces.map(\.stableId)) {
            partialActivity = true
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
                lastActivityAt: facts?.lastActivityAt,
                liveStatus: WorkspaceExplorerLiveWorkspace.verifiedStatus(of: workspace)
            )
        }
        return LiveSnapshot(workspaces: live, partialActivity: partialActivity,
            activeWorkspaceID: activeWorkspaceID())
    }

    func combine(live: LiveSnapshot, archived: ArchiveSnapshot,
                 liveMetadataPending: Bool = false) -> WorkspaceExplorerHistoryLoadResult {
        let liveIDs = Set(live.workspaces.map(\.stableID))
        let records = archived.records.isEmpty ? [:] : restoreRecords()
        let eligibilityByID = Dictionary(uniqueKeysWithValues: archived.records.compactMap { record in
            UUID(uuidString: record.id).map { stableID in
                (stableID, reopenEligibility(stableID, liveIDs, records[stableID]))
            }
        })
        return WorkspaceExplorerHistoryLoadResult(
            items: WorkspaceExplorerHistoryAdapter().join(
                live: live.workspaces,
                archived: archived.records,
                eligibilityByID: eligibilityByID
            ),
            archiveAvailability: archived.availability,
            partialLiveActivity: live.partialActivity,
            liveMetadataPending: liveMetadataPending,
            activeWorkspaceID: live.activeWorkspaceID
        )
    }

    func liveWorkspaces() -> [Workspace] {
        var seenManagers: Set<ObjectIdentifier> = []
        var seenWorkspaces: Set<UUID> = []
        return tabManagers()
            .filter { seenManagers.insert(ObjectIdentifier($0)).inserted }
            .flatMap(\.tabs)
            .filter { seenWorkspaces.insert($0.stableId).inserted }
    }

    func sessions(stableID: UUID, limit: Int = 50, cursor: String? = nil) async throws
        -> ProvenanceWorkspaceSessionPageResponse {
        guard let archiveService else { throw WorkspaceExplorerHistoryLoadError.archiveUnavailable }
        return try await archiveService.workspaceSessions(stableWorkspaceID: stableID, limit: limit, cursor: cursor)
    }

    func evidence(sessionID: String) async throws -> (
        ProvenanceFactualSessionProjectionResponse, ProvenanceSessionOutcomeResponse
    ) {
        guard let archiveService else { throw WorkspaceExplorerHistoryLoadError.archiveUnavailable }
        return try await archiveService.sessionEvidence(sessionID: sessionID)
    }

    func clearHistory() async throws {
        guard let archiveService else { throw WorkspaceExplorerHistoryLoadError.archiveUnavailable }
        try await archiveService.clearExplorerHistory()
    }
}

private enum WorkspaceExplorerHistoryLoadError: Error {
    case archiveUnavailable
}
