import Foundation
import ProvenanceEngineContracts
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@Suite
struct WorkspaceExplorerSessionHistoryAdapterTests {
    @Test
    func sessionHistoryFromAnotherRunAppearsOnceWithReadOnlyIdentity() {
        let id = UUID()
        let activity = Date(timeIntervalSince1970: 1_800_000_000)
        let summary = ProvenanceWorkspaceHistorySummary(id: id.uuidString,
            firstSessionAt: activity.addingTimeInterval(-120), lastActivityAt: activity,
            sessionCount: 2, lastKnownDirectory: "/work/roof-inspection",
            lastKnownRepositoryID: "repository-roof")
        let adapter = WorkspaceExplorerHistoryAdapter()
        let items = adapter.join(live: [], archived: [], sessionWorkspaces: [summary], eligibilityByID: [:])
        #expect(items.count == 1)
        #expect(items[0].title == "roof-inspection")
        #expect(items[0].isSessionHistoryOnly)
        #expect(items[0].lastActivityAt == activity)
        #expect(WorkspaceExplorerCatalog(.init(items: items, archiveAvailability: .available,
            partialLiveActivity: false)).workspaces[0].repository == "repository-roof")
        #expect(items[0].reopenEligibility == .unavailable(.noRestoreSnapshot))

        let closedAt = activity.addingTimeInterval(60)
        let archive = ProvenanceArchivedWorkspaceRecord(
            id: id.uuidString, title: "Maple Street Roof Inspection",
            createdAt: closedAt.addingTimeInterval(-3600), closedAt: closedAt,
            lastActivityAt: closedAt.addingTimeInterval(-300), displayAtClose: nil,
            colorHex: "#3B6FD6", coverageCode: nil)
        let joined = adapter.join(live: [], archived: [archive], sessionWorkspaces: [summary],
            eligibilityByID: [:])
        #expect(joined.count == 1)
        #expect(joined[0].archive == archive)
        #expect(!joined[0].isSessionHistoryOnly)
    }
}
