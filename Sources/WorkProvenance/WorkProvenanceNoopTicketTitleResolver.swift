import Foundation

/// Ticket-title resolver used when no external ticket source should run.
struct WorkProvenanceNoopTicketTitleResolver: WorkProvenanceTicketTitleResolving {
    func titles(for ticketIDs: [String]) async -> [String: String] {
        [:]
    }
}
