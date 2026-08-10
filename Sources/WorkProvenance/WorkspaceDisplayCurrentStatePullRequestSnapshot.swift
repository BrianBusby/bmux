import Foundation
import BmuxFoundation
import ProvenanceEngineContracts

/// PE-owned pull request facts for a workspace display snapshot.
struct WorkspaceDisplayCurrentStatePullRequestSnapshot: Equatable, Sendable {
    let number: Int
    let url: URL?
    let status: String?
    let branch: String?
    let isStale: Bool

    init?(_ display: ProvenanceWorkspaceDisplayRecord) {
        guard let number = display.pullRequestNumber else { return nil }
        self.number = number
        self.url = display.pullRequestURL.flatMap(URL.init(string:))
        self.status = display.pullRequestStatus?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        self.branch = display.pullRequestBranch?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        self.isStale = display.pullRequestIsStale
    }
}
