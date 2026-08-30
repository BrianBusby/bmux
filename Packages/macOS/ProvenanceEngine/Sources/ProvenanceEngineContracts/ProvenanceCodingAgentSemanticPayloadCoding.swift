import Foundation

enum ProvenanceCodingAgentSemanticPayloadCoding {
    static func object(
        _ values: [String: ProvenanceSemanticPayloadValue?]
    ) -> [String: ProvenanceSemanticPayloadValue] {
        values.compactMapValues { $0 }
    }

    static func stringValue(
        in object: [String: ProvenanceSemanticPayloadValue],
        for key: String
    ) -> String? {
        guard case let .string(value) = object[key] else { return nil }
        return value
    }

    static func intValue(
        in object: [String: ProvenanceSemanticPayloadValue],
        for key: String
    ) -> Int? {
        guard case let .int(value) = object[key] else { return nil }
        return value
    }

    static func arrayValue(
        in object: [String: ProvenanceSemanticPayloadValue],
        for key: String
    ) -> [ProvenanceSemanticPayloadValue] {
        guard case let .array(value) = object[key] else { return [] }
        return value
    }

    static func stringArrayValue(
        in object: [String: ProvenanceSemanticPayloadValue],
        for key: String
    ) -> [String] {
        guard case let .array(values) = object[key] else { return [] }
        return values.compactMap { value in
            guard case let .string(string) = value else { return nil }
            return string
        }
    }

    static func semanticPayloadValue(
        for ref: ProvenanceSemanticEvidenceReference
    ) -> ProvenanceSemanticPayloadValue {
        .object(object([
            "kind": .string(ref.kind),
            "id": .string(ref.id),
            "ledgerSequence": ref.ledgerSequence.map(ProvenanceSemanticPayloadValue.int),
            "factualRevision": ref.factualRevision.map(ProvenanceSemanticPayloadValue.int),
        ]))
    }

    static func evidenceReference(
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

    static func evidenceRefs(
        in object: [String: ProvenanceSemanticPayloadValue],
        for key: String
    ) -> [ProvenanceSemanticEvidenceReference] {
        arrayValue(in: object, for: key).compactMap(evidenceReference)
    }

    static func unique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for value in values where seen.insert(value).inserted {
            result.append(value)
        }
        return result
    }
}
