import Foundation
import Testing
@testable import BmuxWorkBrief

@Suite @MainActor struct WorkBriefCoordinatorTests {
    @Test func liveStatusUpdatesWithoutReloadingSourceFacts() async {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let id = UUID()
        let item = WorkBriefLocalWorkspace(id: id, runtimeID: UUID(), title: "Roof inspection",
            repository: "companycam-mobile", branch: "feature/roof-inspection", tickets: [],
            pullRequest: nil, status: .idle, surfaceID: nil, lastActivityAt: now,
            checkedAt: now, evidence: [])
        let unavailable = WorkBriefSourceHealth(state: .notConfigured, checkedAt: nil)
        let snapshot = WorkBriefSnapshot(localWorkspaces: [item],
            localHealth: WorkBriefSourceHealth(state: .available, checkedAt: now),
            linearHealth: unavailable, githubHealth: unavailable, slackHealth: unavailable)
        let coordinator = WorkBriefCoordinator(initialSnapshot: snapshot) {
            Issue.record("A live status change must not requery Provenance Engine")
            return snapshot
        }

        coordinator.observeLocalStatus(id: id, status: .needsInput)

        #expect(coordinator.snapshot?.localWorkspaces.first?.status == .needsInput)
        #expect(coordinator.snapshot?.localWorkspaces.first?.checkedAt == now)
        #expect(coordinator.snapshot?.localHealth == snapshot.localHealth)
    }
}
