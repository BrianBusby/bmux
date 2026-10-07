import Foundation
import ProvenanceEngineContracts

/// Immutable presentation for one workspace card, projected before the list boundary.
struct WorkspaceReferenceCardSnapshot: Identifiable, Equatable {
    let id: UUID
    let hasActiveAIWork: Bool
    let title: String
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
        let pullRequestOwner: (name: String?, url: URL?)?
        if let request = workspace.pullRequest, let login = request.ownerLogin {
            pullRequestOwner = (login, request.ownerURL)
        } else if let request = provenance?.pullRequest,
                  workspace.pullRequest == nil || (workspace.pullRequest?.number == request.number
                      && workspace.pullRequest?.url == request.url) {
            pullRequestOwner = (request.ownerLogin, request.ownerURL)
        } else {
            pullRequestOwner = nil
        }
        pullRequestOwnerLogin = pullRequestOwner?.name
        ownerName = context?.ticketLinks.first?.ownerName ?? pullRequestOwner?.name
        ownerURL = context?.ticketLinks.first?.ownerName != nil
            ? context?.ticketLinks.first?.ownerURL
            : pullRequestOwner?.url
    }
}
