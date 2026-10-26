/// Verified local activity, independent of generated prose.
public enum WorkBriefLocalStatus: Int, Equatable, Sendable {
    case needsInput, error, running, idle, disconnected
}
