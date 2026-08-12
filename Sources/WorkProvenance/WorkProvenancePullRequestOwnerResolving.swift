import Foundation

/// Resolves pull-request owner metadata for workspace display observation.
protocol WorkProvenancePullRequestOwnerResolving: Sendable {
    func owner(for pullRequestURL: String) async -> WorkProvenancePullRequestOwner?
}
