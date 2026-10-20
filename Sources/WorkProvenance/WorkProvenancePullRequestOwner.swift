import Foundation

/// Pull-request metadata resolved for workspace display observation.
struct WorkProvenancePullRequestOwner: Equatable, Sendable {
    let login: String
    let url: String?
    let avatarURL: String?
    let title: String?
    let branch: String?

    init(
        login: String,
        url: String?,
        avatarURL: String? = nil,
        title: String? = nil,
        branch: String? = nil
    ) {
        self.login = login
        self.url = url
        self.avatarURL = avatarURL
        self.title = title
        self.branch = branch
    }
}
