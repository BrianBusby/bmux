import Foundation

/// Structured semantic payload for inferred coding-agent milestones.
public struct ProvenanceCodingAgentMilestonePayload: Codable, Equatable, Sendable {
    /// Identifier of the milestone PE considers current, when known.
    public let currentMilestoneID: String?

    /// Ordered inferred milestones.
    public let milestones: [ProvenanceCodingAgentMilestone]

    /// Evidence class that produced this milestone claim.
    public let basis: String

    /// Why the milestone set had to remain unknown.
    public let unknownReason: String?

    /// Bounded ambiguity explanations that apply to the milestone set.
    public let ambiguityReasons: [String]

    /// Bounded omission explanations that apply to the milestone set.
    public let omissionReasons: [String]

    /// Creates a milestone payload.
    public init(
        currentMilestoneID: String?,
        milestones: [ProvenanceCodingAgentMilestone],
        basis: String,
        unknownReason: String? = nil,
        ambiguityReasons: [String] = [],
        omissionReasons: [String] = []
    ) {
        let validation = Self.validatedHierarchy(milestones)
        let currentMilestone = Self.validatedCurrentMilestoneID(
            currentMilestoneID,
            milestones: validation.milestones
        )
        self.currentMilestoneID = currentMilestone.currentMilestoneID
        self.milestones = validation.milestones
        self.basis = basis
        self.unknownReason = unknownReason
        self.ambiguityReasons = Self.unique(ambiguityReasons + validation.ambiguityReasons)
        self.omissionReasons = Self.unique(
            omissionReasons
                + validation.omissionReasons
                + currentMilestone.omissionReasons
        )
    }

    /// Converts this typed payload into the generic semantic record payload shape.
    public var semanticPayloadValue: ProvenanceSemanticPayloadValue {
        .object(Self.object([
            "currentMilestoneID": currentMilestoneID.map(ProvenanceSemanticPayloadValue.string),
            "milestones": .array(milestones.map(\.semanticPayloadValue)),
            "basis": .string(basis),
            "unknownReason": unknownReason.map(ProvenanceSemanticPayloadValue.string),
            "ambiguityReasons": .array(ambiguityReasons.map(ProvenanceSemanticPayloadValue.string)),
            "omissionReasons": .array(omissionReasons.map(ProvenanceSemanticPayloadValue.string)),
        ]))
    }

    /// Creates a typed milestone payload from a generic semantic record payload.
    public init?(semanticPayloadValue: ProvenanceSemanticPayloadValue) {
        guard case let .object(object) = semanticPayloadValue,
              let basis = Self.stringValue(in: object, for: "basis") else { return nil }
        let milestones = Self.arrayValue(in: object, for: "milestones").compactMap {
            ProvenanceCodingAgentMilestone(semanticPayloadValue: $0)
        }
        self.init(
            currentMilestoneID: Self.stringValue(in: object, for: "currentMilestoneID"),
            milestones: milestones,
            basis: basis,
            unknownReason: Self.stringValue(in: object, for: "unknownReason"),
            ambiguityReasons: Self.stringArrayValue(in: object, for: "ambiguityReasons"),
            omissionReasons: Self.stringArrayValue(in: object, for: "omissionReasons")
        )
    }

