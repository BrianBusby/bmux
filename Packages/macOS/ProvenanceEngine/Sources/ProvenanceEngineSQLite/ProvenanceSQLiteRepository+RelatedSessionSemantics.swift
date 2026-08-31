import Foundation
import ProvenanceEngineContracts

extension ProvenanceSQLiteRepository {
    static let relatedSessionSemanticPayloadItemLimit = 10

    func boundedRelatedSessionSemanticField(
        _ field: ProvenanceSessionWorkModelSemanticField
    ) -> ProvenanceSessionWorkModelSemanticField {
        guard let record = field.record else { return field }
        let boundedPayload = boundedRelatedSessionSemanticPayload(kind: field.kind, payload: record.payload)
        guard boundedPayload != record.payload else { return field }
        return ProvenanceSessionWorkModelSemanticField(
            kind: field.kind,
            scope: field.scope,
            scopeID: field.scopeID,
            state: field.state,
            record: record.replacingPayload(boundedPayload),
            reason: field.reason
        )
    }

    func boundedRelatedSessionSemanticPayload(
        kind: String,
        payload: ProvenanceSemanticPayloadValue
    ) -> ProvenanceSemanticPayloadValue {
        guard case var .object(object) = payload else { return payload }
        let limit = Self.relatedSessionSemanticPayloadItemLimit
        let result: (arrayKey: String, omissionSubject: String, requiredID: String?)?
        switch kind {
        case ProvenanceCodingAgentSemanticInferenceKind.milestones.rawValue:
            result = (
                arrayKey: "milestones",
                omissionSubject: "milestones",
                requiredID: relatedSessionSemanticPayloadString(object["currentMilestoneID"])
            )
        case ProvenanceCodingAgentSemanticInferenceKind.blockers.rawValue:
            result = (arrayKey: "blockers", omissionSubject: "blockers", requiredID: nil)
        case ProvenanceCodingAgentSemanticInferenceKind.approachChanges.rawValue:
            result = (arrayKey: "approachChanges", omissionSubject: "approach_changes", requiredID: nil)
        default:
            result = nil
        }
        guard let result,
              case let .array(items) = object[result.arrayKey],
              let bounded = boundedRelatedSessionSemanticPayloadItems(
                items,
                limit: limit,
                requiredID: result.requiredID
              ) else {
            return payload
        }

        object[result.arrayKey] = .array(bounded.items)
        var omissionReasons = relatedSessionSemanticPayloadStringArray(object["omissionReasons"])
        omissionReasons.append(
            "related_session_semantic_payload_omitted:\(result.omissionSubject):\(bounded.omittedCount)"
        )
        object["omissionReasons"] = .array(uniqueRelatedSessionStrings(omissionReasons).map {
            ProvenanceSemanticPayloadValue.string($0)
        })
        return .object(object)
    }

    func boundedRelatedSessionSemanticPayloadItems(
        _ items: [ProvenanceSemanticPayloadValue],
        limit: Int,
        requiredID: String?
    ) -> (items: [ProvenanceSemanticPayloadValue], omittedCount: Int)? {
        guard limit > 0, items.count > limit else { return nil }
        var selectedIndexes = Set(0..<limit)
        if let requiredID,
           let requiredIndex = items.firstIndex(where: { relatedSessionSemanticPayloadItemID($0) == requiredID }),
           !selectedIndexes.contains(requiredIndex) {
            selectedIndexes.remove(limit - 1)
            selectedIndexes.insert(requiredIndex)
        }
        let boundedItems = items.enumerated().compactMap { index, item in
            selectedIndexes.contains(index) ? item : nil
        }
        return (boundedItems, items.count - boundedItems.count)
    }

    func relatedSessionSemanticAvailability(
        field: ProvenanceSessionWorkModelSemanticField,
        workModel: ProvenanceSessionWorkModel?
    ) -> ProvenanceRelatedSessionAvailability {
        let evidence = relatedSessionSemanticFieldEvidence(field: field, workModel: workModel)
        switch field.state {
        case .known:
            if let reason = relatedSessionSemanticPartialReason(field.record?.payload) {
                return ProvenanceRelatedSessionAvailability(
                    field: "semantic_field:\(field.kind)",
                    status: "partial",
                    reason: reason,
                    evidence: evidence
                )
            }
            return ProvenanceRelatedSessionAvailability(
                field: "semantic_field:\(field.kind)",
                status: "observed",
                evidence: evidence
            )
        case .unknown:
            return ProvenanceRelatedSessionAvailability(
                field: "semantic_field:\(field.kind)",
                status: "unknown",
                reason: field.reason ?? "semantic_field_unknown",
                evidence: evidence
            )
        case .unavailable:
            return ProvenanceRelatedSessionAvailability(
                field: "semantic_field:\(field.kind)",
                status: "unavailable",
                reason: field.reason ?? "semantic_field_unavailable",
                evidence: evidence
            )
        }
    }

    func relatedSessionSemanticFieldEvidence(
        field: ProvenanceSessionWorkModelSemanticField,
        workModel: ProvenanceSessionWorkModel?
    ) -> [ProvenanceRelatedSessionEvidenceReference] {
        var evidence = workModel.map { [relatedSessionEvidence($0)] } ?? []
        if let record = field.record {
            evidence.append(ProvenanceRelatedSessionEvidenceReference(
                kind: "semantic_inference",
                id: record.inferenceID,
                projectionWatermark: record.supportingFactualRevision,
                field: field.kind,
                sourceState: record.status.rawValue
            ))
        }
        return uniqueRelatedSessionEvidence(evidence)
    }

