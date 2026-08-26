import Foundation

/// Factual work evidence grouped under one observed coding-agent turn.
public struct ProvenanceFactualSessionProjectionTurnSnapshot: Codable, Equatable, Sendable {
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

    /// Completed visible assistant outputs explicitly linked to this turn.
    public let assistantMessages: [ProvenanceCodingAgentAssistantMessageRecord]

    /// File-change attributions explicitly linked to this turn.
    public let fileChangeAttributions: [ProvenanceCodingAgentFileChangeAttributionRecord]

    private enum CodingKeys: String, CodingKey {
        case turn
        case submittedPrompt
        case currentPlan
        case completedCommands
        case visibleReasoningSummaries
        case assistantMessages
        case fileChangeAttributions
    }

    /// Creates a factual turn projection snapshot.
    public init(
        turn: ProvenanceCodingAgentTurnRecord,
        submittedPrompt: ProvenanceCodingAgentPromptRecord?,
        currentPlan: ProvenanceCodingAgentPlanUpdateRecord?,
        completedCommands: [ProvenanceCodingAgentCommandRecord],
        visibleReasoningSummaries: [ProvenanceCodingAgentReasoningSummaryRecord],
        fileChangeAttributions: [ProvenanceCodingAgentFileChangeAttributionRecord],
        assistantMessages: [ProvenanceCodingAgentAssistantMessageRecord] = []
    ) {
        self.turn = turn
        self.submittedPrompt = submittedPrompt
        self.currentPlan = currentPlan
        self.completedCommands = completedCommands
        self.visibleReasoningSummaries = visibleReasoningSummaries
        self.assistantMessages = assistantMessages
        self.fileChangeAttributions = fileChangeAttributions
    }

    /// Creates a factual turn projection snapshot from stored JSON, preserving compatibility with older snapshots.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.turn = try container.decode(ProvenanceCodingAgentTurnRecord.self, forKey: .turn)
        self.submittedPrompt = try container.decodeIfPresent(
            ProvenanceCodingAgentPromptRecord.self,
            forKey: .submittedPrompt
        )
        self.currentPlan = try container.decodeIfPresent(
            ProvenanceCodingAgentPlanUpdateRecord.self,
            forKey: .currentPlan
        )
        self.completedCommands = try container.decode(
            [ProvenanceCodingAgentCommandRecord].self,
            forKey: .completedCommands
        )
        self.visibleReasoningSummaries = try container.decode(
            [ProvenanceCodingAgentReasoningSummaryRecord].self,
            forKey: .visibleReasoningSummaries
        )
        self.assistantMessages = try container.decodeIfPresent(
            [ProvenanceCodingAgentAssistantMessageRecord].self,
            forKey: .assistantMessages
        ) ?? []
        self.fileChangeAttributions = try container.decode(
            [ProvenanceCodingAgentFileChangeAttributionRecord].self,
            forKey: .fileChangeAttributions
        )
    }
}
