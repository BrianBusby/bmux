import BmuxSidebar
import Foundation

struct SidebarWorkspaceTitleResolution: Equatable, Sendable {
    enum Source: String, Sendable {
        case live
        case provenance
    }

    let title: String
    let source: Source
    let liveTitle: String
    let provenanceTitle: String?
    let liveTitleIsAuthoritative: Bool

    var suppressedStaleProvenanceTitle: Bool {
        guard liveTitleIsAuthoritative,
              source == .live,
              let provenanceTitle else {
            return false
        }
        return provenanceTitle != liveTitle
    }

    init(
        liveTitle: String,
        liveTitleIsAuthoritative: Bool,
        provenanceTitle: String?
    ) {
        let normalizedLiveTitle = Self.normalizedTitle(liveTitle) ?? liveTitle
        let normalizedProvenanceTitle = Self.normalizedTitle(provenanceTitle)
        self.liveTitle = normalizedLiveTitle
        self.provenanceTitle = normalizedProvenanceTitle
        self.liveTitleIsAuthoritative = liveTitleIsAuthoritative

        if liveTitleIsAuthoritative, Self.normalizedTitle(liveTitle) != nil {
            title = normalizedLiveTitle
            source = .live
        } else if let normalizedProvenanceTitle {
            title = normalizedProvenanceTitle
            source = .provenance
        } else {
            title = normalizedLiveTitle
            source = .live
        }
    }

    private static func normalizedTitle(_ title: String?) -> String? {
        let trimmed = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}

struct SidebarWorkspaceSnapshotBuilder {
    struct PresentationKey: Equatable {
        let showsWorkspaceDescription: Bool
        let usesVerticalBranchLayout: Bool
        let showsGitBranch: Bool
        let usesViewportAwarePath: Bool
        let visibleAuxiliaryDetails: SidebarWorkspaceAuxiliaryDetailVisibility
        let provenanceDisplaySnapshot: WorkspaceDisplayCurrentStateSnapshot?
        let titleResolution: SidebarWorkspaceTitleResolution
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
        let title: String?
        let label: String
        let url: URL?
        let status: SidebarPullRequestStatus
        let ownerLogin: String?
        let ownerURL: URL?
        let branch: String?
        let isStale: Bool
        let isFromProvenance: Bool

        func primaryLine(statusLabel: String) -> String {
            "\(label) #\(number) \(statusLabel)"
        }

        var titleLine: String? {
            let trimmedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return trimmedTitle.isEmpty ? nil : trimmedTitle
        }
    }

    struct TicketDisplay: Identifiable, Equatable {
        let id: String
        let title: String?
        let url: URL?
        let ownerName: String?
        let ownerURL: URL?

        var linkText: String {
            let trimmedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !trimmedTitle.isEmpty,
                  trimmedTitle.caseInsensitiveCompare(id) != .orderedSame else {
                return id
            }
            return "\(id): \(trimmedTitle)"
        }
    }

    struct ProjectDisplay: Identifiable, Equatable {
        let id: String
        let title: String?
        let url: URL?

        var linkText: String {
            let trimmedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return trimmedTitle.isEmpty ? id : trimmedTitle
        }
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
        let projectRows: [ProjectDisplay]
        let ticketRows: [TicketDisplay]
        var resourceLinks: ResourceLinkPresentation {
            SidebarWorkspaceSnapshotBuilder.resourceLinkPresentation(
                pullRequestRows: pullRequestRows,
                projectRows: projectRows,
                ticketRows: ticketRows
            )
        }
        let listeningPorts: [Int]
        let finderDirectoryPath: String?
        let repoBadgeAppearance: WorkspaceRepoBadgeAppearance?
        let mediaActivity: BrowserMediaActivity
        let hasActiveAIWork: Bool
    }

    @MainActor static func resourceLinkPresentation(
        workspace: Workspace,
        provenanceDisplaySnapshot: WorkspaceDisplayCurrentStateSnapshot?,
        label: String
    ) -> ResourceLinkPresentation {
        let orderedPanelIds = workspace.sidebarOrderedPanelIds()
        return resourceLinkPresentation(
            livePullRequests: workspace.sidebarPullRequestsInDisplayOrder(orderedPanelIds: orderedPanelIds),
            provenanceDisplaySnapshot: provenanceDisplaySnapshot,
            latestSubmittedMessage: provenanceDisplaySnapshot?.lastSubmittedPrompt ?? workspace.latestSubmittedMessage,
            latestConversationMessage: workspace.latestConversationMessage,
            label: label
        )
    }

