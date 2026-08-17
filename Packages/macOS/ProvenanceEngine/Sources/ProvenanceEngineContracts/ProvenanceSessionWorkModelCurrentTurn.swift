import Foundation

/// Current/latest turn section for the model.
public struct ProvenanceSessionWorkModelCurrentTurn: Codable, Equatable, Sendable {
    /// Observed turn lifecycle and identity.
    public let turn: ProvenanceCodingAgentTurnRecord

    /// Latest submitted prompt evidence for this turn.
    public let prompt: ProvenanceCodingAgentPromptRecord?

    /// Latest plan evidence for this turn.
    public let plan: ProvenanceCodingAgentPlanUpdateRecord?

    /// Completed command facts for this turn.
    public let completedCommands: [ProvenanceCodingAgentCommandRecord]

    /// Visible reasoning summaries for this turn.
    public let visibleReasoningSummaries: [ProvenanceCodingAgentReasoningSummaryRecord]

    /// File-change attribution facts for this turn.
    public let fileChangeAttributions: [ProvenanceCodingAgentFileChangeAttributionRecord]

    /// PE-owned semantic turn intent.
    public let intent: ProvenanceSessionWorkModelSemanticField

    /// PE-owned semantic current activity.
    public let currentActivity: ProvenanceSessionWorkModelSemanticField

    /// Creates a current turn section.
    ///
    /// - Parameters:
    ///   - turn: Observed turn lifecycle and identity.
    ///   - prompt: Latest submitted prompt evidence for this turn.
    ///   - plan: Latest plan evidence for this turn.
    ///   - completedCommands: Completed command facts for this turn.
    ///   - visibleReasoningSummaries: Visible reasoning summaries for this turn.
    ///   - fileChangeAttributions: File-change attribution facts for this turn.
    ///   - intent: PE-owned semantic turn intent.
    ///   - currentActivity: PE-owned semantic current activity.
    public init(
        turn: ProvenanceCodingAgentTurnRecord,
        prompt: ProvenanceCodingAgentPromptRecord?,
        plan: ProvenanceCodingAgentPlanUpdateRecord?,
        completedCommands: [ProvenanceCodingAgentCommandRecord],
        visibleReasoningSummaries: [ProvenanceCodingAgentReasoningSummaryRecord],
        fileChangeAttributions: [ProvenanceCodingAgentFileChangeAttributionRecord],
        intent: ProvenanceSessionWorkModelSemanticField,
        currentActivity: ProvenanceSessionWorkModelSemanticField
    ) {
        self.turn = turn
        self.prompt = prompt
        self.plan = plan
        self.completedCommands = completedCommands
        self.visibleReasoningSummaries = visibleReasoningSummaries
        self.fileChangeAttributions = fileChangeAttributions
        self.intent = intent
        self.currentActivity = currentActivity
    }
}
