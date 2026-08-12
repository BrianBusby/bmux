import Foundation

/// Pull-request owner metadata resolved for workspace display observation.
struct WorkProvenancePullRequestOwner: Equatable, Sendable {
    let login: String
    let url: String?
    let headBranch: String?

    init(login: String, url: String?, headBranch: String? = nil) {
        self.login = login
        self.url = url
        self.headBranch = headBranch
    }
}
