import Foundation

/// Stable origin identifier for the system that produced an evidence event.
///
/// This is distinct from ``ProvenanceSource``, which describes whether a claim
/// was observed, declared, inferred, reconciled, or unattributed.
public struct ProvenanceEvidenceOrigin: Codable, Equatable, Hashable, Sendable, RawRepresentable, ExpressibleByStringLiteral {
    /// Raw origin value.
    public let rawValue: String

    /// Creates an evidence origin from a stable raw value.
    ///
    /// - Parameter rawValue: Stable origin name.
    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    /// Creates an evidence origin from a string literal.
    ///
    /// - Parameter value: Stable origin name.
    public init(stringLiteral value: String) {
        self.rawValue = value
    }

    /// Evidence captured from a Codex session.
    public static let codexSession = Self(rawValue: "codex-session")

    /// Evidence captured from Git commit history.
    public static let git = Self(rawValue: "git")

    /// Evidence captured from GitHub pull request metadata or bodies.
    public static let githubPullRequest = Self(rawValue: "github-pull-request")

    /// Evidence captured from submitted GitHub reviews.
    public static let githubReview = Self(rawValue: "github-review")

    /// Evidence captured from GitHub review comments or review threads.
    public static let githubReviewComment = Self(rawValue: "github-review-comment")

    /// Evidence captured from GitHub review thread metadata.
    public static let githubReviewThread = Self(rawValue: "github-review-thread")

    /// Evidence captured from terminal activity.
    public static let terminal = Self(rawValue: "terminal")

    /// Evidence captured from documents or notes.
    public static let document = Self(rawValue: "document")

    /// Evidence produced by a compiler or derivation pass.
    public static let derived = Self(rawValue: "derived")
}
