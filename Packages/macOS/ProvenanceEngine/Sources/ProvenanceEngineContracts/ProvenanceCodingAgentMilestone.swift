import Foundation

/// One inferred coding-agent milestone in a session work model.
public struct ProvenanceCodingAgentMilestone: Codable, Equatable, Sendable, Identifiable {
    /// Stable semantic milestone identifier within the inferred milestone set.
    public let id: String

    /// Evidence-derived milestone title.
    public let title: String

    /// Normalized milestone lifecycle status.
    public let status: ProvenanceCodingAgentMilestoneStatus

    /// Zero-based order within the inferred milestone set.
    public let order: Int

    /// Optional parent milestone identifier for future hierarchical inference.
    public let parentID: String?

    /// Creates an inferred coding-agent milestone.
    public init(
        id: String,
        title: String,
        status: ProvenanceCodingAgentMilestoneStatus,
        order: Int,
        parentID: String? = nil
    ) {
        self.id = id
        self.title = title
        self.status = status
        self.order = order
        self.parentID = parentID
    }

    /// Converts this milestone into the generic semantic record payload shape.
    public var semanticPayloadValue: ProvenanceSemanticPayloadValue {
        .object(Self.object([
            "id": .string(id),
            "title": .string(title),
            "status": .string(status.rawValue),
            "order": .int(order),
            "parentID": parentID.map(ProvenanceSemanticPayloadValue.string),
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
            status: status,
            order: order,
            parentID: Self.stringValue(in: object, for: "parentID")
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
}