    func relatedSessionSemanticPartialReason(
        _ payload: ProvenanceSemanticPayloadValue?
    ) -> String? {
        guard let payload else { return nil }
        let omissionReasons = relatedSessionSemanticPayloadOmissionReasons(payload)
        if omissionReasons.contains(where: { $0.hasPrefix("related_session_semantic_payload_omitted:") }) {
            return "bounded_semantic_payload"
        }
        if relatedSessionSemanticPayloadSourceHistoryState(payload) == "partial" {
            return "partial_source_history"
        }
        if !omissionReasons.isEmpty {
            return "source_semantic_omissions"
        }
        return nil
    }

    func relatedSessionSemanticPayloadSourceHistoryState(
        _ payload: ProvenanceSemanticPayloadValue
    ) -> String? {
        guard case let .object(object) = payload else { return nil }
        return relatedSessionSemanticPayloadString(object["sourceHistoryState"])
    }

    func relatedSessionSemanticPayloadOmissionReasons(
        _ payload: ProvenanceSemanticPayloadValue
    ) -> [String] {
        guard case let .object(object) = payload else { return [] }
        return relatedSessionSemanticPayloadStringArray(object["omissionReasons"])
    }

    func relatedSessionSemanticPayloadItemID(
        _ payload: ProvenanceSemanticPayloadValue
    ) -> String? {
        guard case let .object(object) = payload else { return nil }
        return relatedSessionSemanticPayloadString(object["id"])
    }

    func relatedSessionSemanticPayloadString(
        _ payload: ProvenanceSemanticPayloadValue?
    ) -> String? {
        guard case let .string(value) = payload else { return nil }
        return value
    }

    func relatedSessionSemanticPayloadStringArray(
        _ payload: ProvenanceSemanticPayloadValue?
    ) -> [String] {
        guard case let .array(values) = payload else { return [] }
        return values.compactMap(relatedSessionSemanticPayloadString)
    }

    func uniqueRelatedSessionStrings(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for value in values where seen.insert(value).inserted {
            result.append(value)
        }
        return result
    }

    func relatedSessionSemanticFieldFingerprint(
        _ field: ProvenanceSessionWorkModelSemanticField
    ) -> String {
        var parts = [
            "semantic_field",
            "kind=\(field.kind)",
            "scope=\(field.scope.rawValue)",
            "scope_id=\(field.scopeID ?? "")",
            "state=\(field.state.rawValue)",
            "reason=\(field.reason ?? "")",
        ]
        if let record = field.record {
            parts.append("record_id=\(record.inferenceID)")
            parts.append("record_schema=\(record.schemaVersion)")
            parts.append("payload=\(relatedSessionSemanticPayloadFingerprint(record.payload))")
            parts.append("supporting_factual=\(record.supportingFactualRevision.map(String.init) ?? "")")
            parts.append("confidence=\(record.confidence.rawValue)")
            parts.append("specificity=\(record.specificity.rawValue)")
            parts.append("producer_type=\(record.producerType.rawValue)")
            parts.append("producer_id=\(record.producerID)")
            parts.append("producer_version=\(record.producerVersion)")
            parts.append("created=\(relatedSessionTimestampFingerprint(record.createdAt))")
            parts.append("status=\(record.status.rawValue)")
            parts.append("supersedes=\(record.supersedes.sorted().joined(separator: ","))")
            parts.append("superseded_by=\(record.supersededBy ?? "")")
            for ref in record.supportingEvidenceRefs.sorted(by: relatedSessionSemanticEvidenceSort) {
                parts.append([
                    "evidence",
                    ref.kind,
                    ref.id,
                    ref.ledgerSequence.map(String.init) ?? "",
                    ref.factualRevision.map(String.init) ?? "",
                ].joined(separator: "|"))
            }
        }
        return parts.joined(separator: "\n")
    }

    func relatedSessionSemanticEvidenceSort(
        _ lhs: ProvenanceSemanticEvidenceReference,
        _ rhs: ProvenanceSemanticEvidenceReference
    ) -> Bool {
        if lhs.kind != rhs.kind { return lhs.kind < rhs.kind }
        if lhs.id != rhs.id { return lhs.id < rhs.id }
        if lhs.ledgerSequence ?? -1 != rhs.ledgerSequence ?? -1 {
            return lhs.ledgerSequence ?? -1 < rhs.ledgerSequence ?? -1
        }
        return lhs.factualRevision ?? -1 < rhs.factualRevision ?? -1
    }

    func relatedSessionSemanticPayloadFingerprint(
        _ payload: ProvenanceSemanticPayloadValue
    ) -> String {
        switch payload {
        case .null:
            return "null"
        case let .bool(value):
            return "bool:\(value)"
        case let .int(value):
            return "int:\(value)"
        case let .double(value):
            return "double:\(value)"
        case let .string(value):
            return "string:\(value.count):\(value)"
        case let .array(values):
            return "array:[\(values.map(relatedSessionSemanticPayloadFingerprint).joined(separator: ","))]"
        case let .object(object):
            let fields = object.keys.sorted().map { key in
                "\(key.count):\(key)=\(relatedSessionSemanticPayloadFingerprint(object[key] ?? .null))"
            }
            return "object:{\(fields.joined(separator: ","))}"
        }
    }
}
