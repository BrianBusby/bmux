/// Evidence source that produced a work-item reference fact.
public enum ContextEfficiencyWorkItemReferenceSource: String, Codable, Equatable, Sendable {
    /// Compact Codex state metadata.
    case codexStateMetadata = "codex_state_metadata"
    /// A rollout session/thread metadata event.
    case threadMetadata = "thread_metadata"
    /// A user or assistant message rollout event.
    case message
    /// A tool-call argument or command summary rollout event.
    case toolCall = "tool_call"
    /// A tool-output rollout event.
    case toolOutput = "tool_output"
    /// Another rollout event.
    case rolloutEvent = "rollout_event"
}
