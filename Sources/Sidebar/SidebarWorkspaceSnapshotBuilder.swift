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
        let isStale: Bool
    }

    struct TicketDisplay: Identifiable, Equatable {
        let id: String
        let url: URL?
    }

    struct Snapshot: Equatable {
        let presentationKey: PresentationKey
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