    /// Decodes milestone-payload JSON while preserving compatibility with older payloads.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            currentMilestoneID: try container.decodeIfPresent(String.self, forKey: .currentMilestoneID),
            milestones: try container.decode([ProvenanceCodingAgentMilestone].self, forKey: .milestones),
            basis: try container.decode(String.self, forKey: .basis),
            unknownReason: try container.decodeIfPresent(String.self, forKey: .unknownReason),
            ambiguityReasons: try container.decodeIfPresent([String].self, forKey: .ambiguityReasons) ?? [],
            omissionReasons: try container.decodeIfPresent([String].self, forKey: .omissionReasons) ?? []
        )
    }

    /// Encodes the current milestone-payload JSON shape.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(currentMilestoneID, forKey: .currentMilestoneID)
        try container.encode(milestones, forKey: .milestones)
        try container.encode(basis, forKey: .basis)
        try container.encodeIfPresent(unknownReason, forKey: .unknownReason)
        try container.encode(ambiguityReasons, forKey: .ambiguityReasons)
        try container.encode(omissionReasons, forKey: .omissionReasons)
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

    private static func arrayValue(
        in object: [String: ProvenanceSemanticPayloadValue],
        for key: String
    ) -> [ProvenanceSemanticPayloadValue] {
        guard case let .array(value) = object[key] else { return [] }
        return value
    }

    private static func validatedHierarchy(
        _ milestones: [ProvenanceCodingAgentMilestone]
    ) -> (
        milestones: [ProvenanceCodingAgentMilestone],
        ambiguityReasons: [String],
        omissionReasons: [String]
    ) {
        let idCounts = Dictionary(grouping: milestones.map(\.id), by: { $0 }).mapValues(\.count)
        let duplicateIDs = Set(idCounts.filter { $0.value > 1 }.map(\.key))
        var byID: [String: ProvenanceCodingAgentMilestone] = [:]
        for milestone in milestones where !duplicateIDs.contains(milestone.id) {
            byID[milestone.id] = milestone
        }

        var payloadAmbiguities: [String] = duplicateIDs.isEmpty ? [] : ["duplicate_milestone_identity"]
        var payloadOmissions: [String] = []
        let validated = milestones.map { milestone -> ProvenanceCodingAgentMilestone in
            if duplicateIDs.contains(milestone.id) {
                payloadAmbiguities.append("duplicate_milestone_identity:\(milestone.id)")
                return milestone.withParentID(nil, addingOmission: "duplicate_identity_parent_relationship_omitted")
            }
            guard let parentID = milestone.parentID else { return milestone }
            guard byID[parentID] != nil else {
                payloadOmissions.append("unresolvable_parent_relationship_omitted:\(milestone.id)")
                return milestone.withParentID(nil, addingOmission: "unresolvable_parent_relationship_omitted")
            }
            guard parentID != milestone.id,
                  !hasCycle(startID: milestone.id, parentID: parentID, byID: byID) else {
                payloadOmissions.append("cyclic_parent_relationship_omitted:\(milestone.id)")
                return milestone.withParentID(nil, addingOmission: "cyclic_parent_relationship_omitted")
            }
            return milestone
        }

        return (
            milestones: validated,
            ambiguityReasons: unique(payloadAmbiguities),
            omissionReasons: unique(payloadOmissions)
        )
    }

    private static func validatedCurrentMilestoneID(
        _ currentMilestoneID: String?,
        milestones: [ProvenanceCodingAgentMilestone]
    ) -> (currentMilestoneID: String?, omissionReasons: [String]) {
        guard let currentMilestoneID else {
            return (nil, [])
        }
        let idCounts = Dictionary(grouping: milestones.map(\.id), by: { $0 }).mapValues(\.count)
        switch idCounts[currentMilestoneID] {
        case .some(1):
            return (currentMilestoneID, [])
        case .some:
            return (nil, ["current_milestone_identity_ambiguous"])
        case .none:
            return (nil, ["current_milestone_identity_unresolvable"])
        }
    }

    private static func hasCycle(
        startID: String,
        parentID: String,
        byID: [String: ProvenanceCodingAgentMilestone]
    ) -> Bool {
        var visited = Set<String>()
        var currentID: String? = parentID
        while let id = currentID {
            if id == startID { return true }
            guard visited.insert(id).inserted else { return true }
            currentID = byID[id]?.parentID
        }
        return false
    }

    private static func unique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for value in values where seen.insert(value).inserted {
            result.append(value)
        }
        return result
    }

    private enum CodingKeys: String, CodingKey {
        case currentMilestoneID
        case milestones
        case basis
        case unknownReason
        case ambiguityReasons
        case omissionReasons
    }
}
