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
}

extension SidebarWorkspaceSnapshotBuilder {
    @MainActor
    static func pullRequestRows(
        whenVisible isVisible: Bool,
        provenance: PullRequestDisplay?,
        live: [SidebarPullRequestState],
        promptMessages: [String?]
    ) -> [PullRequestDisplay] {
        guard isVisible else { return [] }
        if let provenance { return [provenance] }
        let liveDisplays = live.map(PullRequestDisplay.init)
        if !liveDisplays.isEmpty { return liveDisplays }
        return PullRequestDisplay.promptFallback(from: promptMessages).map { [$0] } ?? []
    }
}

extension SidebarWorkspaceSnapshotBuilder.PullRequestDisplay {
    init(_ pullRequest: SidebarPullRequestState) {
        self.init(
            id: "\(pullRequest.label.lowercased())#\(pullRequest.number)|\(pullRequest.url.absoluteString)",
            number: pullRequest.number,
            label: pullRequest.label,
            url: pullRequest.url,
            status: pullRequest.status,
            ownerLogin: pullRequest.ownerLogin,
            ownerURL: pullRequest.ownerURL,
            isStale: pullRequest.isStale,
            isFromProvenance: false
        )
    }

    @MainActor
    static func promptFallback(from messages: [String?]) -> Self? {
        for message in messages {
            guard let mention = Workspace.submittedPromptPullRequestMention(from: message) else { continue }
            let label = String(localized: "sidebar.pullRequest.label", defaultValue: "PR")
            return Self(
                id: "\(label.lowercased())#\(mention.number)|\(mention.url.absoluteString)",
                number: mention.number,
                label: label,
                url: mention.url,
                status: .open,
                ownerLogin: nil,
                ownerURL: nil,
                isStale: false,
                isFromProvenance: false
            )
        }
        return nil
    }
}
