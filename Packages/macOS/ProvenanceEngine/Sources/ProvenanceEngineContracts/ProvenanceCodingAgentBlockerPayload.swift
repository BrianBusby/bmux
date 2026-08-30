import Foundation

/// Structured semantic payload for inferred coding-agent blockers.
public struct ProvenanceCodingAgentBlockerPayload: Codable, Equatable, Sendable {
    /// Ordered inferred blockers and blocker-resolution episodes.
    public let blockers: [ProvenanceCodingAgentBlocker]

    /// Evidence class that produced this blocker claim.
    public let basis: String

    /// Detailed source-history completeness used by the rule.
    public let sourceHistoryState: ProvenanceCodingAgentSemanticSourceHistoryState

    /// Why the blocker set had to remain unknown.
    public let unknownReason: String?

    /// Bounded ambiguity explanations that apply to the blocker set.
    public let ambiguityReasons: [String]

    /// Bounded omission explanations that apply to the blocker set.
    public let omissionReasons: [String]

    /// Creates a blocker payload.
    public init(
        blockers: [ProvenanceCodingAgentBlocker],
        basis: String,
        sourceHistoryState: ProvenanceCodingAgentSemanticSourceHistoryState = .complete,
        unknownReason: String? = nil,
        ambiguityReasons: [String] = [],
        omissionReasons: [String] = []
    ) {
        self.blockers = blockers
        self.basis = basis
        self.sourceHistoryState = sourceHistoryState
        self.unknownReason = unknownReason
        self.ambiguityReasons = ProvenanceCodingAgentSemanticPayloadCoding.unique(
            ambiguityReasons + blockers.flatMap(\.ambiguityReasons)
        )
        self.omissionReasons = ProvenanceCodingAgentSemanticPayloadCoding.unique(
            omissionReasons + blockers.flatMap(\.omissionReasons)
        )
    }

    /// Converts this typed payload into the generic semantic record payload shape.
    public var semanticPayloadValue: ProvenanceSemanticPayloadValue {
        .object(ProvenanceCodingAgentSemanticPayloadCoding.object([
            "blockers": .array(blockers.map(\.semanticPayloadValue)),
            "basis": .string(basis),
            "sourceHistoryState": .string(sourceHistoryState.rawValue),
            "unknownReason": unknownReason.map(ProvenanceSemanticPayloadValue.string),
            "ambiguityReasons": .array(ambiguityReasons.map(ProvenanceSemanticPayloadValue.string)),
            "omissionReasons": .array(omissionReasons.map(ProvenanceSemanticPayloadValue.string)),
        ]))
    }

    /// Creates a typed blocker payload from a generic semantic record payload.
    public init?(semanticPayloadValue: ProvenanceSemanticPayloadValue) {
        guard case let .object(object) = semanticPayloadValue,
              let basis = ProvenanceCodingAgentSemanticPayloadCoding.stringValue(in: object, for: "basis") else {
            return nil
        }
        let blockers = ProvenanceCodingAgentSemanticPayloadCoding
            .arrayValue(in: object, for: "blockers")
            .compactMap { ProvenanceCodingAgentBlocker(semanticPayloadValue: $0) }
        self.init(
            blockers: blockers,
            basis: basis,
            sourceHistoryState: ProvenanceCodingAgentSemanticPayloadCoding.stringValue(in: object, for: "sourceHistoryState")
                .flatMap(ProvenanceCodingAgentSemanticSourceHistoryState.init(rawValue:)) ?? .complete,
            unknownReason: ProvenanceCodingAgentSemanticPayloadCoding.stringValue(in: object, for: "unknownReason"),
            ambiguityReasons: ProvenanceCodingAgentSemanticPayloadCoding.stringArrayValue(in: object, for: "ambiguityReasons"),
            omissionReasons: ProvenanceCodingAgentSemanticPayloadCoding.stringArrayValue(in: object, for: "omissionReasons")
        )
    }
}
