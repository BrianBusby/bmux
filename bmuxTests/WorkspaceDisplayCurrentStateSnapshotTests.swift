import Foundation
import ProvenanceEngineContracts
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@Suite
struct WorkspaceDisplayCurrentStateSnapshotTests {
    @Test
    func normalizesDisplayFacts() throws {
        let updatedAt = Date(timeIntervalSince1970: 700)
        let record = ProvenanceWorkspaceDisplayRecord(
            id: "workspace-display-1",
            workspaceID: "99999999-9999-9999-9999-999999999999",
            repositoryID: "repo-1",
            worktreeID: "worktree-1",
            currentDirectory: " /tmp/bmux ",
            title: " Current Slice ",
            titleSource: "user",
            branch: " pe-workspace-display-tab-projection ",
            pullRequestNumber: 57,
            pullRequestURL: "https://github.com/manaflow-ai/bmux/pull/57",
            pullRequestOwnerLogin: " octocat ",
            pullRequestOwnerURL: " https://github.com/octocat ",
            pullRequestStatus: "merged",
            pullRequestBranch: "pe-workspace-display-tab-projection",
            pullRequestIsStale: true,
            isDirty: false,
            ticketIDs: [" STE-1964 ", "STE-1964", "GH-57"],
            ticketLinks: [
                ProvenanceWorkspaceDisplayTicketLinkRecord(
                    id: "STE-1964",
                    system: "linear",
                    title: " Canonical domain mutation paths ",
                    url: "https://linear.app/companycam/issue/STE-1964",
                    ownerName: " Brian Busby ",
                    ownerURL: " https://linear.app/companycam/user/brian "
                )
            ],
            projectLinks: [
                ProvenanceWorkspaceDisplayProjectLinkRecord(
                    id: " context-efficiency-c1b9a ",
                    system: " linear ",
                    title: " Context Efficiency ",
                    url: " https://linear.app/companycam/project/context-efficiency-c1b9a "
                )
            ],
            currentWorkSummary: " Durable context reconciliation ",
            lastSubmittedPrompt: " Keep these facts visible ",
            lastSubmittedPromptSubmittedAt: Date(timeIntervalSince1970: 701),
            lastSubmittedPromptSessionID: " session-1 ",
            latestEventID: " event-1 ",
            latestEventSequence: 12,
            observedAt: updatedAt,
            updatedAt: updatedAt
        )

        let snapshot = try #require(WorkspaceDisplayCurrentStateSnapshot(record))

        #expect(snapshot.stableWorkspaceID == UUID(uuidString: "99999999-9999-9999-9999-999999999999"))
        #expect(snapshot.title == "Current Slice")
        #expect(snapshot.currentDirectory == "/tmp/bmux")
        #expect(snapshot.branch == "pe-workspace-display-tab-projection")
        #expect(snapshot.pullRequest?.number == 57)
        #expect(snapshot.pullRequest?.url == URL(string: "https://github.com/manaflow-ai/bmux/pull/57"))
        #expect(snapshot.pullRequest?.ownerLogin == "octocat")
        #expect(snapshot.pullRequest?.ownerURL == URL(string: "https://github.com/octocat"))
        #expect(snapshot.pullRequest?.status == "merged")
        #expect(snapshot.pullRequest?.branch == "pe-workspace-display-tab-projection")
        #expect(snapshot.pullRequest?.isStale == true)
        #expect(snapshot.isDirty == false)
        #expect(snapshot.ticketLinks.map(\.id) == ["STE-1964", "GH-57"])
        #expect(snapshot.ticketLinks.first?.system == "linear")
        #expect(snapshot.ticketLinks.first?.title == "Canonical domain mutation paths")
        #expect(snapshot.ticketLinks.first?.url == URL(string: "https://linear.app/companycam/issue/STE-1964"))
        #expect(snapshot.ticketLinks.first?.ownerName == "Brian Busby")
        #expect(snapshot.ticketLinks.first?.ownerURL == URL(string: "https://linear.app/companycam/user/brian"))
        #expect(snapshot.ticketLinks.last?.system == "linear")
        #expect(snapshot.ticketLinks.last?.title == nil)
        #expect(snapshot.ticketLinks.last?.url == URL(string: "https://linear.app/companycam/issue/GH-57"))
        #expect(snapshot.projectLinks.first?.id == "context-efficiency-c1b9a")
        #expect(snapshot.projectLinks.first?.system == "linear")
        #expect(snapshot.projectLinks.first?.title == "Context Efficiency")
        #expect(snapshot.projectLinks.first?.url == URL(string: "https://linear.app/companycam/project/context-efficiency-c1b9a"))
        #expect(snapshot.currentWorkSummary == "Durable context reconciliation")
        #expect(snapshot.lastSubmittedPrompt == "Keep these facts visible")
        #expect(snapshot.lastSubmittedPromptSubmittedAt == Date(timeIntervalSince1970: 701))
        #expect(snapshot.lastSubmittedPromptSessionID == "session-1")
        #expect(snapshot.latestEventID == "event-1")
        #expect(snapshot.latestEventSequence == 12)
    }

    @Test
    func prefersHigherEventSequence() throws {
        let older = try #require(WorkspaceDisplayCurrentStateSnapshot(workspaceDisplayRecord(
            branch: "older",
            sequence: 4,
            updatedAt: Date(timeIntervalSince1970: 900)
        )))
        let newer = try #require(WorkspaceDisplayCurrentStateSnapshot(workspaceDisplayRecord(
            branch: "newer",
            sequence: 5,
            updatedAt: Date(timeIntervalSince1970: 800)
        )))

        #expect(newer.isNewerThan(older))
        #expect(!older.isNewerThan(newer))
    }

    private func workspaceDisplayRecord(
        branch: String,
        sequence: Int,
        updatedAt: Date
    ) -> ProvenanceWorkspaceDisplayRecord {
        ProvenanceWorkspaceDisplayRecord(
            id: "workspace-display-\(sequence)",
            workspaceID: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
            repositoryID: nil, worktreeID: nil, currentDirectory: nil, title: nil, titleSource: nil,
            branch: branch,
            pullRequestNumber: nil, pullRequestURL: nil, pullRequestOwnerLogin: nil, pullRequestOwnerURL: nil, pullRequestStatus: nil, pullRequestBranch: nil,
            pullRequestIsStale: false,
            isDirty: nil, ticketIDs: [], ticketLinks: [], projectLinks: [],
            latestEventID: "event-\(sequence)",
            latestEventSequence: sequence,
            observedAt: updatedAt,
            updatedAt: updatedAt
        )
    }
}
