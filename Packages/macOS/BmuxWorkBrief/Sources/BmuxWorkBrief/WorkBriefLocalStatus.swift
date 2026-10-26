/// Verified local activity, independent of generated prose.
public enum WorkBriefLocalStatus: Int, Equatable, Sendable {
    /// An observed request for user input.
    case needsInput
    /// An observed local error.
    case error
    /// An active local process or agent.
    case running
    /// An open workspace without active work.
    case idle
    /// Local activity could not be verified.
    case disconnected
}
