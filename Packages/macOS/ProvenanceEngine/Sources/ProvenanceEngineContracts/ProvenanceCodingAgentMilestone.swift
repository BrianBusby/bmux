import Foundation

/// One inferred coding-agent milestone in a session work model.
public struct ProvenanceCodingAgentMilestone: Codable, Equatable, Sendable, Identifiable {
    /// Stable semantic milestone identifier within the inferred milestone set.
    public let id: String

    /// Evidence-derived milestone title.
    public let title: String

    /// Optional evidence-derived description when supported by accepted evidence.
    public let description: String?

    /// Normalized provider-reported milestone work status.
    public let status: ProvenanceCodingAgentMilestoneStatus

    /// Zero-based order within the inferred milestone set.
    public let order: Int

    /// Optional parent milestone identifier when hierarchy is explicitly supported.
    public let parentID: String?

    /// Evidence basis PE used to assign ``id``.
    public let identityBasis: ProvenanceCodingAgentMilestoneIdentityBasis

    /// Evidence basis PE used to assign ``status``.
    public let stateBasis: ProvenanceCodingAgentMilestoneStateBasis

    /// Source evidence references directly supporting this milestone item.
    public let sourceEvidenceRefs: [ProvenanceSemanticEvidenceReference]

    /// Bounded ambiguity explanations for this milestone item.
    public let ambiguityReasons: [String]

    /// Bounded omission explanations for this milestone item.
    public let omissionReasons: [String]

    /// Creates an inferred coding-agent milestone.
    public init(
        id: String,
        title: String,
        description: String? = nil,
        status: ProvenanceCodingAgentMilestoneStatus,
        order: Int,
        parentID: String? = nil,
        identityBasis: ProvenanceCodingAgentMilestoneIdentityBasis = .legacyPayload,
        stateBasis: ProvenanceCodingAgentMilestoneStateBasis = .legacyPayload,
        sourceEvidenceRefs: [ProvenanceSemanticEvidenceReference] = [],
        ambiguityReasons: [String] = [],
        omissionReasons: [String] = []
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.status = status
        self.order = order
        self.parentID = parentID
        self.identityBasis = identityBasis
        self.stateBasis = stateBasis
        self.sourceEvidenceRefs = sourceEvidenceRefs
        self.ambiguityReasons = ambiguityReasons
        self.omissionReasons = omissionReasons
    }

    /// Converts this milestone into the generic semantic record payload shape.
    public var semanticPayloadValue: ProvenanceSemanticPayloadValue {
        .object(Self.object([
            "id": .string(id),
            "title": .string(title),
            "description": description.map(ProvenanceSemanticPayloadValue.string),
            "status": .string(status.rawValue),
            "order": .int(order),
            "parentID": parentID.map(ProvenanceSemanticPayloadValue.string),
            "identityBasis": .string(identityBasis.rawValue),
            "stateBasis": .string(stateBasis.rawValue),
            "sourceEvidenceRefs": .array(sourceEvidenceRefs.map(Self.semanticPayloadValue(for:))),
            "ambiguityReasons": .array(ambiguityReasons.map(ProvenanceSemanticPayloadValue.string)),
            "omissionReasons": .array(omissionReasons.map(ProvenanceSemanticPayloadValue.string)),
        ]))
    }

    /// Creates a typed milestone from a generic semantic record payload.
    public init?(semanticPayloadValue: ProvenanceSemanticPayloadValue) {
        guard case let .object(object) = semanticPayloadValue,
              let id = Self.stringValue(in: object, for: "id"),
              let title = Self.stringValue(in: object, for: "title"),
              let statusRawValue = Self.stringValue(in: object, for: "status"),
              let status = ProvenanceCodingAgentMilestoneStatus(rawValue: statusRawValue),
              let order = Self.intValue(in: object, for: "order") else { return nil }
        self.init(
            id: id,
            title: title,
            description: Self.stringValue(in: object, for: "description"),
            status: status,
            order: order,
            parentID: Self.stringValue(in: object, for: "parentID"),
            identityBasis: Self.identityBasis(in: object),
            stateBasis: Self.stateBasis(in: object),
            sourceEvidenceRefs: Self.evidenceRefs(in: object, for: "sourceEvidenceRefs"),
            ambiguityReasons: Self.stringArrayValue(in: object, for: "ambiguityReasons"),
            omissionReasons: Self.stringArrayValue(in: object, for: "omissionReasons")
        )
    }

