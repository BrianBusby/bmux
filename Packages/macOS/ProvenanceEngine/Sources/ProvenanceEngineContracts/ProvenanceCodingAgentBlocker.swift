import Foundation

/// One inferred coding-agent blocker inside a session work model.
public struct ProvenanceCodingAgentBlocker: Codable, Equatable, Sendable, Identifiable {
    /// Stable semantic blocker identifier within the session.
    public let id: String

    /// Concise evidence-derived blocker description.
    public let description: String

    /// Intended activity affected by this blocker.
    public let affectedActivity: String

    /// Reported condition preventing, bypassing, or ceasing to affect the activity.
    public let condition: String

    /// Optional same-session milestone identifier affected by the blocker.
    public let affectedMilestoneID: String?

    /// Reported blocker state.
    public let state: ProvenanceCodingAgentBlockerState

    /// Evidence basis PE used to assign ``id``.
    public let identityBasis: ProvenanceCodingAgentBlockerIdentityBasis

    /// Evidence basis PE used to assign ``state``.
    public let stateBasis: ProvenanceCodingAgentBlockerStateBasis

    /// Provider that emitted the supporting visible statement, when known.
    public let reportedByProvider: String?

    /// Source classification of the supporting visible statement, when known.
    public let reportedBySource: String?

    /// Source evidence references directly supporting this blocker item.
    public let sourceEvidenceRefs: [ProvenanceSemanticEvidenceReference]

    /// Bounded ambiguity explanations for this blocker item.
    public let ambiguityReasons: [String]

    /// Bounded omission explanations for this blocker item.
    public let omissionReasons: [String]

    /// Creates an inferred coding-agent blocker.
    public init(
        id: String,
        description: String,
        affectedActivity: String,
        condition: String,
        affectedMilestoneID: String? = nil,
        state: ProvenanceCodingAgentBlockerState,
        identityBasis: ProvenanceCodingAgentBlockerIdentityBasis = .legacyPayload,
        stateBasis: ProvenanceCodingAgentBlockerStateBasis = .legacyPayload,
        reportedByProvider: String? = nil,
        reportedBySource: String? = nil,
        sourceEvidenceRefs: [ProvenanceSemanticEvidenceReference] = [],
        ambiguityReasons: [String] = [],
        omissionReasons: [String] = []
    ) {
        self.id = id
        self.description = description
        self.affectedActivity = affectedActivity
        self.condition = condition
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

    /// Converts this blocker into the generic semantic record payload shape.
    public var semanticPayloadValue: ProvenanceSemanticPayloadValue {
        .object(ProvenanceCodingAgentSemanticPayloadCoding.object([
            "id": .string(id),
            "description": .string(description),
            "affectedActivity": .string(affectedActivity),
            "condition": .string(condition),
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

    /// Creates a typed blocker from a generic semantic record payload.
    public init?(semanticPayloadValue: ProvenanceSemanticPayloadValue) {
        guard case let .object(object) = semanticPayloadValue,
              let id = ProvenanceCodingAgentSemanticPayloadCoding.stringValue(in: object, for: "id"),
              let description = ProvenanceCodingAgentSemanticPayloadCoding.stringValue(in: object, for: "description"),
              let affectedActivity = ProvenanceCodingAgentSemanticPayloadCoding.stringValue(in: object, for: "affectedActivity"),
              let condition = ProvenanceCodingAgentSemanticPayloadCoding.stringValue(in: object, for: "condition"),
              let stateRawValue = ProvenanceCodingAgentSemanticPayloadCoding.stringValue(in: object, for: "state"),
              let state = ProvenanceCodingAgentBlockerState(rawValue: stateRawValue) else { return nil }
        self.init(
            id: id,
            description: description,
            affectedActivity: affectedActivity,
            condition: condition,
            affectedMilestoneID: ProvenanceCodingAgentSemanticPayloadCoding.stringValue(in: object, for: "affectedMilestoneID"),
            state: state,
            identityBasis: ProvenanceCodingAgentSemanticPayloadCoding.stringValue(in: object, for: "identityBasis")
                .flatMap(ProvenanceCodingAgentBlockerIdentityBasis.init(rawValue:)) ?? .legacyPayload,
            stateBasis: ProvenanceCodingAgentSemanticPayloadCoding.stringValue(in: object, for: "stateBasis")
                .flatMap(ProvenanceCodingAgentBlockerStateBasis.init(rawValue:)) ?? .legacyPayload,
            reportedByProvider: ProvenanceCodingAgentSemanticPayloadCoding.stringValue(in: object, for: "reportedByProvider"),
            reportedBySource: ProvenanceCodingAgentSemanticPayloadCoding.stringValue(in: object, for: "reportedBySource"),
            sourceEvidenceRefs: ProvenanceCodingAgentSemanticPayloadCoding.evidenceRefs(in: object, for: "sourceEvidenceRefs"),
            ambiguityReasons: ProvenanceCodingAgentSemanticPayloadCoding.stringArrayValue(in: object, for: "ambiguityReasons"),
            omissionReasons: ProvenanceCodingAgentSemanticPayloadCoding.stringArrayValue(in: object, for: "omissionReasons")
        )
    }
}
