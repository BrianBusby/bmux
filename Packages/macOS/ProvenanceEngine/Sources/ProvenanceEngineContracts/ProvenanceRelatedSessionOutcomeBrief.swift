import Foundation

/// Compact factual outcome brief derived from one Session Outcome revision.
public struct ProvenanceRelatedSessionOutcomeBrief: Codable, Equatable, Sendable {
    /// Objective facts copied from Session Outcome.
    public let objectives: [ProvenanceSessionOutcomeTextFact]

    /// Plan item facts copied from Session Outcome.
    public let planItems: [ProvenanceSessionOutcomePlanItem]

    /// Completed action facts copied from Session Outcome.
    public let actionsCompleted: [ProvenanceSessionOutcomeTextFact]

    /// Completed command facts copied from Session Outcome.
    public let commandsCompleted: [ProvenanceSessionOutcomeCommand]

    /// Changed artifact facts copied from Session Outcome.
    public let changedArtifacts: [ProvenanceSessionOutcomeArtifact]

    /// Validation facts copied from Session Outcome.
    public let validationsAttempted: [ProvenanceSessionOutcomeValidation]

    /// Blocker facts copied from Session Outcome.
    public let blockers: [ProvenanceSessionOutcomeTextFact]

    /// Unresolved item facts copied from Session Outcome.
    public let unresolvedItems: [ProvenanceSessionOutcomeTextFact]

    /// Latest resume point copied from Session Outcome, when present.
    public let latestResumePoint: ProvenanceSessionOutcomeTextFact?

    /// Field names truncated to keep this brief bounded.
    public let truncatedFields: [String]

    /// Creates a compact related-session outcome brief.
    public init(
        objectives: [ProvenanceSessionOutcomeTextFact],
        planItems: [ProvenanceSessionOutcomePlanItem],
        actionsCompleted: [ProvenanceSessionOutcomeTextFact],
        commandsCompleted: [ProvenanceSessionOutcomeCommand],
        changedArtifacts: [ProvenanceSessionOutcomeArtifact],
        validationsAttempted: [ProvenanceSessionOutcomeValidation],
        blockers: [ProvenanceSessionOutcomeTextFact],
        unresolvedItems: [ProvenanceSessionOutcomeTextFact],
        latestResumePoint: ProvenanceSessionOutcomeTextFact?,
        truncatedFields: [String]
    ) {
        self.objectives = objectives
        self.planItems = planItems
        self.actionsCompleted = actionsCompleted
        self.commandsCompleted = commandsCompleted
        self.changedArtifacts = changedArtifacts
        self.validationsAttempted = validationsAttempted
        self.blockers = blockers
        self.unresolvedItems = unresolvedItems
        self.latestResumePoint = latestResumePoint
        self.truncatedFields = truncatedFields
    }
}
