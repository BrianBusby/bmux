public import Foundation
public import BmuxGit

/// A panel's pull-request badge as the sidebar shows it: PR number, label,
/// link, status, originating branch, and whether the data has gone stale
/// (repeated transient refresh failures).
///
/// This is the package's wire value for the seam: the host maps it to and
/// from its own sidebar state type. `status` reuses ``BmuxGit/PullRequestStatus``
/// (raw values are shared with the app's sidebar status enum).
public struct SidebarPullRequestBadge: Equatable, Sendable {
    /// The pull request number.
    public let number: Int
    /// The short badge label (currently always "PR").
    public let label: String
    /// Link to the pull request page.
    public let url: URL
    /// The PR author's GitHub login, if known.
    public let ownerLogin: String?
    /// The PR author's GitHub profile URL, if known.
    public let ownerURL: URL?
    /// Open/merged/closed state.
    public let status: PullRequestStatus
    /// The branch the badge was resolved for, when known.
    public let branch: String?
    /// Whether the badge is showing data that repeated transient refresh
    /// failures could not confirm.
    public let isStale: Bool

    /// Creates a badge value.
    public init(
        number: Int,
        label: String,
        url: URL,
        ownerLogin: String? = nil,
        ownerURL: URL? = nil,
        status: PullRequestStatus,
        branch: String? = nil,
        isStale: Bool = false
    ) {
        self.number = number
        self.label = label
        self.url = url
        let normalizedOwnerLogin = ownerLogin?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.ownerLogin = normalizedOwnerLogin.isEmpty ? nil : normalizedOwnerLogin
        self.ownerURL = ownerURL
        self.status = status
        self.branch = branch
        self.isStale = isStale
    }
}
