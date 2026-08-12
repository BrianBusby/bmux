import Foundation

/// Pull-request owner metadata resolved for workspace display observation.
struct WorkProvenancePullRequestOwner: Equatable, Sendable {
    let login: String
    let url: String?
}
