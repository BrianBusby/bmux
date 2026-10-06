import Foundation

/// One title policy for the native sidebar and reference workspace cards.
struct WorkspaceCardTitlePresentation: Equatable, Sendable {
    let title: String
    let description: String?

    init(workspaceTitle: String, ticketTitle: String?) {
        let normalizedTicket = ticketTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
        let heading = normalizedTicket.flatMap { $0.isEmpty ? nil : $0 } ?? workspaceTitle
        let normalizedWorkspace = workspaceTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        title = heading
        description = !normalizedWorkspace.isEmpty
            && normalizedWorkspace != heading.trimmingCharacters(in: .whitespacesAndNewlines)
            ? workspaceTitle : nil
    }
}
