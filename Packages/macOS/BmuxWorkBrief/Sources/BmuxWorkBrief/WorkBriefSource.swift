/// The owner of a fact shown in Work Brief.
public enum WorkBriefSource: String, Equatable, Sendable {
    /// Local bmux workspace state.
    case bmux
    /// Accepted Provenance Engine facts.
    case provenanceEngine
    /// Linear work items.
    case linear
    /// GitHub pull requests and repositories.
    case github
    /// Explicitly selected Slack content.
    case slack
}
