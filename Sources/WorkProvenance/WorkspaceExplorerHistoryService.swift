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
    typealias RecoverArchive = @MainActor () async throws -> [ProvenanceArchivedWorkspaceRecord]

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
    private let recoverArchive: RecoverArchive?

    init(archiveService: WorkProvenanceWorkspaceArchiveService?,
         recoverArchive: RecoverArchive? = nil,
         tabManagers: @escaping TabManagers,
         activeWorkspaceID: @escaping ActiveWorkspaceID,
         restoreRecords: @escaping RestoreRecords,
         reopenEligibility: @escaping ReopenEligibility) {
        self.archiveService = archiveService
        self.tabManagers = tabManagers
        self.activeWorkspaceID = activeWorkspaceID
        self.restoreRecords = restoreRecords
        self.reopenEligibility = reopenEligibility
        self.recoverArchive = recoverArchive
    }

    /// Enriched live facts and retained history complete after the immediate presence snapshot.
    func load() async throws -> WorkspaceExplorerHistoryLoadResult {
        async let archived = archiveSnapshot()
        let live = try await liveSnapshot()
        let archive = try await archived
        let repositoryIDs = Set(live.workspaces.compactMap { $0.display?.repositoryID } +
            archive.records.compactMap { $0.displayAtClose?.repositoryID })
        let repositoryNames = try await repositoryNamesSnapshot(for: repositoryIDs)
        return combine(live: live, archived: archive, repositoryNamesByID: repositoryNames)
    }

    /// Shows current tabs before any PE query can delay the first Explorer render.
    func presenceSnapshot() -> WorkspaceExplorerHistoryLoadResult {
        let live = LiveSnapshot(workspaces: liveWorkspaces().map { workspace in
            WorkspaceExplorerLiveWorkspace(stableID: workspace.stableId, runtimeID: workspace.id,
                title: workspace.bmuxEventWorkspaceTitle, createdAt: workspace.createdAt,
                colorHex: workspace.customColor, display: nil, lastActivityAt: nil,
                liveStatus: WorkspaceExplorerStatus.verified(of: workspace))
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
            let records: [ProvenanceArchivedWorkspaceRecord]
            if let recoverArchive {
                records = try await recoverArchive()
            } else {
                records = try await archiveService.archivedWorkspaces()
            }
            return ArchiveSnapshot(records: records, availability: .available)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            // Recovery failures leave archive completeness unknown, even if older rows remain readable.
            sentryCaptureError("Workspace Explorer archive load failed", category: "provenance",
                data: ["error_type": String(reflecting: type(of: error))])
            return ArchiveSnapshot(records: [], availability: .unavailable)
        }
    }

    private func repositoryNamesSnapshot(for repositoryIDs: Set<String>) async throws -> [String: String] {
        guard let archiveService, !repositoryIDs.isEmpty else { return [:] }
        do {
            return try await archiveService.repositoryNames(for: repositoryIDs)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            sentryCaptureError("Workspace Explorer repository names load failed", category: "provenance",
                data: ["error_type": String(reflecting: type(of: error))])
            return [:]
        }
    }

    func liveSnapshot(limit: Int? = nil) async throws -> LiveSnapshot {
        let allInitialWorkspaces = liveWorkspaces()
        let initialWorkspaces = Array(allInitialWorkspaces.prefix(max(0, limit ?? allInitialWorkspaces.count)))
        var factsByID: [UUID: (display: ProvenanceWorkspaceDisplayRecord?, lastActivityAt: Date?)] = [:]
        var partialActivity = archiveService == nil || allInitialWorkspaces.count > initialWorkspaces.count
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
        let allCurrentWorkspaces = liveWorkspaces()
        let currentWorkspaces = Array(allCurrentWorkspaces.prefix(max(0, limit ?? allCurrentWorkspaces.count)))
        if allCurrentWorkspaces.count > currentWorkspaces.count { partialActivity = true }
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
                liveStatus: WorkspaceExplorerStatus.verified(of: workspace)
            )
        }
        return LiveSnapshot(workspaces: live, partialActivity: partialActivity,
            activeWorkspaceID: activeWorkspaceID())
    }

    func combine(live: LiveSnapshot, archived: ArchiveSnapshot,
                 liveMetadataPending: Bool = false,
                 repositoryNamesByID: [String: String] = [:]) -> WorkspaceExplorerHistoryLoadResult {
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
            activeWorkspaceID: live.activeWorkspaceID,
            repositoryNamesByID: repositoryNamesByID
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

    func clearHistory(at timestamp: Date = Date()) async throws {
        guard let archiveService else { throw WorkspaceExplorerHistoryLoadError.archiveUnavailable }
        try await archiveService.clearExplorerHistory(at: timestamp)
    }
}

private enum WorkspaceExplorerHistoryLoadError: Error {
    case archiveUnavailable
}
