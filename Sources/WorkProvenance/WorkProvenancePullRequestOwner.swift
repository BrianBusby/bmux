import Foundation

/// Pull-request metadata resolved for workspace display observation.
struct WorkProvenancePullRequestOwner: Equatable, Sendable {
    let login: String
    let url: String?
    let title: String?
    let branch: String?

    init(
        login: String,
        url: String?,
        title: String? = nil,
        branch: String? = nil
    ) {
        self.login = login
        self.url = url
        self.title = title
        self.branch = branch
    }
}
