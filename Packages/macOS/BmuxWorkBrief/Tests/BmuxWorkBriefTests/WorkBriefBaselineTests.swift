import Foundation
import Testing
@testable import BmuxWorkBrief

@Suite struct WorkBriefBaselineTests {
    @Test func changedFactsUseCurrentItemsAndExactStableIDs() {
        let now = Date(timeIntervalSince1970: 1_000)
        let workspace = local(status: .running, at: now)
        let issue = external("linear:42", status: "Todo", at: now)
        let first = snapshot([workspace], [issue], at: now)
        let baseline = WorkBriefBaseline(snapshot: first, previous: nil, at: now)
        #expect(baseline.changes(in: first).localIDs.isEmpty)
        #expect(baseline.changes(in: first).externalIDs.isEmpty)
        let changed = snapshot([local(id: workspace.id, status: .needsInput, at: now)],
                               [external("linear:42", status: "In Progress", at: now)], at: now)
        let changes = baseline.changes(in: changed)
        #expect(changes.localIDs == [workspace.id])
        #expect(changes.externalIDs == ["linear:42"])
        #expect(changes.since == now)
    }

    @Test func failureDoesNotErasePreviousProviderFingerprintOrClaimChange() {
        let now = Date(timeIntervalSince1970: 1_000)
        let issue = external("linear:42", status: "Todo", at: now)
        let baseline = WorkBriefBaseline(snapshot: snapshot([], [issue], at: now),
                                         previous: nil, at: now)
        let failed = snapshot([], [issue], at: now, linear: .failed)
        #expect(baseline.changes(in: failed).externalIDs.isEmpty)
        let retained = WorkBriefBaseline(snapshot: failed, previous: baseline,
                                         at: now.addingTimeInterval(60))
        #expect(retained.external == baseline.external)
        #expect(retained.changes(in: snapshot([], [issue], at: now)).externalIDs.isEmpty)
        let expired = WorkBriefBaseline(snapshot: failed, previous: retained,
                                        at: now.addingTimeInterval(31 * 24 * 3600))
        #expect(expired.external.isEmpty)
    }

    @Test func previousBriefExpiresAfterThirtyDays() {
        let now = Date(timeIntervalSince1970: 1_000)
        let baseline = WorkBriefBaseline(snapshot: snapshot([], [], at: now),
                                         previous: nil, at: now)
        #expect(baseline.valid(at: now.addingTimeInterval(30 * 24 * 3600)))
        #expect(!baseline.valid(at: now.addingTimeInterval(31 * 24 * 3600)))
    }

    @Test func maximalMetadataFitsPersistenceCapWithoutInventingChanges() throws {
        let now = Date(timeIntervalSince1970: 1_000)
        let workspaces = (0..<100).map { index in
            let id = UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index))!
            let tickets = (0..<12).map { ticket in
                WorkBriefLink(id: "CC-\(index)-\(ticket)-" + String(repeating: "X", count: 75),
                    label: "Ticket", url: URL(string: "https://linear.app/acme/issue/CC-1")!, source: .linear)
            }
            return WorkBriefLocalWorkspace(id: id, runtimeID: UUID(), title: "Roof inspection",
                repository: nil, branch: nil, tickets: tickets, pullRequest: nil,
                status: .running, surfaceID: nil, lastActivityAt: now,
                checkedAt: now, evidence: [])
        }
        let issues = (0..<100).map { index in
            external("linear:" + String(repeating: "I", count: 100) + "\(index)",
                     status: "In Progress", at: now)
        }
        let current = snapshot(workspaces, issues, at: now)
        let baseline = WorkBriefBaseline(snapshot: current, previous: nil, at: now)
        #expect(try JSONEncoder().encode(baseline).count <= 64_000)
        #expect(baseline.changes(in: current).localIDs.isEmpty)
        #expect(baseline.changes(in: current).externalIDs.isEmpty)
    }

    private func local(id: UUID = UUID(), status: WorkBriefLocalStatus,
                       at now: Date) -> WorkBriefLocalWorkspace {
        WorkBriefLocalWorkspace(id: id, runtimeID: UUID(), title: "Roof inspection",
            repository: "CompanyCam/mobile", branch: nil, tickets: [], pullRequest: nil,
            status: status, surfaceID: nil, lastActivityAt: now, checkedAt: now, evidence: [])
    }

    private func external(_ id: String, status: String, at now: Date) -> WorkBriefExternalItem {
        WorkBriefExternalItem(id: id, source: .linear, title: "Roof inspection",
            url: URL(string: "https://linear.app/acme/issue/CC-42")!, reference: "CC-42",
            repository: nil, owner: nil, status: status, updatedAt: now,
            checkedAt: now, disposition: .needsAttention, evidence: [])
    }

    private func snapshot(_ local: [WorkBriefLocalWorkspace], _ external: [WorkBriefExternalItem],
                          at now: Date,
                          linear: WorkBriefSourceHealth.State = .available) -> WorkBriefSnapshot {
        let current = WorkBriefSourceHealth(state: .available, checkedAt: now)
        let missing = WorkBriefSourceHealth(state: .notConfigured, checkedAt: nil)
        return WorkBriefSnapshot(localWorkspaces: local, externalItems: external,
            localHealth: current, linearHealth: WorkBriefSourceHealth(state: linear, checkedAt: now),
            githubHealth: missing, slackHealth: missing)
    }
}
