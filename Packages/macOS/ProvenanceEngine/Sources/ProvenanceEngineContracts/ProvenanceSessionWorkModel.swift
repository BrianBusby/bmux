import Foundation

/// PE-owned factual plus semantic understanding snapshot for one coding-agent session.
public struct ProvenanceSessionWorkModel: Codable, Equatable, Sendable {
    /// Schema version for this model shape.
    public let schemaVersion: Int

    /// Revision components that let consumers reconcile newer materializations.
    public let revision: ProvenanceSessionWorkModelRevision

    /// Session identity and factual subject.
    public let identity: ProvenanceSessionWorkModelIdentity

    /// Current provider thread and thread-level semantic meaning, when available.
    public let thread: ProvenanceSessionWorkModelThread?

    /// Current/latest turn with factual and semantic meaning, when available.
    public let currentTurn: ProvenanceSessionWorkModelCurrentTurn?

    /// Compact factual references for earlier turns.
    public let priorTurns: [ProvenanceFactualSessionProjectionTurnReference]

    /// Session-level semantic phase.
    public let sessionPhase: ProvenanceSessionWorkModelSemanticField

    /// Source layers used to compose this model.
    public let basis: ProvenanceSessionWorkModelBasis

    /// Creates a SessionWorkModel snapshot.
    ///
    /// - Parameters:
    ///   - schemaVersion: Schema version for this model shape.
    ///   - revision: Revision components for reconciliation.
    ///   - identity: Factual session identity.
    ///   - thread: Current provider thread and thread-level meaning.
    ///   - currentTurn: Latest turn and turn-level meaning.
    ///   - priorTurns: Compact references for earlier turns.
    ///   - sessionPhase: Session-level phase field.
    ///   - basis: Source factual and semantic layers used for composition.
    public init(
        schemaVersion: Int = 1,
        revision: ProvenanceSessionWorkModelRevision,
        identity: ProvenanceSessionWorkModelIdentity,
        thread: ProvenanceSessionWorkModelThread?,
        currentTurn: ProvenanceSessionWorkModelCurrentTurn?,
        priorTurns: [ProvenanceFactualSessionProjectionTurnReference],
        sessionPhase: ProvenanceSessionWorkModelSemanticField,
        basis: ProvenanceSessionWorkModelBasis
    ) {
        self.schemaVersion = schemaVersion
        self.revision = revision
        self.identity = identity
        self.thread = thread
        self.currentTurn = currentTurn
        self.priorTurns = priorTurns
        self.sessionPhase = sessionPhase
        self.basis = basis
    }
}
