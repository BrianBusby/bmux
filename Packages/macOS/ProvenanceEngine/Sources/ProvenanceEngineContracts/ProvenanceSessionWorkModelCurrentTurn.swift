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

    /// Completed visible assistant outputs for this turn.
    public let assistantMessages: [ProvenanceCodingAgentAssistantMessageRecord]

    /// File-change attribution facts for this turn.
    public let fileChangeAttributions: [ProvenanceCodingAgentFileChangeAttributionRecord]

    /// PE-owned semantic turn intent.
    public let intent: ProvenanceSessionWorkModelSemanticField

    /// PE-owned semantic current activity.
    public let currentActivity: ProvenanceSessionWorkModelSemanticField

    private enum CodingKeys: String, CodingKey {
        case turn
        case prompt
        case plan
        case completedCommands
        case visibleReasoningSummaries
        case assistantMessages
        case fileChangeAttributions
        case intent
        case currentActivity
    }

    /// Creates a current turn section.
    ///
    /// - Parameters:
    ///   - turn: Observed turn lifecycle and identity.
    ///   - prompt: Latest submitted prompt evidence for this turn.
    ///   - plan: Latest plan evidence for this turn.
    ///   - completedCommands: Completed command facts for this turn.
    ///   - visibleReasoningSummaries: Visible reasoning summaries for this turn.
    ///   - assistantMessages: Completed visible assistant outputs for this turn.
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
        currentActivity: ProvenanceSessionWorkModelSemanticField,
        assistantMessages: [ProvenanceCodingAgentAssistantMessageRecord] = []
    ) {
        self.turn = turn
        self.prompt = prompt
        self.plan = plan
        self.completedCommands = completedCommands
        self.visibleReasoningSummaries = visibleReasoningSummaries
        self.assistantMessages = assistantMessages
        self.fileChangeAttributions = fileChangeAttributions
        self.intent = intent
        self.currentActivity = currentActivity
    }

    /// Creates a current turn section from stored JSON, preserving compatibility with older model snapshots.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.turn = try container.decode(ProvenanceCodingAgentTurnRecord.self, forKey: .turn)
        self.prompt = try container.decodeIfPresent(ProvenanceCodingAgentPromptRecord.self, forKey: .prompt)
        self.plan = try container.decodeIfPresent(ProvenanceCodingAgentPlanUpdateRecord.self, forKey: .plan)
        self.completedCommands = try container.decode([ProvenanceCodingAgentCommandRecord].self, forKey: .completedCommands)
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
        self.intent = try container.decode(ProvenanceSessionWorkModelSemanticField.self, forKey: .intent)
        self.currentActivity = try container.decode(
            ProvenanceSessionWorkModelSemanticField.self,
            forKey: .currentActivity
        )
    }
}
