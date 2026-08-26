import Foundation

/// A stable semantic event type stored in the provenance ledger.
///
/// The type is a string-backed value instead of a closed enum so clients can
/// preserve newer event names even when an older SDK only understands the core V1 set.
public struct ProvenanceEventType: Codable, Equatable, Hashable, Sendable, RawRepresentable, ExpressibleByStringLiteral {
    /// The raw event type value.
    public let rawValue: String

    /// Creates an event type from a raw value.
    ///
    /// - Parameter rawValue: Stable event type name.
    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    /// Creates an event type from a string literal.
    ///
    /// - Parameter value: Stable event type name.
    public init(stringLiteral value: String) {
        self.rawValue = value
    }

    /// A client proposed a work-item assignment.
    public static let workItemProposed = Self(rawValue: "work_item_proposed")

    /// An agent confirmed or corrected a work-item assignment.
    public static let workItemConfirmed = Self(rawValue: "work_item_confirmed")

    /// A session began contributing to a work item.
    public static let contributionStarted = Self(rawValue: "contribution_started")

    /// A contribution recorded a progress checkpoint.
    public static let progressCheckpoint = Self(rawValue: "progress_checkpoint")

    /// A client detected likely overlap or conflict.
    public static let conflictDetected = Self(rawValue: "conflict_detected")

    /// Sessions recorded an advisory coordination agreement.
    public static let coordinationAgreement = Self(rawValue: "coordination_agreement")

    /// A session closed its contribution.
    public static let contributionCompleted = Self(rawValue: "contribution_completed")

    /// A client observed repository metadata.
    public static let repositoryObserved = Self(rawValue: "repository_observed")

    /// A client observed worktree metadata.
    public static let worktreeObserved = Self(rawValue: "worktree_observed")

    /// A client observed workspace display metadata.
    public static let workspaceDisplayObserved = Self(rawValue: "workspace_display_observed")

    /// A client observed session metadata.
    public static let sessionObserved = Self(rawValue: "session_observed")

    /// A client observed a coding-agent provider thread identity.
    public static let codingAgentThreadObserved = Self(rawValue: "coding_agent_thread_observed")

    /// A client observed a coding-agent provider turn lifecycle fact.
    public static let codingAgentTurnObserved = Self(rawValue: "coding_agent_turn_observed")

    /// A client observed submitted input for a coding-agent turn.
    public static let codingAgentPromptSubmitted = Self(rawValue: "coding_agent_prompt_submitted")

    /// A client observed a provider-emitted coding-agent plan update.
    public static let codingAgentPlanUpdated = Self(rawValue: "coding_agent_plan_updated")

    /// A client observed completion of a coding-agent command execution.
    public static let codingAgentCommandCompleted = Self(rawValue: "coding_agent_command_completed")

    /// A client observed a provider-supported visible reasoning summary.
    public static let codingAgentReasoningSummaryCompleted = Self(rawValue: "coding_agent_reasoning_summary_completed")

    /// A client observed provider-emitted visible assistant output.
    public static let codingAgentAssistantMessageCompleted = Self(rawValue: "coding_agent_assistant_message_completed")

    /// A client observed file-change activity attributed to a coding-agent turn.
    public static let codingAgentFileChangeAttributed = Self(rawValue: "coding_agent_file_change_attributed")

    /// A producer observed a session start.
    public static let sessionStarted = Self(rawValue: "session_started")

    /// A producer observed a session stop.
    public static let sessionStopped = Self(rawValue: "session_stopped")

    /// A client observed a child session start.
    @available(*, deprecated, renamed: "sessionStarted")
    public static let subsessionStarted = Self(rawValue: "subsession_started")

    /// A client observed a child session stop.
    @available(*, deprecated, renamed: "sessionStopped")
    public static let subsessionStopped = Self(rawValue: "subsession_stopped")
}
