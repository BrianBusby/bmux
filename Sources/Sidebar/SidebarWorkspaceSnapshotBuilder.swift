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
        if !livePullRequests.isEmpty {
            return livePullRequests.map { livePullRequestDisplay($0) }
        }

        let messages = [latestSubmittedMessage, latestConversationMessage]
        let promptMention = firstPromptPullRequestMention(messages: messages)
        if let promptMention,
           promptMention.number != provenancePullRequest?.number {
            return [promptPullRequestDisplay(promptMention, label: label)]
        }

        guard let pullRequest = provenancePullRequest else {
            return promptMention.map { [promptPullRequestDisplay($0, label: label)] } ?? []
        }
        let mentionedNumbers = pullRequestNumbers(messages: messages)
        guard mentionedNumbers.isEmpty || mentionedNumbers.contains(pullRequest.number) else {
            return []
        }

        let url = pullRequest.url ?? promptMention?.url
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

    private static func livePullRequestDisplay(_ pullRequest: SidebarPullRequestState) -> PullRequestDisplay {
        PullRequestDisplay(
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

    private static func promptPullRequestDisplay(
        _ mention: (number: Int, url: URL),
        label: String
    ) -> PullRequestDisplay {
        PullRequestDisplay(
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

    private static func firstPromptPullRequestMention(
        messages: [String?]
    ) -> (number: Int, url: URL)? {
        for message in messages {
            guard let mention = Workspace.submittedPromptPullRequestMention(from: message) else {
                continue
            }
            return mention
        }
        return nil
    }

    private static func pullRequestNumbers(messages: [String?]) -> Set<Int> {
        var numbers = Set<Int>()
        for message in messages {
            for number in pullRequestNumbers(message: message) {
                numbers.insert(number)
            }
        }
        return numbers
    }

    private static func pullRequestNumbers(message: String?) -> [Int] {
        guard let message else { return [] }
        let pattern = #"(?i)(?:https?://github\.com/[^/\s"'<>]+/[^/\s"'<>]+/pull/|(?:\bPR\b|\bpull request\b|\bpull\b)\s*#?\s*)([0-9]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsMessage = message as NSString
        let range = NSRange(location: 0, length: nsMessage.length)
        return regex.matches(in: message, range: range).compactMap { match in
            guard match.numberOfRanges == 2 else { return nil }
            return Int(nsMessage.substring(with: match.range(at: 1)))
        }
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
