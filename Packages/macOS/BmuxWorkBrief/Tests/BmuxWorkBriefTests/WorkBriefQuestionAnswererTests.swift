import Foundation
import Testing
@testable import BmuxWorkBrief

@Suite struct WorkBriefQuestionAnswererTests {
    @Test func ticketPRQuestionUsesOnlyExplicitLocalLinks() {
        let ticket = WorkBriefLink(id: "CC-42", label: "CC-42",
            url: URL(string: "https://linear.app/acme/issue/CC-42")!, source: .linear)
        let pr = WorkBriefLink(id: "pr-12", label: "#12",
            url: URL(string: "https://github.com/CompanyCam/mobile/pull/12")!, source: .github)
        let now = Date(timeIntervalSince1970: 100)
        let local = WorkBriefLocalWorkspace(id: UUID(), runtimeID: UUID(), title: "Roof inspection",
            repository: "CompanyCam/mobile", branch: "CC-42-roof", tickets: [ticket],
            pullRequest: pr, status: .running, surfaceID: nil, lastActivityAt: now,
            checkedAt: now, evidence: [])
        let missing = WorkBriefLocalWorkspace(id: UUID(), runtimeID: UUID(), title: "Wall inspection",
            repository: "CompanyCam/mobile", branch: "CC-43-wall", tickets: [],
            pullRequest: pr, status: .running, surfaceID: nil, lastActivityAt: now,
            checkedAt: now, evidence: [])
        let snapshot = brief([local, missing], external: [], now: now)
        let answerer = WorkBriefQuestionAnswerer()
        let found = answerer.answer("Which PR goes with CC-42?", snapshot: snapshot)
        #expect(found.kind == .ticketPullRequest)
        #expect(found.localIDs == [local.id])
        #expect(found.links == [pr])
        #expect(answerer.answer("Which PR goes with CC-43?", snapshot: snapshot).kind == .noEvidence)
    }

    @Test func attentionAndWaitingUseOnlyClassifiedFacts() {
        let now = Date(timeIntervalSince1970: 100)
        let review = external("github:12", disposition: .needsAttention, now: now)
        let waiting = external("github:13", disposition: .waitingOn, now: now)
        let snapshot = brief([], external: [review, waiting], now: now)
        let answerer = WorkBriefQuestionAnswerer()
        #expect(answerer.answer("What needs my attention?", snapshot: snapshot).externalIDs == [review.id])
        #expect(answerer.answer("What am I waiting on?", snapshot: snapshot).externalIDs == [waiting.id])
    }

    private func external(_ id: String, disposition: WorkBriefExternalItem.Disposition,
                          now: Date) -> WorkBriefExternalItem {
        WorkBriefExternalItem(id: id, source: .github, title: "Roof inspection",
            url: URL(string: "https://github.com/CompanyCam/mobile/pull/12")!,
            reference: "#12", repository: "CompanyCam/mobile", owner: "brian",
            status: "open", updatedAt: now, checkedAt: now,
            disposition: disposition, evidence: [])
    }

    private func brief(_ local: [WorkBriefLocalWorkspace], external: [WorkBriefExternalItem],
                       now: Date) -> WorkBriefSnapshot {
        let current = WorkBriefSourceHealth(state: .available, checkedAt: now)
        let missing = WorkBriefSourceHealth(state: .notConfigured, checkedAt: nil)
        return WorkBriefSnapshot(localWorkspaces: local, externalItems: external,
            localHealth: current, linearHealth: missing, githubHealth: current,
            slackHealth: missing)
    }
}
