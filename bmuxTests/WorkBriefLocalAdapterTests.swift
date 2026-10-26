import BmuxWorkBrief
import Foundation
import ProvenanceEngineContracts
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@Suite
struct WorkBriefLocalAdapterTests {
    @Test
    func keepsOnlyExplicitSecureLinksAndObservedLocalStatus() throws {
        let id = UUID()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let display = ProvenanceWorkspaceDisplayRecord(id: "display", workspaceID: id.uuidString,
            repositoryID: "roof-plans", branch: "feature/roof-review", pullRequestNumber: 42,
            pullRequestURL: "https://github.com/example/roof-plans/pull/42",
            ticketIDs: ["ROOF-18", "ROOF-19"],
            ticketLinks: [
                .init(id: "ROOF-18", system: "linear", url: "https://linear.app/example/issue/ROOF-18"),
                .init(id: "ROOF-19", system: "linear", url: "http://example.test/private")
            ], observedAt: now, updatedAt: now)
        let live = WorkspaceExplorerLiveWorkspace(stableID: id, runtimeID: UUID(),
            title: "Maple Street Roof Inspection", createdAt: now, colorHex: nil,
            display: display, lastActivityAt: now, liveStatus: .needsInput)
        let result = WorkspaceExplorerHistoryLoadResult(items: WorkspaceExplorerHistoryAdapter().join(
            live: [live], archived: [], eligibilityByID: [:]), archiveAvailability: .available,
            partialLiveActivity: false)

        let snapshot = WorkBriefLocalAdapter().snapshot(result, surfaceIDs: [id: UUID().uuidString],
            checkedAt: now)
        let item = try #require(snapshot.localWorkspaces.first)
        #expect(snapshot.localWorkspaces.count == 1)
        #expect(item.status == .needsInput)
        #expect(item.repository == "roof-plans")
        #expect(item.tickets.map(\.id) == ["ROOF-18"])
        #expect(item.pullRequest?.url.host == "github.com")
        let allEvidenceObserved = item.evidence.allSatisfy { $0.isObserved }
        #expect(allEvidenceObserved)
        #expect(WorkBriefProjection(snapshot: snapshot).needsAttention.map(\.id) == [id])
    }

    @Test
    func partialPresenceDoesNotInventExternalLinksOrClaimFreshness() throws {
        let id = UUID()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let live = WorkspaceExplorerLiveWorkspace(stableID: id, runtimeID: UUID(),
            title: "Maple Street Roof Inspection", createdAt: now, colorHex: nil,
            display: nil, lastActivityAt: nil, liveStatus: .disconnected)
        let result = WorkspaceExplorerHistoryLoadResult(items: WorkspaceExplorerHistoryAdapter().join(
            live: [live], archived: [], eligibilityByID: [:]), archiveAvailability: .pending,
            partialLiveActivity: true, liveMetadataPending: true)

        let snapshot = WorkBriefLocalAdapter().snapshot(result, checkedAt: now)
        let item = try #require(snapshot.localWorkspaces.first)
        #expect(snapshot.localHealth.state == .partial)
        #expect(snapshot.linearHealth.state == .notConfigured)
        #expect(item.tickets.isEmpty)
        #expect(item.pullRequest == nil)
        #expect(item.evidence.map(\.field) == ["workspace"])
    }
}
