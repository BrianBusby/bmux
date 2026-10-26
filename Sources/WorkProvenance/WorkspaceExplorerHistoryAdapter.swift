import Foundation
import ProvenanceEngineContracts

struct WorkspaceExplorerHistoryAdapter {
    func join(
        live: [WorkspaceExplorerLiveWorkspace],
        archived: [ProvenanceArchivedWorkspaceRecord],
        sessionWorkspaces: [ProvenanceWorkspaceHistorySummary] = [],
        eligibilityByID: [UUID: WorkspaceExplorerReopenEligibility]
    ) -> [WorkspaceExplorerHistoryItem] {
        let archiveByID = Dictionary(archived.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let sessionsByWorkspaceID = Dictionary(sessionWorkspaces.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first })
        let liveIDs = Set(live.map { $0.stableID.uuidString })
        let open = live.map { workspace in
            let id = workspace.stableID.uuidString
            return WorkspaceExplorerHistoryItem(
                id: id,
                title: workspace.title,
                createdAt: archiveByID[id]?.createdAt ?? workspace.createdAt,
                closedAt: nil,
                lastActivityAt: [workspace.lastActivityAt, archiveByID[id]?.lastActivityAt,
                    sessionsByWorkspaceID[id]?.lastActivityAt]
                    .compactMap { $0 }.max(),
                colorHex: workspace.colorHex,
                display: workspace.display ?? archiveByID[id]?.displayAtClose ??
                    sessionsByWorkspaceID[id]?.display,
                repositoryID: workspace.display?.repositoryID ?? archiveByID[id]?.displayAtClose?.repositoryID ??
                    sessionsByWorkspaceID[id]?.display?.repositoryID ??
                    sessionsByWorkspaceID[id]?.lastKnownRepositoryID,
                liveWorkspaceID: workspace.runtimeID,
                liveStatus: workspace.liveStatus,
                archive: archiveByID[id],
                reopenEligibility: .unavailable(.alreadyOpen)
            )
        }
        let closed = archived.filter { !liveIDs.contains($0.id) }.map { record in
            WorkspaceExplorerHistoryItem(
                id: record.id,
                title: record.title,
                createdAt: record.createdAt,
                closedAt: record.closedAt,
                lastActivityAt: [record.lastActivityAt,
                    sessionsByWorkspaceID[record.id]?.lastActivityAt].compactMap { $0 }.max(),
                colorHex: record.colorHex,
                display: record.displayAtClose ?? sessionsByWorkspaceID[record.id]?.display,
                repositoryID: record.displayAtClose?.repositoryID ??
                    sessionsByWorkspaceID[record.id]?.display?.repositoryID ??
                    sessionsByWorkspaceID[record.id]?.lastKnownRepositoryID,
                liveWorkspaceID: nil,
                liveStatus: .closedHistorical,
                archive: record,
                reopenEligibility: UUID(uuidString: record.id)
                    .flatMap { eligibilityByID[$0] } ?? .unavailable(.noRestoreSnapshot)
            )
        }
        let knownIDs = liveIDs.union(archiveByID.keys)
        let historical = sessionWorkspaces.filter {
            !knownIDs.contains($0.id) && UUID(uuidString: $0.id) != nil
        }.map { workspace in
            let title = workspace.display?.title?.trimmingCharacters(in: .whitespacesAndNewlines)
            let directoryName = (workspace.display?.currentDirectory ?? workspace.lastKnownDirectory).map {
                URL(fileURLWithPath: $0).lastPathComponent
            }
            return WorkspaceExplorerHistoryItem(
                id: workspace.id,
                title: title.flatMap { $0.isEmpty ? nil : $0 } ??
                    directoryName.flatMap { $0.isEmpty ? nil : $0 } ??
                    String(localized: "explorer.untitledWorkspace", defaultValue: "Untitled workspace"),
                createdAt: nil,
                closedAt: nil,
                lastActivityAt: workspace.lastActivityAt,
                colorHex: nil,
                display: workspace.display,
                repositoryID: workspace.display?.repositoryID ?? workspace.lastKnownRepositoryID,
                liveWorkspaceID: nil,
                liveStatus: .closedHistorical,
                archive: nil,
                reopenEligibility: .unavailable(.noRestoreSnapshot)
            )
        }
        let past = (closed + historical).sorted { lhs, rhs in
            let left = lhs.lastActivityAt ?? lhs.closedAt ?? lhs.createdAt ?? .distantPast
            let right = rhs.lastActivityAt ?? rhs.closedAt ?? rhs.createdAt ?? .distantPast
            return left == right ? lhs.id > rhs.id : left > right
        }
        return open + past
    }
}
