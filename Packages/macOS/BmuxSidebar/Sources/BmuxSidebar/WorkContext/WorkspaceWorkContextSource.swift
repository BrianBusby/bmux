/// The source that produced a piece of workspace work context.
public enum WorkspaceWorkContextSource: String, Equatable, Sendable {
    /// The value was projected from existing sidebar metadata.
    case sidebarMetadata

    /// The value was parsed from a submitted prompt or conversation message.
    case promptMention

    /// The value was reported by git branch observation.
    case gitBranchReport

    /// The value was parsed from a branch name.
    case branchName

    /// The value was returned by pull-request lookup for a branch.
    case pullRequestLookup

    /// The value was supplied by an explicit user action.
    case manual

    /// The source is not known.
    case unknown
}
