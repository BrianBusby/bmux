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

    /// Creates a milestone payload.
    public init(
        currentMilestoneID: String?,
        milestones: [ProvenanceCodingAgentMilestone],
        basis: String,
        unknownReason: String? = nil
    ) {
        self.currentMilestoneID = currentMilestoneID
        self.milestones = milestones
        self.basis = basis
        self.unknownReason = unknownReason
    }

    /// Converts this typed payload into the generic semantic record payload shape.
    public var semanticPayloadValue: ProvenanceSemanticPayloadValue {
        .object(Self.object([
            "currentMilestoneID": currentMilestoneID.map(ProvenanceSemanticPayloadValue.string),
            "milestones": .array(milestones.map(\.semanticPayloadValue)),
            "basis": .string(basis),
            "unknownReason": unknownReason.map(ProvenanceSemanticPayloadValue.string),
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
            unknownReason: Self.stringValue(in: object, for: "unknownReason")
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

    private static func arrayValue(
        in object: [String: ProvenanceSemanticPayloadValue],
        for key: String
    ) -> [ProvenanceSemanticPayloadValue] {
        guard case let .array(value) = object[key] else { return [] }
        return value
    }
}
