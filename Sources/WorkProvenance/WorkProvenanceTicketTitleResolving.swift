import Foundation

/// Resolves human-readable titles for ticket identifiers used in workspace display facts.
protocol WorkProvenanceTicketTitleResolving: Sendable {
    func titles(for ticketIDs: [String]) async -> [String: String]
}
