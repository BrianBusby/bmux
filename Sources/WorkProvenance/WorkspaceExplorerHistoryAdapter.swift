import Foundation
import ProvenanceEngineContracts

struct WorkspaceExplorerHistoryAdapter {
    func join(
        live: [WorkspaceExplorerLiveWorkspace],
        archived: [ProvenanceArchivedWorkspaceRecord],
        eligibilityByID: [UUID: WorkspaceExplorerReopenEligibility]
    ) -> [WorkspaceExplorerHistoryItem] {
        let archiveByID = Dictionary(archived.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let liveIDs = Set(live.map { $0.stableID.uuidString })
        let open = live.map { workspace in
            let id = workspace.stableID.uuidString
            return WorkspaceExplorerHistoryItem(
                id: id,
                title: workspace.title,
                createdAt: archiveByID[id]?.createdAt ?? workspace.createdAt,
                closedAt: nil,
                lastActivityAt: [workspace.lastActivityAt, archiveByID[id]?.lastActivityAt]
                    .compactMap { $0 }.max(),
                colorHex: workspace.colorHex,
                display: workspace.display ?? archiveByID[id]?.displayAtClose,
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
                lastActivityAt: record.lastActivityAt,
                colorHex: record.colorHex,
                display: record.displayAtClose,
                liveWorkspaceID: nil,
                liveStatus: .closedHistorical,
                archive: record,
                reopenEligibility: UUID(uuidString: record.id)
                    .flatMap { eligibilityByID[$0] } ?? .unavailable(.noRestoreSnapshot)
            )
        }
        return open + closed
    }
}
