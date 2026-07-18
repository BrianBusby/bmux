/// Kind of work-item or provenance reference detected from imported evidence.
public enum ContextEfficiencyWorkItemReferenceKind: String, Codable, Equatable, Sendable {
    /// A GitHub pull request reference.
    case pullRequest = "pull_request"
    /// A GitHub issue reference.
    case issue
    /// A tracker-style ticket key such as `STE-1964`.
    case ticket
    /// A git branch reference.
    case branch
    /// A GitHub repository reference.
    case repository
}
