import Foundation
import ProvenanceEngineContracts

/// One logical workspace, even when a retained archive also exists for a live tab.
struct WorkspaceExplorerHistoryItem: Identifiable {
    let id: String
    let title: String
    let createdAt: Date?
    let closedAt: Date?
    let lastActivityAt: Date?
    let colorHex: String?
    let display: ProvenanceWorkspaceDisplayRecord?
    let repositoryID: String?
    let liveWorkspaceID: UUID?
    let liveStatus: WorkspaceExplorerStatus
    let archive: ProvenanceArchivedWorkspaceRecord?
    let reopenEligibility: WorkspaceExplorerReopenEligibility

    var isOpen: Bool { liveWorkspaceID != nil }
    var isSessionHistoryOnly: Bool { liveWorkspaceID == nil && archive == nil }
    var hasUnverifiedPresence: Bool {
        isSessionHistoryOnly || (!isOpen && archive != nil &&
            lastActivityAt.map { $0 > (closedAt ?? .distantFuture) } == true)
    }

    func withSessionHistory(_ historical: Self?) -> Self {
        guard let historical else { return self }
        let laterThanClose = !isOpen && historical.lastActivityAt.map {
            $0 > (closedAt ?? .distantFuture)
        } == true
        return Self(id: id, title: title, createdAt: createdAt, closedAt: closedAt,
            lastActivityAt: [lastActivityAt, historical.lastActivityAt].compactMap { $0 }.max(),
            colorHex: colorHex,
            display: laterThanClose ? historical.display ?? display : display ?? historical.display,
            repositoryID: laterThanClose ? historical.repositoryID ?? repositoryID :
                repositoryID ?? historical.repositoryID,
            liveWorkspaceID: liveWorkspaceID, liveStatus: liveStatus,
            archive: archive, reopenEligibility: reopenEligibility)
    }

    var lastRecordedStatus: WorkspaceExplorerStatus? {
        guard let code = archive?.lastRecordedStatusCode else { return nil }
        return WorkspaceExplorerStatus(archiveCode: code)
    }

    func withLiveStatus(_ status: WorkspaceExplorerStatus) -> Self {
        Self(id: id, title: title, createdAt: createdAt, closedAt: closedAt,
            lastActivityAt: lastActivityAt, colorHex: colorHex, display: display,
            repositoryID: repositoryID,
            liveWorkspaceID: liveWorkspaceID, liveStatus: status,
            archive: archive, reopenEligibility: reopenEligibility)
    }
}
