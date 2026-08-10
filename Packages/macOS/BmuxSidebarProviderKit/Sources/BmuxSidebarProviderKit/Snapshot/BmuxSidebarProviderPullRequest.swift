import Foundation

/// Pull-request metadata exposed to in-process sidebar providers.
public struct BmuxSidebarProviderPullRequest: Codable, Equatable, Sendable {
    /// Pull-request number.
    public var number: Int
    /// Display label for the pull request.
    public var label: String
    /// Pull-request URL string.
    public var url: String
    /// Pull-request lifecycle status.
    public var status: String
    /// GitHub login of the PR author, when known.
    public var ownerLogin: String?
    /// GitHub profile URL of the PR author, when known.
    public var ownerURL: String?
    /// Branch associated with the pull request, when known.
    public var branch: String?
    /// Whether the pull-request metadata may be stale.
    public var isStale: Bool

    /// Creates pull-request metadata for a sidebar provider snapshot.
    /// - Parameters:
    ///   - number: Pull-request number.
    ///   - label: Display label for the pull request.
    ///   - url: Pull-request URL string.
    ///   - status: Pull-request lifecycle status.
    ///   - ownerLogin: GitHub login of the PR author, when known.
    ///   - ownerURL: GitHub profile URL of the PR author, when known.
    ///   - branch: Branch associated with the pull request, when known.
    ///   - isStale: Whether the pull-request metadata may be stale.
    public init(
        number: Int,
        label: String,
        url: String,
        status: String,
        ownerLogin: String? = nil,
        ownerURL: String? = nil,
        branch: String? = nil,
        isStale: Bool = false
    ) {
        self.number = number
        self.label = label
        self.url = url
        self.status = status
        self.ownerLogin = ownerLogin
        self.ownerURL = ownerURL
        self.branch = branch
        self.isStale = isStale
    }
}
