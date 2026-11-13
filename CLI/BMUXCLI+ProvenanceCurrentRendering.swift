import Foundation
import ProvenanceEngineContracts

extension BMUXCLI {
    /// The compact contract trims secondary detail before omitting trailing briefs to fit 12 KiB.
    func printProvenanceCurrentRelated(_ response: ProvenanceRelatedSessionResponse, jsonOutput: Bool) throws {
        guard let projection = response.projection, response.found else {
            printProvenanceCurrentUnavailable(response.reason ?? "no_session", jsonOutput: jsonOutput)
            return
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        func text(_ input: String, limit: Int = 160) -> String {
            input.count > limit ? String(input.prefix(limit)) + "…" : input
        }
        func optional(_ input: String?) -> Any { input.map { text($0) as Any } ?? NSNull() }
        func value<T>(_ input: T?) -> Any { input.map { $0 as Any } ?? NSNull() }
        func fact(_ input: ProvenanceSessionOutcomeTextFact) -> [String: Any] {
            ["id": input.id, "text": text(input.text), "source_turn_id": input.sourceTurnID,
             "turn_revision": input.sourceTurnOutcomeRevisionID, "text_truncated": input.text.count > 160]
        }
        func reference(_ input: ProvenanceRelatedSessionEvidenceReference) -> [String: Any] {
            ["kind": input.kind, "id": input.id, "revision": value(input.projectionRevisionID),
             "sequence": value(input.eventSequence), "field": value(input.field), "source_state": value(input.sourceState),
             "source": value(input.source?.rawValue)]
        }
        func brief(_ item: ProvenanceRelatedSessionBrief) throws -> [String: Any] {
            let outcome = item.outcomeBrief
            let boundary = item.worktreeBoundaries.first
            let prioritySemantics = item.semanticFields.filter { $0.kind == "coding_agent.blockers" || $0.kind == "coding_agent.approach_changes" }
            let remainingSemantics = item.semanticFields.filter { $0.kind != "coding_agent.blockers" && $0.kind != "coding_agent.approach_changes" }
            let semanticFields = try (prioritySemantics + remainingSemantics).prefix(4).map { field -> [String: Any] in
                let payload: String?
                if let record = field.record {
                    payload = String(data: try encoder.encode(record.payload), encoding: .utf8)
                } else {
                    payload = nil
                }
                let refs: [[String: Any]] = (field.record?.supportingEvidenceRefs.prefix(2) ?? []).map {
                    ["kind": $0.kind, "id": $0.id, "sequence": value($0.ledgerSequence),
                     "factual_revision": value($0.factualRevision)]
                }
                let blockerPayload = field.kind == "coding_agent.blockers"
                    ? field.record.flatMap { ProvenanceCodingAgentBlockerPayload(semanticPayloadValue: $0.payload) } : nil
                let blockers: [[String: Any]] = (blockerPayload?.blockers.prefix(2) ?? []).map { blocker in
                    let sourceRefs = blocker.sourceEvidenceRefs.count > 2
                        ? Array(blocker.sourceEvidenceRefs.prefix(1)) + Array(blocker.sourceEvidenceRefs.suffix(1))
                        : blocker.sourceEvidenceRefs
                    let sourceEvidence: [[String: Any]] = sourceRefs.map {
                        ["kind": $0.kind, "id": $0.id, "sequence": value($0.ledgerSequence),
                         "factual_revision": value($0.factualRevision)]
                    }
                    return ["id": blocker.id, "state": blocker.state.rawValue,
                            "condition": text(blocker.condition), "activity": text(blocker.affectedActivity),
                            "condition_truncated": blocker.condition.count > 160,
                            "activity_truncated": blocker.affectedActivity.count > 160,
                            "source_evidence": sourceEvidence,
                            "source_evidence_omitted": max(0, blocker.sourceEvidenceRefs.count - 2)]
                }
                return ["kind": field.kind, "state": field.state.rawValue,
                        "blocker_items": blockers, "blocker_items_omitted": max(0, (blockerPayload?.blockers.count ?? 0) - 2),
                        "reason": value(field.reason), "record_id": value(field.record?.inferenceID),
                        "producer": value(field.record?.producerID), "confidence": value(field.record?.confidence.rawValue),
                        "status": value(field.record?.status.rawValue), "superseded_by": value(field.record?.supersededBy),
                        "evidence": refs, "evidence_omitted": max(0, (field.record?.supportingEvidenceRefs.count ?? 0) - 2),
                        "payload_excerpt": optional(payload), "payload_truncated": (payload?.count ?? 0) > 160]
            }
            let validations: [[String: Any]] = (outcome?.validationsAttempted.prefix(2) ?? []).map {
                ["id": $0.id, "command": text($0.validation.command), "result": $0.validation.resultStatus,
                 "revision": $0.sourceTurnOutcomeRevisionID, "command_truncated": $0.validation.command.count > 160]
            }
            let boundaryFields: [String: Any] = [
                "repository": optional(boundary?.repositoryPath), "worktree": optional(boundary?.worktreePath),
                "branch": optional(boundary?.branch), "head": optional(boundary?.head)
            ]
            let freshnessAge = item.freshness.relationshipObservedAt.map { Date().timeIntervalSince($0) }
            let recency: String
            if let freshnessAge, freshnessAge >= 0 {
                recency = freshnessAge > 24 * 60 * 60 ? "stale" : "recent"
            } else {
                recency = "unknown"
            }
            let freshness: [String: Any] = [
                "state": item.freshness.state, "recency": recency, "stale_after_seconds": 24 * 60 * 60,
                "observed_at": value(item.freshness.relationshipObservedAt?.timeIntervalSince1970),
                "outcome_at": value(item.freshness.sessionOutcomeGeneratedAt?.timeIntervalSince1970)
            ]
            let availability: [[String: Any]] = item.completeness.fields.prefix(8).map {
                ["field": $0.field, "status": $0.status, "reason": value($0.reason)]
            }
            let boundaryTexts = [boundary?.repositoryPath, boundary?.worktreePath, boundary?.branch, boundary?.head]
            let omitted: [String: Any] = [
                "objectives": max(0, (outcome?.objectives.count ?? 0) - 2),
                "blockers": max(0, (outcome?.blockers.count ?? 0) - 2),
                "actions": max(0, (outcome?.actionsCompleted.count ?? 0) - 2),
                "plan_items": outcome?.planItems.count ?? 0, "commands": outcome?.commandsCompleted.count ?? 0,
                "artifacts": outcome?.changedArtifacts.count ?? 0, "unresolved_items": outcome?.unresolvedItems.count ?? 0,
                "resume_point": outcome?.latestResumePoint != nil,
                "validations": max(0, (outcome?.validationsAttempted.count ?? 0) - 2),
                "semantic_fields": max(0, item.semanticFields.count - 4), "evidence": max(0, item.evidence.count - 3),
                "availability": max(0, item.completeness.fields.count - 8),
                "boundaries": max(0, item.worktreeBoundaries.count - 1),
                "boundary_text_truncated": boundaryTexts.contains { ($0?.count ?? 0) > 160 },
                "outcome_fields": outcome?.truncatedFields ?? []
            ]
            return [
                "session_id": item.sessionID, "lifecycle": item.lifecycleState, "completion": item.completionState,
                "reasons": item.relationshipReasons.map { $0.kind.rawValue },
                "match_evidence": item.relationshipReasons.filter {
                    $0.kind == .requestedArtifact || $0.kind == .objectiveTextMatch || $0.kind == .currentWorkspaceTicket
                }.map { reason in
                    let revisionReferences = reason.evidence.filter { $0.projectionRevisionID != nil }
                    let otherReferences = reason.evidence.filter { $0.projectionRevisionID == nil }
                    return ["kind": reason.kind.rawValue, "value": optional(reason.relatedValue),
                            "value_truncated": (reason.relatedValue?.count ?? 0) > 160,
                            "observed_at": value(reason.observedAt?.timeIntervalSince1970),
                            "evidence": (revisionReferences + otherReferences).prefix(3).map(reference),
                            "evidence_omitted": max(0, reason.evidence.count - 3)] as [String: Any]
                }, "boundary": boundaryFields,
                "freshness": freshness, "outcome_revision": value(item.sessionOutcomeRevisionID),
                "objectives": (outcome?.objectives.prefix(2) ?? []).map(fact),
                "blockers": (outcome?.blockers.prefix(2) ?? []).map(fact),
                "actions": (outcome?.actionsCompleted.prefix(2) ?? []).map(fact),
                "validations": validations, "semantic_fields": semanticFields,
                "evidence": item.evidence.prefix(3).map(reference), "completeness": item.completeness.status,
                "outcome_available": outcome != nil, "availability": availability, "omitted": omitted
            ]
        }
        var results = try projection.relatedSessions.map(brief)
        var dropped = 0
        var notes = projection.completeness.notes.map { text($0) }
        var notesOmitted = 0
        var reductionStage = 0
        func reduceFields(_ key: String, retain: Int, omissionKey: String) {
            for index in results.indices {
                guard let fields = results[index][key] as? [[String: Any]], fields.count > retain,
                      var omitted = results[index]["omitted"] as? [String: Any] else { continue }
                omitted[omissionKey] = (omitted[omissionKey] as? Int ?? 0) + fields.count - retain
                results[index][key] = Array(fields.prefix(retain))
                results[index]["omitted"] = omitted
            }
        }
        var payload: [String: Any] = [:]
        var data = Data()
        repeat {
            payload = ["schema_version": 1, "found": true, "target_session_id": projection.targetSessionID,
                       "revision": projection.projection.revisionID,
                       "watermark": value(projection.projection.sourceEvidenceWatermark),
                       "completeness": projection.completeness.status,
                       "projection_availability": projection.completeness.fields.map {
                           ["field": $0.field, "status": $0.status, "reason": value($0.reason)]
                       },
                       "completeness_notes": notes,
                       "completeness_notes_omitted": notesOmitted,
                       "completeness_notes_truncated": notesOmitted > 0 || projection.completeness.notes.contains { $0.count > 160 },
                       "exclusions_retained": projection.excludedCandidates.count,
                       "candidates_omitted_for_limit": value(projection.candidatesOmittedForLimit),
                       "briefs_omitted_for_budget": dropped, "results": results]
            data = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
            if data.count <= 12 * 1024 || results.isEmpty { break }
            switch reductionStage {
            case 0:
                notesOmitted = max(0, notes.count - 2)
                notes = Array(notes.prefix(2))
                reductionStage += 1
            case 1:
                reduceFields("semantic_fields", retain: 2, omissionKey: "semantic_fields")
                reductionStage += 1
            case 2:
                reduceFields("availability", retain: 4, omissionKey: "availability")
                reductionStage += 1
            case 3:
                reduceFields("evidence", retain: 1, omissionKey: "evidence")
                reductionStage += 1
            default:
                results.removeLast()
                dropped += 1
            }
        } while true
        guard data.count <= 12 * 1024, let encoded = String(data: data, encoding: .utf8) else {
            throw CLIError(message: String(localized: "cli.provenance.current.tooLarge", defaultValue: "Current session context exceeds the output budget."))
        }
        if jsonOutput {
            print(encoded)
        } else {
            let metadata = payload.filter { $0.key != "results" }
            let metadataData = try JSONSerialization.data(withJSONObject: metadata, options: [.sortedKeys])
            guard let metadataText = String(data: metadataData, encoding: .utf8) else {
                throw CLIError(message: String(localized: "cli.provenance.current.tooLarge", defaultValue: "Current session context exceeds the output budget."))
            }
            var lines = [String(localized: "cli.provenance.current.header", defaultValue: "Related session context:"), metadataText]
            for result in results {
                let resultData = try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys])
                guard let resultText = String(data: resultData, encoding: .utf8) else {
                    throw CLIError(message: String(localized: "cli.provenance.current.tooLarge", defaultValue: "Current session context exceeds the output budget."))
                }
                lines.append("- " + resultText)
            }
            let output = lines.joined(separator: "\n")
            guard output.utf8.count + 1 <= 16 * 1024 else {
                throw CLIError(message: String(localized: "cli.provenance.current.tooLarge", defaultValue: "Current session context exceeds the output budget."))
            }
            print(output)
        }
    }
}
