import Foundation

/// One inferred coding-agent approach change inside a session work model.
public struct ProvenanceCodingAgentApproachChange: Codable, Equatable, Sendable, Identifiable {
    /// Stable semantic approach-change identifier within the session.
    public let id: String

    /// Objective whose strategy changed.
    public let objective: String

    /// Prior reported approach.
    public let priorApproach: String

    /// Replacement reported approach, when the accepted statement supplies one.
    public let replacementApproach: String?

    /// Reported reason for the approach change, when supplied.
    public let reason: String?

    /// Optional same-session milestone identifier affected by the approach change.
    public let affectedMilestoneID: String?

    /// Reported approach-change state.
    public let state: ProvenanceCodingAgentApproachChangeState

    /// Evidence basis PE used to assign ``id``.
    public let identityBasis: ProvenanceCodingAgentApproachChangeIdentityBasis

    /// Evidence basis PE used to assign ``state``.
    public let stateBasis: ProvenanceCodingAgentApproachChangeStateBasis

    /// Provider that emitted the supporting visible statement, when known.
    public let reportedByProvider: String?

    /// Source classification of the supporting visible statement, when known.
    public let reportedBySource: String?

    /// Source evidence references directly supporting this approach-change item.
    public let sourceEvidenceRefs: [ProvenanceSemanticEvidenceReference]

    /// Bounded ambiguity explanations for this approach-change item.
    public let ambiguityReasons: [String]

    /// Bounded omission explanations for this approach-change item.
    public let omissionReasons: [String]

    /// Creates an inferred coding-agent approach change.
    public init(
        id: String,
        objective: String,
        priorApproach: String,
        replacementApproach: String? = nil,
        reason: String? = nil,
        affectedMilestoneID: String? = nil,
        state: ProvenanceCodingAgentApproachChangeState,
        identityBasis: ProvenanceCodingAgentApproachChangeIdentityBasis = .legacyPayload,
        stateBasis: ProvenanceCodingAgentApproachChangeStateBasis = .legacyPayload,
        reportedByProvider: String? = nil,
        reportedBySource: String? = nil,
        sourceEvidenceRefs: [ProvenanceSemanticEvidenceReference] = [],
        ambiguityReasons: [String] = [],
        omissionReasons: [String] = []
    ) {
        self.id = id
        self.objective = objective
        self.priorApproach = priorApproach
        self.replacementApproach = replacementApproach
        self.reason = reason
        self.affectedMilestoneID = affectedMilestoneID
        self.state = state
        self.identityBasis = identityBasis
        self.stateBasis = stateBasis
        self.reportedByProvider = reportedByProvider
        self.reportedBySource = reportedBySource
        self.sourceEvidenceRefs = sourceEvidenceRefs
        self.ambiguityReasons = ProvenanceCodingAgentSemanticPayloadCoding.unique(ambiguityReasons)
        self.omissionReasons = ProvenanceCodingAgentSemanticPayloadCoding.unique(omissionReasons)
    }

    /// Converts this approach change into the generic semantic record payload shape.
    public var semanticPayloadValue: ProvenanceSemanticPayloadValue {
        .object(ProvenanceCodingAgentSemanticPayloadCoding.object([
            "id": .string(id),
            "objective": .string(objective),
            "priorApproach": .string(priorApproach),
            "replacementApproach": replacementApproach.map(ProvenanceSemanticPayloadValue.string),
            "reason": reason.map(ProvenanceSemanticPayloadValue.string),
            "affectedMilestoneID": affectedMilestoneID.map(ProvenanceSemanticPayloadValue.string),
            "state": .string(state.rawValue),
            "identityBasis": .string(identityBasis.rawValue),
            "stateBasis": .string(stateBasis.rawValue),
            "reportedByProvider": reportedByProvider.map(ProvenanceSemanticPayloadValue.string),
            "reportedBySource": reportedBySource.map(ProvenanceSemanticPayloadValue.string),
            "sourceEvidenceRefs": .array(sourceEvidenceRefs.map(
                ProvenanceCodingAgentSemanticPayloadCoding.semanticPayloadValue(for:)
            )),
            "ambiguityReasons": .array(ambiguityReasons.map(ProvenanceSemanticPayloadValue.string)),
            "omissionReasons": .array(omissionReasons.map(ProvenanceSemanticPayloadValue.string)),
        ]))
    }

    /// Creates a typed approach change from a generic semantic record payload.
    public init?(semanticPayloadValue: ProvenanceSemanticPayloadValue) {
        guard case let .object(object) = semanticPayloadValue,
              let id = ProvenanceCodingAgentSemanticPayloadCoding.stringValue(in: object, for: "id"),
              let objective = ProvenanceCodingAgentSemanticPayloadCoding.stringValue(in: object, for: "objective"),
              let priorApproach = ProvenanceCodingAgentSemanticPayloadCoding.stringValue(in: object, for: "priorApproach"),
              let stateRawValue = ProvenanceCodingAgentSemanticPayloadCoding.stringValue(in: object, for: "state"),
              let state = ProvenanceCodingAgentApproachChangeState(rawValue: stateRawValue) else { return nil }
        self.init(
            id: id,
            objective: objective,
            priorApproach: priorApproach,
            replacementApproach: ProvenanceCodingAgentSemanticPayloadCoding.stringValue(in: object, for: "replacementApproach"),
            reason: ProvenanceCodingAgentSemanticPayloadCoding.stringValue(in: object, for: "reason"),
            affectedMilestoneID: ProvenanceCodingAgentSemanticPayloadCoding.stringValue(in: object, for: "affectedMilestoneID"),
            state: state,
            identityBasis: ProvenanceCodingAgentSemanticPayloadCoding.stringValue(in: object, for: "identityBasis")
                .flatMap(ProvenanceCodingAgentApproachChangeIdentityBasis.init(rawValue:)) ?? .legacyPayload,
            stateBasis: ProvenanceCodingAgentSemanticPayloadCoding.stringValue(in: object, for: "stateBasis")
                .flatMap(ProvenanceCodingAgentApproachChangeStateBasis.init(rawValue:)) ?? .legacyPayload,
            reportedByProvider: ProvenanceCodingAgentSemanticPayloadCoding.stringValue(in: object, for: "reportedByProvider"),
            reportedBySource: ProvenanceCodingAgentSemanticPayloadCoding.stringValue(in: object, for: "reportedBySource"),
            sourceEvidenceRefs: ProvenanceCodingAgentSemanticPayloadCoding.evidenceRefs(in: object, for: "sourceEvidenceRefs"),
            ambiguityReasons: ProvenanceCodingAgentSemanticPayloadCoding.stringArrayValue(in: object, for: "ambiguityReasons"),
            omissionReasons: ProvenanceCodingAgentSemanticPayloadCoding.stringArrayValue(in: object, for: "omissionReasons")
        )
    }
}
