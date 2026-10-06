import Foundation
import ProvenanceEngineContracts

/// Immutable presentation for one workspace card, projected before the list boundary.
struct WorkspaceReferenceCardSnapshot: Identifiable, Equatable {
    let id: UUID
    let title: String
    let prompt: String?
    let branch: String?
    let isDirty: Bool?
    let ticketID: String?
    let ticketURL: URL?
    let projectTitle: String?
    let projectURL: URL?
    let summary: String?
    let pullRequestText: String?
    let pullRequestURL: URL?
    let ownerName: String?
    let ownerURL: URL?

    @MainActor
    init(workspace: Workspace, provenance: WorkspaceDisplayCurrentStateSnapshot?, workspaceTitle: String) {
        let context = provenance
        let titlePresentation = WorkspaceCardTitlePresentation(
            workspaceTitle: workspaceTitle, ticketTitle: context?.ticketLinks.first?.title
        )
        id = workspace.id
        title = titlePresentation.title
        prompt = provenance?.lastSubmittedPrompt ?? workspace.latestSubmittedMessage
        branch = context?.agentWorktreeBranch
        isDirty = branch == nil ? nil : context?.agentWorktree?.isDirty
        ticketID = context?.ticketLinks.first?.id
        ticketURL = context?.ticketLinks.first?.url
        projectTitle = provenance?.projectLinks.first.map { $0.title ?? $0.id }
        projectURL = provenance?.projectLinks.first?.url
        summary = titlePresentation.description
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
        let pullRequestOwner = workspace.pullRequest.map { (name: $0.ownerLogin, url: $0.ownerURL) }
            ?? provenance?.pullRequest.map { (name: $0.ownerLogin, url: $0.ownerURL) }
        ownerName = context?.ticketLinks.first?.ownerName ?? pullRequestOwner?.name
        ownerURL = context?.ticketLinks.first?.ownerName != nil
            ? context?.ticketLinks.first?.ownerURL
            : pullRequestOwner?.url
    }
}
