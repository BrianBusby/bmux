import Foundation

/// Deterministic factual projection summarizing the observable outcome of one turn.
public struct ProvenanceTurnOutcome: Codable, Equatable, Sendable {
    /// Schema version for this outcome shape.
    public let schemaVersion: Int

    /// Stable Provenance Engine turn projection identifier.
    public let turnID: String

    /// Provenance session that owns the turn.
    public let sessionID: String

    /// Provider name, such as `codex`.
    public let provider: String

    /// Provider-native turn identifier.
    public let providerTurnID: String

    /// Projection revision and rule metadata.
    public let projection: ProvenanceTurnOutcomeProjectionMetadata

    /// Explicit objective copied from submitted prompt evidence, when observed.
    public let objective: ProvenanceTurnOutcomeTextFact?

    /// Plan items explicitly observed for the turn.
    public let planItems: [ProvenanceTurnOutcomePlanItem]

    /// Actions explicitly marked complete in plan or visible summary evidence.
    public let actionsCompleted: [ProvenanceTurnOutcomeTextFact]

    /// Completed command or tool executions observed for the turn.
    public let commandsCompleted: [ProvenanceTurnOutcomeCommand]

    /// Files or artifact paths explicitly attributed to the turn.
    public let artifactsChanged: [ProvenanceTurnOutcomeArtifact]

    /// Decisions explicitly represented by accepted evidence.
    public let decisions: [ProvenanceTurnOutcomeTextFact]

    /// Validation attempts deterministically recognized from accepted evidence.
    public let validationsAttempted: [ProvenanceTurnOutcomeValidation]

    /// Explicit blockers observed in plan or lifecycle evidence.
    public let blockers: [ProvenanceTurnOutcomeTextFact]

    /// Explicit unresolved plan items or deferred work.
    public let unresolvedItems: [ProvenanceTurnOutcomeTextFact]

    /// Repository, worktree, branch, and commit boundary observed for the turn.
    public let repositoryBoundary: ProvenanceTurnOutcomeRepositoryBoundary?

    /// Recommended resume point copied from explicit unresolved evidence, when available.
    public let resumePoint: ProvenanceTurnOutcomeTextFact?

    /// Raw factual turn lifecycle state.
    public let lifecycleState: String

    /// Normalized factual completion state.
    public let completionState: String

    /// Completeness and availability metadata for optional fields.
    public let completeness: ProvenanceTurnOutcomeCompleteness

    /// Creates a deterministic turn outcome.
    public init(
        schemaVersion: Int = 1,
        turnID: String,
        sessionID: String,
        provider: String,
        providerTurnID: String,
        projection: ProvenanceTurnOutcomeProjectionMetadata,
        objective: ProvenanceTurnOutcomeTextFact? = nil,
        planItems: [ProvenanceTurnOutcomePlanItem] = [],
        actionsCompleted: [ProvenanceTurnOutcomeTextFact] = [],
        commandsCompleted: [ProvenanceTurnOutcomeCommand] = [],
        artifactsChanged: [ProvenanceTurnOutcomeArtifact] = [],
        decisions: [ProvenanceTurnOutcomeTextFact] = [],
        validationsAttempted: [ProvenanceTurnOutcomeValidation] = [],
        blockers: [ProvenanceTurnOutcomeTextFact] = [],
        unresolvedItems: [ProvenanceTurnOutcomeTextFact] = [],
        repositoryBoundary: ProvenanceTurnOutcomeRepositoryBoundary? = nil,
        resumePoint: ProvenanceTurnOutcomeTextFact? = nil,
        lifecycleState: String,
        completionState: String,
        completeness: ProvenanceTurnOutcomeCompleteness
    ) {
        self.schemaVersion = schemaVersion
        self.turnID = turnID
        self.sessionID = sessionID
        self.provider = provider
        self.providerTurnID = providerTurnID
        self.projection = projection
        self.objective = objective
        self.planItems = planItems
        self.actionsCompleted = actionsCompleted
        self.commandsCompleted = commandsCompleted
        self.artifactsChanged = artifactsChanged
        self.decisions = decisions
        self.validationsAttempted = validationsAttempted
        self.blockers = blockers
        self.unresolvedItems = unresolvedItems
        self.repositoryBoundary = repositoryBoundary
        self.resumePoint = resumePoint
        self.lifecycleState = lifecycleState
        self.completionState = completionState
        self.completeness = completeness
    }
}
