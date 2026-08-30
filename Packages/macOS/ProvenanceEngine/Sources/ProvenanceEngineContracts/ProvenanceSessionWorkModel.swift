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

    /// Session-level semantic milestone set.
    public let milestones: ProvenanceSessionWorkModelSemanticField

    /// Session-level semantic blocker set.
    public let blockers: ProvenanceSessionWorkModelSemanticField

    /// Session-level semantic approach-change set.
    public let approachChanges: ProvenanceSessionWorkModelSemanticField

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
    ///   - milestones: Session-level milestone field.
    ///   - blockers: Session-level blocker field.
    ///   - approachChanges: Session-level approach-change field.
    ///   - sessionPhase: Session-level phase field.
    ///   - basis: Source factual and semantic layers used for composition.
    public init(
        schemaVersion: Int = 3,
        revision: ProvenanceSessionWorkModelRevision,
        identity: ProvenanceSessionWorkModelIdentity,
        thread: ProvenanceSessionWorkModelThread?,
        currentTurn: ProvenanceSessionWorkModelCurrentTurn?,
        priorTurns: [ProvenanceFactualSessionProjectionTurnReference],
        milestones: ProvenanceSessionWorkModelSemanticField? = nil,
        blockers: ProvenanceSessionWorkModelSemanticField? = nil,
        approachChanges: ProvenanceSessionWorkModelSemanticField? = nil,
        sessionPhase: ProvenanceSessionWorkModelSemanticField,
        basis: ProvenanceSessionWorkModelBasis
    ) {
        self.schemaVersion = schemaVersion
        self.revision = revision
        self.identity = identity
        self.thread = thread
        self.currentTurn = currentTurn
        self.priorTurns = priorTurns
        self.milestones = milestones ?? Self.defaultMilestones(identity: identity)
        self.blockers = blockers ?? Self.defaultBlockers(identity: identity)
        self.approachChanges = approachChanges ?? Self.defaultApproachChanges(identity: identity)
        self.sessionPhase = sessionPhase
        self.basis = basis
    }

    /// Decodes a SessionWorkModel, defaulting missing older semantic fields to unknown.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let identity = try container.decode(ProvenanceSessionWorkModelIdentity.self, forKey: .identity)
        self.schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        self.revision = try container.decode(ProvenanceSessionWorkModelRevision.self, forKey: .revision)
        self.identity = identity
        self.thread = try container.decodeIfPresent(ProvenanceSessionWorkModelThread.self, forKey: .thread)
        self.currentTurn = try container.decodeIfPresent(ProvenanceSessionWorkModelCurrentTurn.self, forKey: .currentTurn)
        self.priorTurns = try container.decode(
            [ProvenanceFactualSessionProjectionTurnReference].self,
            forKey: .priorTurns
        )
        self.milestones = try container.decodeIfPresent(
            ProvenanceSessionWorkModelSemanticField.self,
            forKey: .milestones
        ) ?? Self.defaultMilestones(identity: identity)
        self.blockers = try container.decodeIfPresent(
            ProvenanceSessionWorkModelSemanticField.self,
            forKey: .blockers
        ) ?? Self.defaultBlockers(identity: identity)
        self.approachChanges = try container.decodeIfPresent(
            ProvenanceSessionWorkModelSemanticField.self,
            forKey: .approachChanges
        ) ?? Self.defaultApproachChanges(identity: identity)
        self.sessionPhase = try container.decode(ProvenanceSessionWorkModelSemanticField.self, forKey: .sessionPhase)
        self.basis = try container.decode(ProvenanceSessionWorkModelBasis.self, forKey: .basis)
    }

    /// Encodes a SessionWorkModel snapshot.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(revision, forKey: .revision)
        try container.encode(identity, forKey: .identity)
        try container.encodeIfPresent(thread, forKey: .thread)
        try container.encodeIfPresent(currentTurn, forKey: .currentTurn)
        try container.encode(priorTurns, forKey: .priorTurns)
        try container.encode(milestones, forKey: .milestones)
        try container.encode(blockers, forKey: .blockers)
        try container.encode(approachChanges, forKey: .approachChanges)
        try container.encode(sessionPhase, forKey: .sessionPhase)
        try container.encode(basis, forKey: .basis)
    }

    private static func defaultMilestones(
        identity: ProvenanceSessionWorkModelIdentity
    ) -> ProvenanceSessionWorkModelSemanticField {
        ProvenanceSessionWorkModelSemanticField(
            kind: ProvenanceCodingAgentSemanticInferenceKind.milestones.rawValue,
            scope: .session,
            scopeID: identity.session.id,
            state: .unknown,
            reason: "no_active_semantic_inference"
        )
    }

    private static func defaultBlockers(
        identity: ProvenanceSessionWorkModelIdentity
    ) -> ProvenanceSessionWorkModelSemanticField {
        ProvenanceSessionWorkModelSemanticField(
            kind: ProvenanceCodingAgentSemanticInferenceKind.blockers.rawValue,
            scope: .session,
            scopeID: identity.session.id,
            state: .unknown,
            reason: "no_active_semantic_inference"
        )
    }

    private static func defaultApproachChanges(
        identity: ProvenanceSessionWorkModelIdentity
    ) -> ProvenanceSessionWorkModelSemanticField {
        ProvenanceSessionWorkModelSemanticField(
            kind: ProvenanceCodingAgentSemanticInferenceKind.approachChanges.rawValue,
            scope: .session,
            scopeID: identity.session.id,
            state: .unknown,
            reason: "no_active_semantic_inference"
        )
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case revision
        case identity
        case thread
        case currentTurn
        case priorTurns
        case milestones
        case blockers
        case approachChanges
        case sessionPhase
        case basis
    }
}
