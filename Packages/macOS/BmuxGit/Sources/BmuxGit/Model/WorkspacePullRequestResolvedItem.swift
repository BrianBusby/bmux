import Foundation

/// The pull request a refresh resolved for one panel, reduced to the fields a
/// badge needs.
public struct WorkspacePullRequestResolvedItem: Sendable {
    /// The pull request number.
    public let number: Int
    /// The PR's html URL string.
    public let urlString: String
    /// The PR author's GitHub login, if known.
    public let ownerLogin: String?
    /// The PR author's GitHub profile URL string, if known.
    public let ownerURLString: String?
    /// The ``PullRequestStatus`` raw value (`"open"`/`"merged"`/`"closed"`),
    /// kept as a string so app-side status enums can bridge via `rawValue`.
    public let statusRawValue: String
    /// The branch the PR was matched for.
    public let branch: String

    /// Creates a resolved item.
    public init(
        number: Int,
        urlString: String,
        ownerLogin: String? = nil,
        ownerURLString: String? = nil,
        statusRawValue: String,
        branch: String
    ) {
        self.number = number
        self.urlString = urlString
        self.ownerLogin = ownerLogin
        self.ownerURLString = ownerURLString
        self.statusRawValue = statusRawValue
        self.branch = branch
    }
}
