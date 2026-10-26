import BmuxSidebar
import Foundation
import ProvenanceEngineContracts
import ProvenanceEngineSDK
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

extension SidebarWorkspaceCardPresentationTests {
    @MainActor @Test func referenceCardKeepsPullRequestAvatarWhenTicketHasAnOwner() throws {
        let workspace = Workspace(title: "Review roof inspection")
        let avatarURL = "https://avatars.githubusercontent.com/u/42?v=4"
        let record = ProvenanceWorkspaceDisplayRecord(
            id: "roof-work", workspaceID: workspace.stableId.uuidString,
            pullRequestNumber: 42, pullRequestOwnerLogin: "sam",
            pullRequestOwnerURL: "https://github.com/sam",
            pullRequestOwnerAvatarURL: avatarURL,
            ticketLinks: [.init(id: "ROOF-42", title: "Repair flashing", ownerName: "Alex")],
            observedAt: Date(timeIntervalSince1970: 900), updatedAt: Date(timeIntervalSince1970: 900)
        )
        let provenance = try #require(WorkspaceDisplayCurrentStateSnapshot(record, agentWorktree: nil))

        let card = Self.referenceCard(workspace: workspace, provenance: provenance)

        #expect(card.ownerName == "sam")
        #expect(card.ownerURL == URL(string: "https://github.com/sam"))
        #expect(card.ownerAvatarURL == URL(string: avatarURL))
    }

    @MainActor @Test func referenceRailUsesLivePullRequestOwnerAvatar() throws {
        let workspace = Workspace(title: "Review roof inspection")
        let panelID = try #require(workspace.focusedPanelId)
        let pullRequestURL = try #require(URL(string: "https://github.com/example/repo/pull/42"))
        let avatarURL = try #require(URL(string: "https://avatars.githubusercontent.com/u/42?v=4"))
        workspace.updatePanelPullRequest(
            panelId: panelID, number: 42, label: "PR", url: pullRequestURL,
            ownerLogin: "octocat", ownerAvatarURL: avatarURL, status: .open
        )

        let card = Self.referenceCard(workspace: workspace, provenance: nil)
        #expect(card.ownerName == "octocat")
        #expect(card.ownerAvatarURL == avatarURL)
    }

    @MainActor @Test func referenceRailUsesMatchingProvenanceAvatarOnlyForPullRequestOwner() throws {
        let workspace = Workspace(title: "Review roof inspection")
        let panelID = try #require(workspace.focusedPanelId)
        let pullRequestURL = try #require(URL(string: "https://github.com/example/repo/pull/42"))
        let avatarURL = try #require(URL(string: "https://avatars.githubusercontent.com/u/42?v=4"))
        workspace.updatePanelPullRequest(
            panelId: panelID, number: 42, label: "PR", url: pullRequestURL,
            ownerLogin: "octocat", status: .open
        )
        let record = ProvenanceWorkspaceDisplayRecord(
            id: "roof-work", workspaceID: workspace.stableId.uuidString,
            pullRequestNumber: 42, pullRequestURL: pullRequestURL.absoluteString,
            pullRequestOwnerLogin: "octocat", pullRequestOwnerAvatarURL: avatarURL.absoluteString,
            observedAt: Date(), updatedAt: Date()
        )
        let provenance = try #require(WorkspaceDisplayCurrentStateSnapshot(record))
        #expect(Self.referenceCard(workspace: workspace, provenance: provenance).ownerAvatarURL == avatarURL)

        let ticketOwnerRecord = ProvenanceWorkspaceDisplayRecord(
            id: "roof-work", workspaceID: workspace.stableId.uuidString,
            pullRequestNumber: 42, pullRequestURL: pullRequestURL.absoluteString,
            pullRequestOwnerLogin: "octocat", pullRequestOwnerAvatarURL: avatarURL.absoluteString,
            ticketLinks: [.init(id: "ROOF-42", ownerName: "Sam")],
            observedAt: Date(), updatedAt: Date()
        )
        let ticketOwnerProvenance = try #require(WorkspaceDisplayCurrentStateSnapshot(ticketOwnerRecord))
        let ticketOwnerCard = Self.referenceCard(workspace: workspace, provenance: ticketOwnerProvenance)
        #expect(ticketOwnerCard.ownerName == "Sam")
        #expect(ticketOwnerCard.ownerAvatarURL == nil)

        let otherPullRequestRecord = ProvenanceWorkspaceDisplayRecord(
            id: "roof-work", workspaceID: workspace.stableId.uuidString,
            pullRequestNumber: 43, pullRequestURL: "https://github.com/example/repo/pull/43",
            pullRequestOwnerLogin: "another-owner", pullRequestOwnerAvatarURL: avatarURL.absoluteString,
            observedAt: Date(), updatedAt: Date()
        )
        let otherPullRequestProvenance = try #require(WorkspaceDisplayCurrentStateSnapshot(otherPullRequestRecord))
        #expect(Self.referenceCard(workspace: workspace, provenance: otherPullRequestProvenance).ownerAvatarURL == nil)
    }

}
