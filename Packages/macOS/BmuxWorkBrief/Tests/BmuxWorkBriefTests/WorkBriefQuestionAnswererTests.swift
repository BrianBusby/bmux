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
        #expect(answerer.answer("Which PR goes with CC-4?", snapshot: snapshot).kind == .noEvidence)
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

    @Test func localizedQuestionsUseTheSameSourceFacts() {
        let now = Date(timeIntervalSince1970: 100)
        let ticket = WorkBriefLink(id: "CC-42", label: "CC-42",
            url: URL(string: "https://linear.app/acme/issue/CC-42")!, source: .linear)
        let pr = WorkBriefLink(id: "pr-12", label: "#12",
            url: URL(string: "https://github.com/CompanyCam/mobile/pull/12")!, source: .github)
        let local = WorkBriefLocalWorkspace(id: UUID(), runtimeID: UUID(), title: "Roof inspection",
            repository: "CompanyCam/mobile", branch: "roof", tickets: [ticket],
            pullRequest: pr, status: .running, surfaceID: nil, lastActivityAt: now,
            checkedAt: now, evidence: [])
        let review = external("github:12", disposition: .needsAttention, now: now)
        let waiting = external("github:13", disposition: .waitingOn, now: now)
        let snapshot = brief([local], external: [review, waiting], now: now)
        let answerer = WorkBriefQuestionAnswerer()
        #expect(answerer.answer("何に対応が必要ですか？", snapshot: snapshot).externalIDs == [review.id])
        #expect(answerer.answer("何を待っていますか？", snapshot: snapshot).externalIDs == [waiting.id])
        #expect(answerer.answer("何が進行中ですか？", snapshot: snapshot).localIDs == [local.id])
        #expect(answerer.answer("CC-42に関連するPRは？", snapshot: snapshot).links == [pr])
    }

    @Test func blockerQuestionNeedsAnExactObservedItem() {
        let now = Date(timeIntervalSince1970: 100)
        let first = external("github:13", disposition: .waitingOn, now: now)
        let second = external("github:14", disposition: .waitingOn, now: now)
        let active = external("github:15", disposition: .inProgress, now: now)
        let snapshot = brief([], external: [first, second, active], now: now)
        let answerer = WorkBriefQuestionAnswerer()
        #expect(answerer.answer("Why is #13 blocked?", snapshot: snapshot).externalIDs == [first.id])
        #expect(answerer.answer("Why is this blocked?", snapshot: snapshot).kind != .waitingOn)
        #expect(answerer.answer("Why is #15 blocked?", snapshot: snapshot).kind != .waitingOn)
    }

    @Test func localOnlyTicketHasNoObservedBlockerReason() {
        let now = Date(timeIntervalSince1970: 100)
        let ticket = WorkBriefLink(id: "CC-42", label: "CC-42",
            url: URL(string: "https://linear.app/acme/issue/CC-42")!, source: .linear)
        let local = WorkBriefLocalWorkspace(id: UUID(), runtimeID: UUID(), title: "Roof inspection",
            repository: "CompanyCam/mobile", branch: nil, tickets: [ticket],
            pullRequest: nil, status: .running, surfaceID: nil, lastActivityAt: now,
            checkedAt: now, evidence: [])
        let snapshot = brief([local], external: [], now: now)
        #expect(WorkBriefQuestionAnswerer().answer("Why is CC-42 blocked?", snapshot: snapshot).kind == .noWaitEvidence)
    }

    private func external(_ id: String, disposition: WorkBriefExternalItem.Disposition,
                          now: Date) -> WorkBriefExternalItem {
        let number = id.split(separator: ":").last.map(String.init) ?? "12"
        let url = URL(string: "https://github.com/CompanyCam/mobile/pull/\(number)")!
        let evidence = disposition == .waitingOn
            ? [WorkBriefEvidence(id: "\(id):reviewers", source: .github,
                field: "awaitingReview", isObserved: true, checkedAt: now, url: url)] : []
        return WorkBriefExternalItem(id: id, source: .github, title: "Roof inspection",
            url: url,
            reference: "#\(number)", repository: "CompanyCam/mobile", owner: "brian",
            status: "open", updatedAt: now, checkedAt: now,
            disposition: disposition, evidence: evidence)
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
