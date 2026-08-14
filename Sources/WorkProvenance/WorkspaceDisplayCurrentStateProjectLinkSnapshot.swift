import Foundation
import BmuxFoundation
import ProvenanceEngineContracts

/// PE-owned project facts for a workspace display snapshot.
struct WorkspaceDisplayCurrentStateProjectLinkSnapshot: Equatable, Sendable, Identifiable {
    let id: String
    let system: String?
    let title: String?
    let url: URL?

    init?(_ link: ProvenanceWorkspaceDisplayProjectLinkRecord) {
        let trimmedID = link.id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedID.isEmpty else { return nil }
        self.id = trimmedID
        self.system = link.system?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        self.title = link.title?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        let trimmedURL = link.url?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        self.url = trimmedURL.flatMap(URL.init(string:)) ?? Self.linearURL(forProjectSlug: trimmedID)
    }

    private static func linearURL(forProjectSlug projectSlug: String) -> URL? {
        LinearWebLinkBuilder().projectURL(forProjectSlug: projectSlug)
    }
}
