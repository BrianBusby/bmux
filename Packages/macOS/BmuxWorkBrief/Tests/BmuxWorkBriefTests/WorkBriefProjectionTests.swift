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

    @Test func onlyExplicitSourceLinksCorrelateExternalWork() {
        let now = Date(timeIntervalSince1970: 100)
        let url = URL(string: "https://linear.app/acme/issue/CC-42")!
        let linked = WorkBriefLocalWorkspace(id: UUID(), runtimeID: UUID(), title: "Roof inspection",
            repository: "companycam-mobile", branch: "CC-42-roof", tickets: [
                WorkBriefLink(id: "CC-42", label: "CC-42", url: url, source: .linear)],
            pullRequest: nil, status: .running, surfaceID: nil, lastActivityAt: now,
            checkedAt: now, evidence: [])
        let branchOnly = workspace(status: .running, checkedAt: now)
        let external = WorkBriefExternalItem(id: "linear:uuid-42", source: .linear,
            title: "Roof inspection", url: url, reference: "CC-42", repository: nil,
            owner: nil, status: "In progress", updatedAt: now, checkedAt: now,
            disposition: .inProgress, evidence: [])
        let unrelated = WorkBriefExternalItem(id: "linear:uuid-43", source: .linear,
            title: "Wall inspection", url: URL(string: "https://linear.app/acme/issue/CC-43")!,
            reference: "CC-43", repository: nil, owner: nil, status: "Todo", updatedAt: now,
            checkedAt: now, disposition: .needsAttention, evidence: [])
        let projection = WorkBriefProjection(snapshot: snapshot([linked, branchOnly],
            checkedAt: now, external: [external, unrelated]))
        #expect(projection.relatedWorkspaceIDs[external.id] == [linked.id])
        #expect(projection.relatedWorkspaceIDs[unrelated.id] == [])
        #expect(projection.externalInProgress.isEmpty)
        #expect(projection.externalNeedsAttention.map(\.id) == [unrelated.id])
    }

    @Test func exactPRLinkSurfacesConflictingStatus() {
        let now = Date(timeIntervalSince1970: 100)
        let url = URL(string: "https://github.com/CompanyCam/mobile/pull/12")!
        let local = WorkBriefLocalWorkspace(id: UUID(), runtimeID: UUID(), title: "Roof inspection",
            repository: "CompanyCam/mobile", branch: "roof", tickets: [],
            pullRequest: WorkBriefLink(id: url.absoluteString, label: "#12", url: url,
                source: .github), status: .idle, pullRequestStatus: "Merged",
            surfaceID: nil, lastActivityAt: now, checkedAt: now, evidence: [])
        let external = WorkBriefExternalItem(id: "github:12", source: .github,
            title: "Roof inspection", url: url, reference: "#12", repository: "CompanyCam/mobile",
            owner: "brian", status: "open", updatedAt: now, checkedAt: now,
            disposition: .inProgress, evidence: [])
        let projection = WorkBriefProjection(snapshot: snapshot([local], checkedAt: now,
            external: [external]))
        #expect(projection.relatedWorkspaceIDs[external.id] == [local.id])
        #expect(projection.conflictingExternalIDs == [external.id])
    }

    private func workspace(status: WorkBriefLocalStatus, checkedAt: Date) -> WorkBriefLocalWorkspace {
        WorkBriefLocalWorkspace(id: UUID(), runtimeID: UUID(), title: "Roof inspection",
            repository: "companycam-mobile", branch: "feature/roof-inspection", tickets: [],
            pullRequest: nil, status: status, surfaceID: nil, lastActivityAt: checkedAt,
            checkedAt: checkedAt, evidence: [])
    }

    private func snapshot(_ items: [WorkBriefLocalWorkspace], checkedAt: Date,
                          external: [WorkBriefExternalItem] = [],
                          health: WorkBriefSourceHealth.State = .available) -> WorkBriefSnapshot {
        let missing = WorkBriefSourceHealth(state: .notConfigured, checkedAt: nil)
        return WorkBriefSnapshot(localWorkspaces: items, externalItems: external,
            localHealth: WorkBriefSourceHealth(state: health, checkedAt: checkedAt),
            linearHealth: missing, githubHealth: missing, slackHealth: missing)
    }
}