    static func resourceLinkPresentation(
        livePullRequests: [SidebarPullRequestState],
        provenanceDisplaySnapshot: WorkspaceDisplayCurrentStateSnapshot?,
        latestSubmittedMessage: String?,
        latestConversationMessage: String?,
        label: String
    ) -> ResourceLinkPresentation {
        let pullRequestRows = pullRequestDisplays(
            livePullRequests: livePullRequests,
            provenancePullRequest: provenanceDisplaySnapshot?.pullRequest,
            provenanceCurrentDirectory: provenanceDisplaySnapshot?.currentDirectory,
            provenanceBranch: provenanceDisplaySnapshot?.branch,
            latestSubmittedMessage: latestSubmittedMessage,
            latestConversationMessage: latestConversationMessage,
            label: label
        )
        return resourceLinkPresentation(
            pullRequestRows: pullRequestRows,
            projectRows: projectDisplays(from: provenanceDisplaySnapshot),
            ticketRows: ticketDisplays(from: provenanceDisplaySnapshot)
        )
    }

    static func resourceLinkPresentation(
        pullRequestRows: [PullRequestDisplay],
        projectRows: [ProjectDisplay],
        ticketRows: [TicketDisplay]
    ) -> ResourceLinkPresentation {
        ResourceLinkPresentation(
            ticketRows: ticketRows,
            pullRequestRows: pullRequestRows,
            projectRows: projectRows,
            ownerRows: ownerDisplays(
                pullRequestRows: pullRequestRows,
                ticketRows: ticketRows
            )
        )
    }

    static func selectedWorkspaceHeaderResources(
        _ resources: ResourceLinkPresentation,
        isSelected: Bool
    ) -> ResourceLinkPresentation? {
        guard isSelected, resources.hasHeaderItems else {
            return nil
        }
        return resources
    }

    static func showsSidebarResourceRows(
        selectedWorkspaceHeaderResources: ResourceLinkPresentation?
    ) -> Bool {
        selectedWorkspaceHeaderResources?.hasHeaderItems != true
    }

    static func ticketDisplays(
        from provenanceDisplaySnapshot: WorkspaceDisplayCurrentStateSnapshot?
    ) -> [TicketDisplay] {
        provenanceDisplaySnapshot?.ticketLinks.map {
            TicketDisplay(
                id: $0.id,
                title: $0.title,
                url: $0.url,
                ownerName: $0.ownerName,
                ownerURL: $0.ownerURL
            )
        } ?? []
    }

    static func projectDisplays(
        from provenanceDisplaySnapshot: WorkspaceDisplayCurrentStateSnapshot?
    ) -> [ProjectDisplay] {
        provenanceDisplaySnapshot?.projectLinks.map {
            ProjectDisplay(
                id: $0.id,
                title: $0.title,
                url: $0.url
            )
        } ?? []
    }

    private static func ownerDisplays(
        pullRequestRows: [PullRequestDisplay],
        ticketRows: [TicketDisplay]
    ) -> [OwnerDisplay] {
        var seenKeys = Set<String>()
        var owners: [OwnerDisplay] = []

        func append(name: String?, url: URL?, source: String) {
            let trimmedName = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !trimmedName.isEmpty else { return }
            let identity = url?.absoluteString.lowercased() ?? trimmedName.lowercased()
            guard seenKeys.insert(identity).inserted else { return }
            owners.append(OwnerDisplay(
                id: "\(source):\(trimmedName.lowercased())|\(url?.absoluteString ?? "")",
                name: trimmedName,
                url: url
            ))
        }

        for pullRequest in pullRequestRows {
            append(name: pullRequest.ownerLogin, url: pullRequest.ownerURL, source: "pullRequest")
        }
        for ticket in ticketRows {
            append(name: ticket.ownerName, url: ticket.ownerURL, source: "ticket")
        }

        return owners
    }

