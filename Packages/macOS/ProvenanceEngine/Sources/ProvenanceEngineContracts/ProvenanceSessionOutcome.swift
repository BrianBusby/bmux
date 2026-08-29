import Foundation

/// Deterministic factual projection summarizing the accepted outcomes for one coding-agent session.
public struct ProvenanceSessionOutcome: Codable, Equatable, Sendable {
    /// Schema version for this outcome shape.
    public let schemaVersion: Int

    /// Stable Provenance Engine session projection identifier.
    public let sessionID: String

    /// Current factual session record that owns the aggregated turns.
    public let session: ProvenanceSessionRecord

    /// External provider identities attached to the session, when observed.
    public let externalIdentities: [ProvenanceExternalIdentityRecord]

    /// Provider thread identities observed for the session.
    public let providerThreadIdentities: [ProvenanceFactualSessionProjectionProviderThreadIdentity]

    /// Projection revision and rule metadata.
    public let projection: ProvenanceSessionOutcomeProjectionMetadata

    /// Ordered turn outcome revisions included in this session outcome.
    public let constituentTurns: [ProvenanceSessionOutcomeTurnReference]

    /// Exact turn outcome objects used by this revision.
    public let turnOutcomes: [ProvenanceTurnOutcome]

    /// Explicit objectives observed across the session in turn order.
    public let objectives: [ProvenanceSessionOutcomeTextFact]

    /// Latest factual state for plan items reconciled across turns.
    public let planItems: [ProvenanceSessionOutcomePlanItem]

    /// Actions explicitly completed across the session in turn order.
    public let actionsCompleted: [ProvenanceSessionOutcomeTextFact]

    /// Completed command or tool executions observed across the session.
    public let commandsCompleted: [ProvenanceSessionOutcomeCommand]

    /// Changed artifact facts observed across the session.
    public let changedArtifacts: [ProvenanceSessionOutcomeArtifact]

    /// Decisions explicitly represented by accepted evidence.
    public let decisions: [ProvenanceSessionOutcomeTextFact]

    /// Validation attempts deterministically recognized from accepted evidence.
    public let validationsAttempted: [ProvenanceSessionOutcomeValidation]

    /// Explicit blockers observed across the session.
    public let blockers: [ProvenanceSessionOutcomeTextFact]

    /// Explicit unresolved plan items or deferred work.
    public let unresolvedItems: [ProvenanceSessionOutcomeTextFact]

    /// Repository, worktree, branch, and commit boundaries observed across included turns.
    public let repositoryBoundaries: [ProvenanceSessionOutcomeRepositoryBoundary]

    /// Explicit resume points observed across the session.
    public let resumePoints: [ProvenanceSessionOutcomeTextFact]

    /// Latest explicit resume point in turn order, when available.
    public let latestResumePoint: ProvenanceSessionOutcomeTextFact?

    /// Raw factual session lifecycle state.
    public let lifecycleState: String

    /// Normalized factual session completion state.
    public let completionState: String

    /// Completeness and availability metadata for optional fields.
    public let completeness: ProvenanceSessionOutcomeCompleteness

    /// Creates a deterministic session outcome.
    public init(
        schemaVersion: Int = 1,
        sessionID: String,
        session: ProvenanceSessionRecord,
        externalIdentities: [ProvenanceExternalIdentityRecord] = [],
        providerThreadIdentities: [ProvenanceFactualSessionProjectionProviderThreadIdentity] = [],
        projection: ProvenanceSessionOutcomeProjectionMetadata,
        constituentTurns: [ProvenanceSessionOutcomeTurnReference] = [],
        turnOutcomes: [ProvenanceTurnOutcome] = [],
        objectives: [ProvenanceSessionOutcomeTextFact] = [],
        planItems: [ProvenanceSessionOutcomePlanItem] = [],
        actionsCompleted: [ProvenanceSessionOutcomeTextFact] = [],
        commandsCompleted: [ProvenanceSessionOutcomeCommand] = [],
        changedArtifacts: [ProvenanceSessionOutcomeArtifact] = [],
        decisions: [ProvenanceSessionOutcomeTextFact] = [],
        validationsAttempted: [ProvenanceSessionOutcomeValidation] = [],
        blockers: [ProvenanceSessionOutcomeTextFact] = [],
        unresolvedItems: [ProvenanceSessionOutcomeTextFact] = [],
        repositoryBoundaries: [ProvenanceSessionOutcomeRepositoryBoundary] = [],
        resumePoints: [ProvenanceSessionOutcomeTextFact] = [],
        latestResumePoint: ProvenanceSessionOutcomeTextFact? = nil,
        lifecycleState: String,
        completionState: String,
        completeness: ProvenanceSessionOutcomeCompleteness
    ) {
        self.schemaVersion = schemaVersion
        self.sessionID = sessionID
        self.session = session
        self.externalIdentities = externalIdentities
        self.providerThreadIdentities = providerThreadIdentities
        self.projection = projection
        self.constituentTurns = constituentTurns
        self.turnOutcomes = turnOutcomes
        self.objectives = objectives
        self.planItems = planItems
        self.actionsCompleted = actionsCompleted
        self.commandsCompleted = commandsCompleted
        self.changedArtifacts = changedArtifacts
        self.decisions = decisions
        self.validationsAttempted = validationsAttempted
        self.blockers = blockers
        self.unresolvedItems = unresolvedItems
        self.repositoryBoundaries = repositoryBoundaries
        self.resumePoints = resumePoints
        self.latestResumePoint = latestResumePoint
        self.lifecycleState = lifecycleState
        self.completionState = completionState
        self.completeness = completeness
    }
}
