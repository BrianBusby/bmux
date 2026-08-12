import Foundation

/// Pull-request owner resolver used when no external resolver should run.
struct WorkProvenanceNoopPullRequestOwnerResolver: WorkProvenancePullRequestOwnerResolving {
    func owner(for pullRequestURL: String) async -> WorkProvenancePullRequestOwner? {
        nil
    }
}
