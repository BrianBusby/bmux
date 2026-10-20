import Foundation
import ProvenanceEngineContracts

enum WorkspaceExplorerReopenReason: Equatable {
    case historyLoading
    case noRestoreSnapshot
    case noDirectoryRecorded
    case directoryRemoved
    case noRestorablePanels
    case alreadyOpen
    case unsupportedRemoteRestore
}

enum WorkspaceExplorerReopenEligibility: Equatable {
    case eligible(recordID: UUID)
    case unavailable(WorkspaceExplorerReopenReason)
}

/// Immutable input captured from bmux's live workspace owner on the main actor.
struct WorkspaceExplorerLiveWorkspace {
    let stableID: UUID
    let runtimeID: UUID
    let title: String
    let createdAt: Date
    let colorHex: String?
    let display: ProvenanceWorkspaceDisplayRecord?
    let lastActivityAt: Date?
}

/// One logical workspace, even when a retained archive also exists for a live tab.
struct WorkspaceExplorerHistoryItem: Identifiable {
    let id: String
    let title: String
    let createdAt: Date?
    let closedAt: Date?
    let lastActivityAt: Date?
    let colorHex: String?
    let display: ProvenanceWorkspaceDisplayRecord?
    let liveWorkspaceID: UUID?
    let archive: ProvenanceArchivedWorkspaceRecord?
    let reopenEligibility: WorkspaceExplorerReopenEligibility

    var isOpen: Bool { liveWorkspaceID != nil }
}

enum WorkspaceExplorerArchiveAvailability: Equatable {
    case available
    case unavailable
}

struct WorkspaceExplorerHistoryLoadResult {
    let items: [WorkspaceExplorerHistoryItem]
    let archiveAvailability: WorkspaceExplorerArchiveAvailability
    let partialLiveActivity: Bool
}

enum WorkspaceExplorerHistoryAdapter {
    static func join(
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
                display: workspace.display,
                liveWorkspaceID: workspace.runtimeID,
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
                archive: record,
                reopenEligibility: UUID(uuidString: record.id)
                    .flatMap { eligibilityByID[$0] } ?? .unavailable(.noRestoreSnapshot)
            )
        }
        return open + closed
    }
}

