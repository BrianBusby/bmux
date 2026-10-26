import Foundation
import ProvenanceEngineContracts

/// Immutable presentation for one workspace card, projected before the list boundary.
struct WorkspaceReferenceCardSnapshot: Identifiable, Equatable {
    let id: UUID
    let hasActiveAIWork: Bool
    let title: String
    let titleIsTicket: Bool
    let prompt: String?
    let branch: String?
    let isDirty: Bool?
    let ticketID: String?
    let ticketURL: URL?
    let projectTitle: String?
    let projectURL: URL?
    let projectFilterTitle: String?
    let pullRequestText: String?
    let pullRequestURL: URL?
    let ownerName: String?
    let ownerURL: URL?
    let ownerAvatarURL: URL?
    let pullRequestOwnerLogin: String?

    var ownerInitials: String? {
        guard let words = ownerName?.split(whereSeparator: \.isWhitespace),
              let first = words.first else { return nil }
        if let last = words.last, words.count > 1 {
            return (String(first.prefix(1)) + String(last.prefix(1))).uppercased()
        }
        return String(first.prefix(2)).uppercased()
    }

    @MainActor
    init(workspace: Workspace, provenance: WorkspaceDisplayCurrentStateSnapshot?, workspaceTitle: String) {
        let context = provenance
        let titlePresentation = WorkspaceCardTitlePresentation(
            workspaceTitle: workspaceTitle, ticketTitle: context?.ticketLinks.first?.title
        )
        id = workspace.id
        hasActiveAIWork = workspace.hasActiveAIWork
        title = titlePresentation.title
        titleIsTicket = titlePresentation.usesTicketTitle
        prompt = provenance?.lastSubmittedPrompt ?? workspace.latestSubmittedMessage
        branch = context?.agentWorktreeBranch
        isDirty = branch == nil ? nil : context?.agentWorktree?.isDirty
        ticketID = context?.ticketLinks.first?.id
        ticketURL = context?.ticketLinks.first?.url
        let project = provenance?.projectLinks.first
        projectTitle = project.map { $0.title ?? $0.id }
        projectURL = project?.url
        projectFilterTitle = project?.title
        if let request = workspace.pullRequest {
            pullRequestText = "#\(request.number) · \(request.title ?? "")".trimmingCharacters(in: .whitespacesAndNewlines)
            pullRequestURL = request.url
        } else if let request = provenance?.pullRequest {
            pullRequestText = "#\(request.number) ·".trimmingCharacters(in: .whitespacesAndNewlines)
            pullRequestURL = request.url
        } else {
            pullRequestText = nil
            pullRequestURL = nil
        }
        let pullRequestOwner: (name: String?, url: URL?, avatarURL: URL?)?
        let matchingProvenancePullRequest = provenance?.pullRequest.flatMap { request in
            workspace.pullRequest == nil || (workspace.pullRequest?.number == request.number
                && (request.url == nil || workspace.pullRequest?.url == request.url)) ? request : nil
        }
        if let request = workspace.pullRequest, let login = request.ownerLogin {
            pullRequestOwner = (
                login,
                request.ownerURL ?? matchingProvenancePullRequest?.ownerURL,
                request.ownerAvatarURL ?? matchingProvenancePullRequest?.ownerAvatarURL
            )
        } else if let request = matchingProvenancePullRequest {
            pullRequestOwner = (request.ownerLogin, request.ownerURL, request.ownerAvatarURL)
        } else {
            pullRequestOwner = nil
        }
        pullRequestOwnerLogin = pullRequestOwner?.name
        let ticketOwnerName = context?.ticketLinks.first?.ownerName
        ownerName = pullRequestOwner?.name ?? ticketOwnerName
        ownerURL = pullRequestOwner?.name != nil
            ? pullRequestOwner?.url
            : context?.ticketLinks.first?.ownerURL
        ownerAvatarURL = pullRequestOwner?.name != nil ? pullRequestOwner?.avatarURL : nil
    }

    init(explorerItem item: WorkspaceExplorerHistoryItem, hiddenDimensions: Set<WorkspaceExplorerDimension>) {
        let display = item.display
        let ticket = display?.ticketLinks.first
        let ticketID = ticket?.id ?? display?.ticketIDs.first
        let project = display?.projectLinks.first
        let titlePresentation = WorkspaceCardTitlePresentation(
            workspaceTitle: item.title, ticketTitle: hiddenDimensions.contains(.ticket) ? nil : ticket?.title
        )
        id = UUID(uuidString: item.id) ?? item.liveWorkspaceID ?? UUID()
        hasActiveAIWork = item.isOpen && (item.liveStatus == .running || item.liveStatus == .needsInput)
        title = titlePresentation.title
        titleIsTicket = titlePresentation.usesTicketTitle && !hiddenDimensions.contains(.ticket)
        prompt = display?.lastSubmittedPrompt
        branch = display?.branch
        isDirty = display?.isDirty
        self.ticketID = hiddenDimensions.contains(.ticket) ? nil : ticketID
        ticketURL = hiddenDimensions.contains(.ticket) ? nil : ticket?.url.flatMap(URL.init(string:))
        projectTitle = hiddenDimensions.contains(.project) ? nil : project.map { $0.title ?? $0.id }
        projectURL = hiddenDimensions.contains(.project) ? nil : project?.url.flatMap(URL.init(string:))
        projectFilterTitle = project?.title
        if let number = display?.pullRequestNumber {
            let status = hiddenDimensions.contains(.pullRequestStatus) ? nil : display?.pullRequestStatus
            pullRequestText = (["#\(number)", status].compactMap { $0 }).joined(separator: " · ")
        } else {
            pullRequestText = nil
        }
        pullRequestURL = display?.pullRequestURL.flatMap(URL.init(string:))
        pullRequestOwnerLogin = display?.pullRequestOwnerLogin
        let pullRequestOwner = hiddenDimensions.contains(.pullRequestOwner)
            ? nil : display?.pullRequestOwnerLogin
        ownerName = pullRequestOwner ?? ticket?.ownerName
        let pullRequestOwnerURL = display?.pullRequestOwnerURL.flatMap(URL.init(string:))
        ownerURL = pullRequestOwner != nil ? pullRequestOwnerURL : ticket?.ownerURL.flatMap(URL.init(string:))
        let pullRequestAvatarURL = display?.pullRequestOwnerAvatarURL.flatMap(URL.init(string:))
        ownerAvatarURL = pullRequestOwner != nil ? pullRequestAvatarURL : nil
    }
}