    static func pullRequestDisplays(
        livePullRequests: [SidebarPullRequestState],
        provenancePullRequest: WorkspaceDisplayCurrentStatePullRequestSnapshot?,
        provenanceCurrentDirectory: String? = nil,
        provenanceBranch: String? = nil,
        latestSubmittedMessage: String?,
        latestConversationMessage: String?,
        label: String
    ) -> [PullRequestDisplay] {
        if !livePullRequests.isEmpty {
            return livePullRequests.map {
                livePullRequestDisplay(
                    $0,
                    provenancePullRequest: matchingProvenancePullRequest(
                        for: $0,
                        provenancePullRequest: provenancePullRequest
                    )
                )
            }
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
        let hasMatchingPromptNumber = mentionedNumbers.contains(pullRequest.number)
        let hasPromptContradiction = !mentionedNumbers.isEmpty && !hasMatchingPromptNumber
        guard !hasPromptContradiction else {
            return []
        }
        guard hasMatchingPromptNumber || Workspace.looksLikePullRequestScopedWorktree(
            number: pullRequest.number,
            candidates: [provenanceCurrentDirectory, provenanceBranch, pullRequest.branch]
        ) else {
            return []
        }

        let url = pullRequest.url ?? promptMention?.url
        return [PullRequestDisplay(
            id: "\(label.lowercased())#\(pullRequest.number)|\(url?.absoluteString ?? "")",
            number: pullRequest.number,
            title: nil,
            label: label,
            url: url,
            status: pullRequest.status.flatMap(SidebarPullRequestStatus.init(rawValue:)) ?? .open,
            ownerLogin: pullRequest.ownerLogin,
            ownerURL: pullRequestOwnerURL(
                login: pullRequest.ownerLogin,
                url: pullRequest.ownerURL
            ),
            branch: pullRequest.branch,
            isStale: pullRequest.isStale,
            isFromProvenance: true
        )]
    }

    private static func livePullRequestDisplay(
        _ pullRequest: SidebarPullRequestState,
        provenancePullRequest: WorkspaceDisplayCurrentStatePullRequestSnapshot? = nil
    ) -> PullRequestDisplay {
        let ownerLogin = pullRequest.ownerLogin ?? provenancePullRequest?.ownerLogin
        let ownerURL = pullRequestOwnerURL(
            login: ownerLogin,
            url: pullRequest.ownerURL ?? provenancePullRequest?.ownerURL
        )
        let branch = pullRequest.branch ?? provenancePullRequest?.branch
        return PullRequestDisplay(
            id: "\(pullRequest.label.lowercased())#\(pullRequest.number)|\(pullRequest.url.absoluteString)",
            number: pullRequest.number,
            title: pullRequest.title,
            label: pullRequest.label,
            url: pullRequest.url,
            status: pullRequest.status,
            ownerLogin: ownerLogin,
            ownerURL: ownerURL,
            branch: branch,
            isStale: pullRequest.isStale,
            isFromProvenance: false
        )
    }

    private static func matchingProvenancePullRequest(
        for pullRequest: SidebarPullRequestState,
        provenancePullRequest: WorkspaceDisplayCurrentStatePullRequestSnapshot?
    ) -> WorkspaceDisplayCurrentStatePullRequestSnapshot? {
        guard let provenancePullRequest,
              provenancePullRequest.number == pullRequest.number else {
            return nil
        }
        guard let provenanceURL = provenancePullRequest.url else {
            return provenancePullRequest
        }
        return provenanceURL == pullRequest.url ? provenancePullRequest : nil
    }

    private static func promptPullRequestDisplay(
        _ mention: SubmittedPromptPullRequestMention,
        label: String
    ) -> PullRequestDisplay {
        PullRequestDisplay(
            id: "\(label.lowercased())#\(mention.number)|\(mention.url.absoluteString)",
            number: mention.number,
            title: nil,
            label: label,
            url: mention.url,
            status: .open,
            ownerLogin: nil,
            ownerURL: nil,
            branch: nil,
            isStale: false,
            isFromProvenance: false
        )
    }

    private static func firstPromptPullRequestMention(
        messages: [String?]
    ) -> SubmittedPromptPullRequestMention? {
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
