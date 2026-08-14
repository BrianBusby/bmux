import Foundation
import BmuxFoundation
import ProvenanceEngineContracts

/// PE-owned ticket facts for a workspace display snapshot.
struct WorkspaceDisplayCurrentStateTicketLinkSnapshot: Equatable, Sendable, Identifiable {
    let id: String
    let system: String?
    let title: String?
    let url: URL?
    let ownerName: String?
    let ownerURL: URL?

    init?(_ link: ProvenanceWorkspaceDisplayTicketLinkRecord) {
        let trimmedID = link.id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedID.isEmpty else { return nil }
        self.id = trimmedID
        self.system = link.system?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        self.title = link.title?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        self.url = link.url.flatMap(URL.init(string:)) ?? Self.linearURL(for: trimmedID)
        self.ownerName = link.ownerName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        let ownerURL = link.ownerURL?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        self.ownerURL = ownerURL.flatMap(URL.init(string:))
    }

    init(id: String) {
        self.id = id
        self.system = Self.linearURL(for: id) == nil ? nil : "linear"
        self.title = nil
        self.url = Self.linearURL(for: id)
        self.ownerName = nil
        self.ownerURL = nil
    }

    static func links(
        ticketIDs: [String],
        ticketLinks: [ProvenanceWorkspaceDisplayTicketLinkRecord]
    ) -> [WorkspaceDisplayCurrentStateTicketLinkSnapshot] {
        var seen = Set<String>()
        var snapshots: [WorkspaceDisplayCurrentStateTicketLinkSnapshot] = []
        for link in ticketLinks {
            guard let snapshot = WorkspaceDisplayCurrentStateTicketLinkSnapshot(link),
                  seen.insert(snapshot.id).inserted else {
                continue
            }
            snapshots.append(snapshot)
        }
        for ticketID in ticketIDs {
            let trimmedID = ticketID.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedID.isEmpty, seen.insert(trimmedID).inserted else { continue }
            snapshots.append(WorkspaceDisplayCurrentStateTicketLinkSnapshot(id: trimmedID))
        }
        return snapshots
    }

    private static func linearURL(for ticketID: String) -> URL? {
        LinearWebLinkBuilder().issueURL(for: ticketID)
    }
}
