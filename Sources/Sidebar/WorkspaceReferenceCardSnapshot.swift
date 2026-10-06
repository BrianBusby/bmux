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
    init(workspace: Workspace, provenance: WorkspaceDisplayCurrentStateSnapshot?) {
        id = workspace.id
        title = provenance?.ticketLinks.first?.title ?? provenance?.title ?? workspace.title
        prompt = provenance?.lastSubmittedPrompt ?? workspace.latestSubmittedMessage
        branch = provenance?.branch ?? workspace.presentedGitBranch?.branch
        isDirty = provenance?.isDirty ?? workspace.presentedGitBranch?.isDirty
        ticketID = provenance?.ticketLinks.first?.id ?? workspace.sidebarMetadata.workContext.ticket?.key
        ticketURL = provenance?.ticketLinks.first?.url ?? workspace.sidebarMetadata.workContext.ticket?.url
        projectTitle = provenance?.projectLinks.first.map { $0.title ?? $0.id }
        projectURL = provenance?.projectLinks.first?.url
        summary = (provenance?.currentWorkSummary ?? workspace.customDescription)?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
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
        ownerName = provenance?.ticketLinks.first?.ownerName ?? pullRequestOwner?.name
        ownerURL = provenance?.ticketLinks.first?.ownerName != nil
            ? provenance?.ticketLinks.first?.ownerURL
            : pullRequestOwner?.url
    }
}
