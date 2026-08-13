import BmuxSidebar
import Foundation

struct SidebarWorkspaceSnapshotBuilder {
    struct PresentationKey: Equatable {
        let showsWorkspaceDescription: Bool
        let usesVerticalBranchLayout: Bool
        let showsGitBranch: Bool
        let usesViewportAwarePath: Bool
        let visibleAuxiliaryDetails: SidebarWorkspaceAuxiliaryDetailVisibility
        let provenanceDisplaySnapshot: WorkspaceDisplayCurrentStateSnapshot?
    }

    struct VerticalBranchDirectoryLine: Equatable {
        let branch: String?
        // Ordered longest to shortest. Empty means no directory to show.
        // First element is the canonical display string when only one is needed.
        let directoryCandidates: [String]

        var directory: String? { directoryCandidates.first }
    }

    struct PullRequestDisplay: Identifiable, Equatable {
        let id: String
        let number: Int
        let label: String
        let url: URL?
        let status: SidebarPullRequestStatus
        let ownerLogin: String?
        let ownerURL: URL?
        let isStale: Bool
        let isFromProvenance: Bool
    }

    struct TicketDisplay: Identifiable, Equatable {
        let id: String
        let title: String?
        let url: URL?
        let ownerName: String?
        let ownerURL: URL?
    }

    struct Snapshot: Equatable {
        let presentationKey: PresentationKey
        let ticketTitle: String?
        let title: String
        let customDescription: String?
        let isPinned: Bool
        let customColorHex: String?
        let remoteWorkspaceSidebarText: String?
        let remoteConnectionStatusText: String
        let remoteStateHelpText: String
        let showsRemoteReconnectAffordance: Bool
        let copyableSidebarSSHError: String?
        let latestConversationMessage: String?
        let latestSubmittedMessage: String?
        let metadataEntries: [SidebarStatusEntry]
        let metadataBlocks: [SidebarMetadataBlock]
        let latestLog: SidebarLogEntry?
        let progress: SidebarProgressState?
        let compactGitBranchSummaryText: String?
        let compactDirectoryCandidates: [String]
        let compactBranchDirectoryCandidates: [String]
        let branchDirectoryLines: [VerticalBranchDirectoryLine]
        let branchLinesContainBranch: Bool
        let pullRequestRows: [PullRequestDisplay]
        let ticketRows: [TicketDisplay]
        let listeningPorts: [Int]
        let finderDirectoryPath: String?
        let repoBadgeAppearance: WorkspaceRepoBadgeAppearance?
        let mediaActivity: BrowserMediaActivity
        let hasActiveAIWork: Bool
    }

    static func pullRequestDisplays(
        livePullRequests: [SidebarPullRequestState],
        provenancePullRequest: WorkspaceDisplayCurrentStatePullRequestSnapshot?,
        latestSubmittedMessage: String?,
        latestConversationMessage: String?,
        label: String
    ) -> [PullRequestDisplay] {
        guard let pullRequest = provenancePullRequest else { return [] }
        let url = pullRequest.url ?? provenancePullRequestURL(
            number: pullRequest.number,
            livePullRequests: livePullRequests,
            messages: [latestSubmittedMessage, latestConversationMessage]
        )
        return [PullRequestDisplay(
            id: "\(label.lowercased())#\(pullRequest.number)|\(url?.absoluteString ?? "")",
            number: pullRequest.number,
            label: label,
            url: url,
            status: pullRequest.status.flatMap(SidebarPullRequestStatus.init(rawValue:)) ?? .open,
            ownerLogin: pullRequest.ownerLogin,
            ownerURL: pullRequestOwnerURL(
                login: pullRequest.ownerLogin,
                url: pullRequest.ownerURL
            ),
            isStale: pullRequest.isStale,
            isFromProvenance: true
        )]
    }

    private static func provenancePullRequestURL(
        number: Int,
        livePullRequests: [SidebarPullRequestState],
        messages: [String?]
    ) -> URL? {
        if let livePullRequest = livePullRequests.first(where: { $0.number == number }) {
            return livePullRequest.url
        }

        for message in messages {
            guard let mention = Workspace.submittedPromptPullRequestMention(from: message, matchingNumber: number) else {
                continue
            }
            return mention.url
        }
        return nil
    }

    private static func pullRequestOwnerURL(login: String?, url: URL?) -> URL? {
        if let url { return url }
        guard let login = login?.trimmingCharacters(in: .whitespacesAndNewlines),
              !login.isEmpty else {
            return nil
        }
        return URL(string: "https://github.com/\(login)")
    }
}