    /// Decodes milestone JSON while preserving compatibility with older payloads.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.title = try container.decode(String.self, forKey: .title)
        self.description = try container.decodeIfPresent(String.self, forKey: .description)
        self.status = try container.decode(ProvenanceCodingAgentMilestoneStatus.self, forKey: .status)
        self.order = try container.decode(Int.self, forKey: .order)
        self.parentID = try container.decodeIfPresent(String.self, forKey: .parentID)
        self.identityBasis = try container.decodeIfPresent(
            ProvenanceCodingAgentMilestoneIdentityBasis.self,
            forKey: .identityBasis
        ) ?? .legacyPayload
        self.stateBasis = try container.decodeIfPresent(
            ProvenanceCodingAgentMilestoneStateBasis.self,
            forKey: .stateBasis
        ) ?? .legacyPayload
        self.sourceEvidenceRefs = try container.decodeIfPresent(
            [ProvenanceSemanticEvidenceReference].self,
            forKey: .sourceEvidenceRefs
        ) ?? []
        self.ambiguityReasons = try container.decodeIfPresent([String].self, forKey: .ambiguityReasons) ?? []
        self.omissionReasons = try container.decodeIfPresent([String].self, forKey: .omissionReasons) ?? []
    }

    /// Encodes the current milestone JSON shape.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encode(status, forKey: .status)
        try container.encode(order, forKey: .order)
        try container.encodeIfPresent(parentID, forKey: .parentID)
        try container.encode(identityBasis, forKey: .identityBasis)
        try container.encode(stateBasis, forKey: .stateBasis)
        try container.encode(sourceEvidenceRefs, forKey: .sourceEvidenceRefs)
        try container.encode(ambiguityReasons, forKey: .ambiguityReasons)
        try container.encode(omissionReasons, forKey: .omissionReasons)
    }

    func withParentID(_ parentID: String?, addingOmission omission: String? = nil) -> Self {
        var omissions = omissionReasons
        if let omission, !omissions.contains(omission) {
            omissions.append(omission)
        }
        return Self(
            id: id,
            title: title,
            description: description,
            status: status,
            order: order,
            parentID: parentID,
            identityBasis: identityBasis,
            stateBasis: stateBasis,
            sourceEvidenceRefs: sourceEvidenceRefs,
            ambiguityReasons: ambiguityReasons,
            omissionReasons: omissions
        )
    }

    private static func object(
        _ values: [String: ProvenanceSemanticPayloadValue?]
    ) -> [String: ProvenanceSemanticPayloadValue] {
        values.compactMapValues { $0 }
    }

    private static func stringValue(
        in object: [String: ProvenanceSemanticPayloadValue],
        for key: String
    ) -> String? {
        guard case let .string(value) = object[key] else { return nil }
        return value
    }

    private static func intValue(
        in object: [String: ProvenanceSemanticPayloadValue],
        for key: String
    ) -> Int? {
        guard case let .int(value) = object[key] else { return nil }
        return value
    }

    private static func stringArrayValue(
        in object: [String: ProvenanceSemanticPayloadValue],
        for key: String
    ) -> [String] {
        guard case let .array(values) = object[key] else { return [] }
        return values.compactMap { value in
            guard case let .string(string) = value else { return nil }
            return string
        }
    }

    private static func identityBasis(
        in object: [String: ProvenanceSemanticPayloadValue]
    ) -> ProvenanceCodingAgentMilestoneIdentityBasis {
        stringValue(in: object, for: "identityBasis")
            .flatMap(ProvenanceCodingAgentMilestoneIdentityBasis.init(rawValue:)) ?? .legacyPayload
    }

    private static func stateBasis(
        in object: [String: ProvenanceSemanticPayloadValue]
    ) -> ProvenanceCodingAgentMilestoneStateBasis {
        stringValue(in: object, for: "stateBasis")
            .flatMap(ProvenanceCodingAgentMilestoneStateBasis.init(rawValue:)) ?? .legacyPayload
    }

    private static func evidenceRefs(
        in object: [String: ProvenanceSemanticPayloadValue],
        for key: String
    ) -> [ProvenanceSemanticEvidenceReference] {
        guard case let .array(values) = object[key] else { return [] }
        return values.compactMap(evidenceReference)
    }

    private static func semanticPayloadValue(
        for ref: ProvenanceSemanticEvidenceReference
    ) -> ProvenanceSemanticPayloadValue {
        .object(object([
            "kind": .string(ref.kind),
            "id": .string(ref.id),
            "ledgerSequence": ref.ledgerSequence.map(ProvenanceSemanticPayloadValue.int),
            "factualRevision": ref.factualRevision.map(ProvenanceSemanticPayloadValue.int),
        ]))
    }

    private static func evidenceReference(
        from payload: ProvenanceSemanticPayloadValue
    ) -> ProvenanceSemanticEvidenceReference? {
        guard case let .object(object) = payload,
              let kind = stringValue(in: object, for: "kind"),
              let id = stringValue(in: object, for: "id") else { return nil }
        return ProvenanceSemanticEvidenceReference(
            kind: kind,
            id: id,
            ledgerSequence: intValue(in: object, for: "ledgerSequence"),
            factualRevision: intValue(in: object, for: "factualRevision")
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case status
        case order
        case parentID
        case identityBasis
        case stateBasis
        case sourceEvidenceRefs
        case ambiguityReasons
        case omissionReasons
    }
}
