import Foundation
import Testing
@testable import BmuxWorkBrief

@Suite struct WorkBriefProjectionTests {
    @Test func attentionUsesVerifiedStatusAndKeepsOpenWorkVisible() {
        let now = Date()
        let pending = workspace(status: .needsInput, checkedAt: now)
        let idle = workspace(status: .idle, checkedAt: now)
        let projection = WorkBriefProjection(snapshot: snapshot([idle, pending], checkedAt: now))
        #expect(projection.inProgress.map(\.id) == [pending.id, idle.id])
        #expect(projection.needsAttention.map(\.id) == [pending.id])
        #expect(projection.waitingOn.isEmpty)
    }

    @Test func partialSourceDoesNotEraseKnownWork() {
        let now = Date()
        let item = workspace(status: .running, checkedAt: now)
        let brief = snapshot([item], checkedAt: now, health: .partial)
        #expect(brief.localHealth.state == .partial)
        #expect(WorkBriefProjection(snapshot: brief).inProgress.map(\.id) == [item.id])
        #expect(brief.linearHealth.state == .notConfigured)
    }

    private func workspace(status: WorkBriefLocalStatus, checkedAt: Date) -> WorkBriefLocalWorkspace {
        WorkBriefLocalWorkspace(id: UUID(), runtimeID: UUID(), title: "Roof inspection",
            repository: "companycam-mobile", branch: "feature/roof-inspection", tickets: [],
            pullRequest: nil, status: status, surfaceID: nil, lastActivityAt: checkedAt,
            checkedAt: checkedAt, evidence: [])
    }

    private func snapshot(_ items: [WorkBriefLocalWorkspace], checkedAt: Date,
                          health: WorkBriefSourceHealth.State = .available) -> WorkBriefSnapshot {
        let missing = WorkBriefSourceHealth(state: .notConfigured, checkedAt: nil)
        return WorkBriefSnapshot(localWorkspaces: items,
            localHealth: WorkBriefSourceHealth(state: health, checkedAt: checkedAt),
            linearHealth: missing, githubHealth: missing, slackHealth: missing)
    }
}
