import Foundation

/// Structured semantic payload for inferred coding-agent approach changes.
public struct ProvenanceCodingAgentApproachChangePayload: Codable, Equatable, Sendable {
    /// Ordered inferred approach changes.
    public let approachChanges: [ProvenanceCodingAgentApproachChange]

    /// Evidence class that produced this approach-change claim.
    public let basis: String

    /// Detailed source-history completeness used by the rule.
    public let sourceHistoryState: ProvenanceCodingAgentSemanticSourceHistoryState

    /// Why the approach-change set had to remain unknown.
    public let unknownReason: String?

    /// Bounded ambiguity explanations that apply to the approach-change set.
    public let ambiguityReasons: [String]

    /// Bounded omission explanations that apply to the approach-change set.
    public let omissionReasons: [String]

    /// Creates an approach-change payload.
    public init(
        approachChanges: [ProvenanceCodingAgentApproachChange],
        basis: String,
        sourceHistoryState: ProvenanceCodingAgentSemanticSourceHistoryState = .complete,
        unknownReason: String? = nil,
        ambiguityReasons: [String] = [],
        omissionReasons: [String] = []
    ) {
        self.approachChanges = approachChanges
        self.basis = basis
        self.sourceHistoryState = sourceHistoryState
        self.unknownReason = unknownReason
        self.ambiguityReasons = ProvenanceCodingAgentSemanticPayloadCoding.unique(
            ambiguityReasons + approachChanges.flatMap(\.ambiguityReasons)
        )
        self.omissionReasons = ProvenanceCodingAgentSemanticPayloadCoding.unique(
            omissionReasons + approachChanges.flatMap(\.omissionReasons)
        )
    }

    /// Converts this typed payload into the generic semantic record payload shape.
    public var semanticPayloadValue: ProvenanceSemanticPayloadValue {
        .object(ProvenanceCodingAgentSemanticPayloadCoding.object([
            "approachChanges": .array(approachChanges.map(\.semanticPayloadValue)),
            "basis": .string(basis),
            "sourceHistoryState": .string(sourceHistoryState.rawValue),
            "unknownReason": unknownReason.map(ProvenanceSemanticPayloadValue.string),
            "ambiguityReasons": .array(ambiguityReasons.map(ProvenanceSemanticPayloadValue.string)),
            "omissionReasons": .array(omissionReasons.map(ProvenanceSemanticPayloadValue.string)),
        ]))
    }

    /// Creates a typed approach-change payload from a generic semantic record payload.
    public init?(semanticPayloadValue: ProvenanceSemanticPayloadValue) {
        guard case let .object(object) = semanticPayloadValue,
              let basis = ProvenanceCodingAgentSemanticPayloadCoding.stringValue(in: object, for: "basis") else {
            return nil
        }
        let approachChanges = ProvenanceCodingAgentSemanticPayloadCoding
            .arrayValue(in: object, for: "approachChanges")
            .compactMap { ProvenanceCodingAgentApproachChange(semanticPayloadValue: $0) }
        self.init(
            approachChanges: approachChanges,
            basis: basis,
            sourceHistoryState: ProvenanceCodingAgentSemanticPayloadCoding.stringValue(in: object, for: "sourceHistoryState")
                .flatMap(ProvenanceCodingAgentSemanticSourceHistoryState.init(rawValue:)) ?? .complete,
            unknownReason: ProvenanceCodingAgentSemanticPayloadCoding.stringValue(in: object, for: "unknownReason"),
            ambiguityReasons: ProvenanceCodingAgentSemanticPayloadCoding.stringArrayValue(in: object, for: "ambiguityReasons"),
            omissionReasons: ProvenanceCodingAgentSemanticPayloadCoding.stringArrayValue(in: object, for: "omissionReasons")
        )
    }
}
