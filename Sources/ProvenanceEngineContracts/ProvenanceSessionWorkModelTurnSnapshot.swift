import Foundation

/// Factual work evidence grouped under one observed coding-agent turn.
public struct ProvenanceSessionWorkModelTurnSnapshot: Codable, Equatable, Sendable {
    /// Observed provider turn lifecycle projection.
    public let turn: ProvenanceCodingAgentTurnRecord

    /// Latest submitted prompt explicitly linked to this turn, when observed.
    public let submittedPrompt: ProvenanceCodingAgentPromptRecord?

    /// Latest provider plan update explicitly linked to this turn, when observed.
    public let currentPlan: ProvenanceCodingAgentPlanUpdateRecord?

    /// Completed command facts explicitly linked to this turn.
    public let completedCommands: [ProvenanceCodingAgentCommandRecord]

    /// Completed visible reasoning summaries explicitly linked to this turn.
    public let visibleReasoningSummaries: [ProvenanceCodingAgentReasoningSummaryRecord]

    /// File-change attributions explicitly linked to this turn.
    public let fileChangeAttributions: [ProvenanceCodingAgentFileChangeAttributionRecord]

    /// Creates a factual turn work snapshot.
    public init(
        turn: ProvenanceCodingAgentTurnRecord,
        submittedPrompt: ProvenanceCodingAgentPromptRecord?,
        currentPlan: ProvenanceCodingAgentPlanUpdateRecord?,
        completedCommands: [ProvenanceCodingAgentCommandRecord],
        visibleReasoningSummaries: [ProvenanceCodingAgentReasoningSummaryRecord],
        fileChangeAttributions: [ProvenanceCodingAgentFileChangeAttributionRecord]
    ) {
        self.turn = turn
        self.submittedPrompt = submittedPrompt
        self.currentPlan = currentPlan
        self.completedCommands = completedCommands
        self.visibleReasoningSummaries = visibleReasoningSummaries
        self.fileChangeAttributions = fileChangeAttributions
    }
}
