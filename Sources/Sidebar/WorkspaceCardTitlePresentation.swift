import Foundation

/// One title policy for the native sidebar and reference workspace cards.
struct WorkspaceCardTitlePresentation: Equatable, Sendable {
    let title: String
    let description: String?
    let usesTicketTitle: Bool

    init(workspaceTitle: String, ticketTitle: String?) {
        let normalizedTicket = ticketTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
        let ticketHeading = normalizedTicket.flatMap { $0.isEmpty ? nil : $0 }
        let heading = ticketHeading ?? workspaceTitle
        let normalizedWorkspace = workspaceTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        title = heading
        usesTicketTitle = ticketHeading != nil
        description = !normalizedWorkspace.isEmpty
            && normalizedWorkspace != heading.trimmingCharacters(in: .whitespacesAndNewlines)
            ? workspaceTitle : nil
    }
}
