import Foundation

/// Identifies a capability that a Provenance Engine endpoint or in-process client supports.
///
/// Capabilities are advertised through ``ProvenanceEngineHealth`` so clients can
/// detect which authoritative operations are available before calling them.
public enum ProvenanceEngineCapability: String, Codable, Equatable, Sendable, CaseIterable {
    /// Appends an authoritative provenance event.
    case appendEvent = "append_event"

    /// Records a normalized session lifecycle transition.
    case recordSessionLifecycle = "record_session_lifecycle"

    /// Records a normalized subsession lifecycle transition.
    @available(*, deprecated, renamed: "recordSessionLifecycle")
    case recordSubsessionLifecycle = "record_subsession_lifecycle"

    /// Queries a bounded session relationship tree.
    case querySessionTree = "query_session_tree"

    /// Queries bounded provenance context for a file path.
    case queryFileExplanation = "query_file_explanation"

    /// Queries registered worktrees.
    case queryWorktrees = "query_worktrees"

    /// Queries the current bounded provenance context for a worktree.
    case queryCurrentContext = "query_current_context"

    /// Queries current display metadata for a workspace.
    case queryWorkspaceDisplay = "query_workspace_display"

    /// Queries the factual session projection snapshot for a coding-agent session.
    case queryFactualSessionProjection = "query_factual_session_projection"

    /// Queries factual detail for one observed coding-agent turn.
    case queryFactualSessionTurnDetail = "query_factual_session_turn_detail"

    /// All currently advertised engine capabilities.
    public static let allCases: [ProvenanceEngineCapability] = [
        .appendEvent,
        .recordSessionLifecycle,
        .querySessionTree,
        .queryFileExplanation,
        .queryWorktrees,
        .queryCurrentContext,
        .queryWorkspaceDisplay,
        .queryFactualSessionProjection,
        .queryFactualSessionTurnDetail,
    ]
}
