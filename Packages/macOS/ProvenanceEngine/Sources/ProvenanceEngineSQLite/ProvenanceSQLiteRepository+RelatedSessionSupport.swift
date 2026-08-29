import Foundation
import ProvenanceEngineContracts

extension ProvenanceSQLiteRepository {
    func relatedSessionEvidence(
        _ outcome: ProvenanceSessionOutcome
    ) -> ProvenanceRelatedSessionEvidenceReference {
        ProvenanceRelatedSessionEvidenceReference(
            kind: "session_outcome",
            id: outcome.sessionID,
            projectionRevisionID: outcome.projection.revisionID,
            projectionWatermark: outcome.projection.sourceEvidenceWatermark,
            field: "session_outcome"
        )
    }

    func relatedSessionEvidence(
        _ workModel: ProvenanceSessionWorkModel
    ) -> ProvenanceRelatedSessionEvidenceReference {
        ProvenanceRelatedSessionEvidenceReference(
            kind: "session_work_model",
            id: workModel.identity.session.id,
            projectionRevisionID: workModel.revision.modelRevisionKey,
            projectionWatermark: workModel.revision.factualRevision,
            field: "session_work_model"
        )
    }

    func relatedSessionEvidence(
        _ repository: ProvenanceRepositoryRecord
    ) -> ProvenanceRelatedSessionEvidenceReference {
        ProvenanceRelatedSessionEvidenceReference(
            kind: "repository",
            id: repository.id,
            field: "repository"
        )
    }

    func relatedSessionEvidence(
        _ worktree: ProvenanceWorktreeRecord
    ) -> ProvenanceRelatedSessionEvidenceReference {
        ProvenanceRelatedSessionEvidenceReference(
            kind: "worktree",
            id: worktree.id,
            field: "worktree"
        )
    }

    func relatedSessionEvidence(
        _ thread: ProvenanceFactualSessionProjectionProviderThreadIdentity
    ) -> ProvenanceRelatedSessionEvidenceReference {
        ProvenanceRelatedSessionEvidenceReference(
            kind: "provider_thread",
            id: thread.threadID,
            field: "provider_thread"
        )
    }

    func relatedSessionEvidence(
        _ identity: ProvenanceExternalIdentityRecord
    ) -> ProvenanceRelatedSessionEvidenceReference {
        ProvenanceRelatedSessionEvidenceReference(
            kind: "external_identity",
            id: identity.id,
            field: "external_identity"
        )
    }

    func relatedSessionEvidence(
        _ relationship: ProvenanceSessionRelationshipRecord,
        field: String
    ) -> ProvenanceRelatedSessionEvidenceReference {
        ProvenanceRelatedSessionEvidenceReference(
            kind: "session_relationship",
            id: relationship.sessionID,
            field: field,
            sourceState: relationship.source.rawValue
        )
    }

    func relatedSessionEvidence(
        _ evidence: [ProvenanceTurnOutcomeEvidenceReference]
    ) -> [ProvenanceRelatedSessionEvidenceReference] {
        evidence.map { item in
            ProvenanceRelatedSessionEvidenceReference(
                kind: "event",
                id: item.eventID,
                eventSequence: item.eventSequence,
                eventType: item.eventType,
                field: "\(item.recordKind):\(item.recordID)",
                sourceState: item.sourceState
            )
        }
    }

    func appendRelatedSessionEvidence(
        _ evidence: [ProvenanceRelatedSessionEvidenceReference],
        for key: String,
        to dictionary: inout [String: [ProvenanceRelatedSessionEvidenceReference]]
    ) {
        dictionary[key] = uniqueRelatedSessionEvidence((dictionary[key] ?? []) + evidence)
    }

    func appendRelatedSessionExclusion(
        _ exclusion: ProvenanceRelatedSessionCandidateExclusion,
        limit: Int,
        to exclusions: inout [ProvenanceRelatedSessionCandidateExclusion]
    ) throws {
        guard exclusions.count < limit else { return }
        exclusions.append(exclusion)
    }

    func uniqueRelatedSessionEvidence(
        _ evidence: [ProvenanceRelatedSessionEvidenceReference]
    ) -> [ProvenanceRelatedSessionEvidenceReference] {
        var seen = Set<String>()
        let sortedEvidence = evidence.sorted(by: relatedSessionEvidenceSort)
        return sortedEvidence.filter { item in
            let key = relatedSessionEvidenceIdentityKey(item)
            return seen.insert(key).inserted
        }
    }

    func relatedSessionEvidenceIdentityKey(
        _ item: ProvenanceRelatedSessionEvidenceReference
    ) -> String {
        let eventSequence = item.eventSequence.map(String.init) ?? ""
        let projectionWatermark = item.projectionWatermark.map(String.init) ?? ""
        return [
            item.kind,
            item.id,
            eventSequence,
            item.eventType ?? "",
            item.projectionRevisionID ?? "",
            projectionWatermark,
            item.field ?? "",
            item.sourceState ?? "",
        ].joined(separator: "|")
    }

    func uniqueRelatedSessionBoundaries(
        _ boundaries: [ProvenanceRelatedSessionWorktreeBoundary]
    ) -> [ProvenanceRelatedSessionWorktreeBoundary] {
        var seen = Set<String>()
        return boundaries.sorted { lhs, rhs in
            if lhs.repositoryID ?? "" != rhs.repositoryID ?? "" { return lhs.repositoryID ?? "" < rhs.repositoryID ?? "" }
            if lhs.repositoryPath ?? "" != rhs.repositoryPath ?? "" { return lhs.repositoryPath ?? "" < rhs.repositoryPath ?? "" }
            if lhs.worktreeID ?? "" != rhs.worktreeID ?? "" { return lhs.worktreeID ?? "" < rhs.worktreeID ?? "" }
            if lhs.worktreePath ?? "" != rhs.worktreePath ?? "" { return lhs.worktreePath ?? "" < rhs.worktreePath ?? "" }
            if lhs.branch ?? "" != rhs.branch ?? "" { return lhs.branch ?? "" < rhs.branch ?? "" }
            return lhs.id < rhs.id
        }.filter { boundary in
            let key = [
                boundary.repositoryID ?? "",
                boundary.repositoryPath ?? "",
                boundary.worktreeID ?? "",
                boundary.worktreePath ?? "",
                boundary.branch ?? "",
                boundary.head ?? "",
                boundary.cwd ?? "",
            ].joined(separator: "|")
            return seen.insert(key).inserted
        }
    }

    func relatedSessionCandidateSort(
        _ lhs: RelatedSessionCandidateBrief,
        _ rhs: RelatedSessionCandidateBrief
    ) -> Bool {
        if lhs.relationshipStrength != rhs.relationshipStrength {
            return lhs.relationshipStrength > rhs.relationshipStrength
        }
        if lhs.freshnessDate != rhs.freshnessDate {
            return lhs.freshnessDate > rhs.freshnessDate
        }
        return lhs.brief.sessionID < rhs.brief.sessionID
    }

    func relatedSessionReasonSort(
        _ lhs: ProvenanceRelatedSessionRelationshipReason,
        _ rhs: ProvenanceRelatedSessionRelationshipReason
    ) -> Bool {
        let lhsPriority = relatedSessionReasonPriority(lhs.kind)
        let rhsPriority = relatedSessionReasonPriority(rhs.kind)
        if lhsPriority != rhsPriority { return lhsPriority > rhsPriority }
        if lhs.kind.rawValue != rhs.kind.rawValue { return lhs.kind.rawValue < rhs.kind.rawValue }
        if lhs.targetValue ?? "" != rhs.targetValue ?? "" { return lhs.targetValue ?? "" < rhs.targetValue ?? "" }
        if lhs.relatedValue ?? "" != rhs.relatedValue ?? "" { return lhs.relatedValue ?? "" < rhs.relatedValue ?? "" }
        return lhs.relationshipDepth ?? 0 < rhs.relationshipDepth ?? 0
    }

    func relatedSessionEvidenceSort(
        _ lhs: ProvenanceRelatedSessionEvidenceReference,
        _ rhs: ProvenanceRelatedSessionEvidenceReference
    ) -> Bool {
        if lhs.eventSequence ?? -1 != rhs.eventSequence ?? -1 {
            return lhs.eventSequence ?? -1 < rhs.eventSequence ?? -1
        }
        if lhs.kind != rhs.kind { return lhs.kind < rhs.kind }
        if lhs.id != rhs.id { return lhs.id < rhs.id }
        if lhs.projectionRevisionID ?? "" != rhs.projectionRevisionID ?? "" {
            return lhs.projectionRevisionID ?? "" < rhs.projectionRevisionID ?? ""
        }
        return lhs.field ?? "" < rhs.field ?? ""
    }

    func relatedSessionReasonPriority(
        _ kind: ProvenanceRelatedSessionRelationshipKind
    ) -> Int {
        switch kind {
        case .sameWorktree:
            return 100
        case .sessionTreeAncestor, .sessionTreeDescendant:
            return 95
        case .sharedProviderThread:
            return 90
        case .sessionTreeSibling:
            return 85
        case .sameBranch:
            return 80
        case .sharedChangedArtifact:
            return 70
        case .sameRepository:
            return 60
        case .sharedExternalIdentity:
            return 50
        }
    }

    func relatedSessionContentFingerprint(
        requestFingerprint: String,
        target: RelatedSessionProfile,
        relatedSessions: [ProvenanceRelatedSessionBrief],
        excludedCandidates: [ProvenanceRelatedSessionCandidateExclusion]
    ) -> String {
        var parts = [
            "schema=1",
            "request=\(requestFingerprint)",
            "target=\(target.session.id)",
            "target_status=\(target.session.status)",
            "target_worktree=\(target.session.worktreeID ?? "")",
            "target_cwd=\(target.session.cwd ?? "")",
            "target_outcome=\(target.outcome?.projection.revisionID ?? "")",
            "target_work_model_semantic=\(relatedSessionSemanticRevisionFingerprint(target.workModel?.revision))",
        ]
        for brief in relatedSessions {
            parts.append("related|\(brief.sessionID)|\(brief.lifecycleState)|\(brief.completionState)")
            parts.append("related_worktree|\(brief.session.worktreeID ?? "")")
            parts.append("related_cwd|\(brief.session.cwd ?? "")")
            parts.append("outcome|\(brief.sessionOutcomeRevisionID ?? "")")
            parts.append("work_model_semantic|\(relatedSessionSemanticRevisionFingerprint(brief.sessionWorkModelRevision))")
            for identity in brief.externalIdentities {
                parts.append("external_identity|\(identity.system)|\(identity.kind)|\(identity.externalID)")
            }
            for thread in brief.providerThreadIdentities {
                parts.append("provider_thread|\(thread.provider)|\(thread.providerThreadID)")
            }
            for boundary in brief.worktreeBoundaries {
                parts.append([
                    "boundary",
                    boundary.repositoryID ?? "",
                    boundary.repositoryPath ?? "",
                    boundary.worktreeID ?? "",
                    boundary.worktreePath ?? "",
                    boundary.branch ?? "",
                    boundary.head ?? "",
                    boundary.cwd ?? "",
                ].joined(separator: "|"))
            }
            for reason in brief.relationshipReasons {
                parts.append([
                    "reason",
                    reason.kind.rawValue,
                    reason.targetValue ?? "",
                    reason.relatedValue ?? "",
                    reason.relationshipDepth.map(String.init) ?? "",
                ].joined(separator: "|"))
            }
            for field in brief.completeness.fields {
                parts.append("availability|\(field.field)|\(field.status)|\(field.reason ?? "")")
            }
            for field in brief.outcomeBrief?.truncatedFields ?? [] {
                parts.append("truncated|\(field)")
            }
        }
        for exclusion in excludedCandidates {
            parts.append("excluded|\(exclusion.sessionID ?? "")|\(exclusion.reason)")
        }
        return stableIDFactory.id(
            prefix: "related-session-fingerprint",
            value: parts.joined(separator: "\n")
        )
    }

    func relatedSessionSemanticRevisionFingerprint(
        _ revision: ProvenanceSessionWorkModelRevision?
    ) -> String {
        guard let revision else { return "" }
        return [
            "schema=\(revision.schemaVersion)",
            "semantic=\(revision.semanticInferenceIDs.sorted().joined(separator: ","))",
            "semantic_latest=\(relatedSessionTimestampFingerprint(revision.latestSemanticInferenceCreatedAt))",
        ].joined(separator: "|")
    }

    func relatedSessionRequestFingerprint(
        limit: Int,
        updatedAfter: Date?,
        exclusionLimit: Int
    ) -> String {
        stableIDFactory.id(
            prefix: "related-session-request",
            value: [
                "schema=1",
                "limit=\(limit)",
                "updated_after=\(relatedSessionTimestampFingerprint(updatedAfter))",
                "exclusion_limit=\(exclusionLimit)",
            ].joined(separator: "\n")
        )
    }

    func relatedSessionFreshnessDate(
        session: ProvenanceSessionRecord,
        outcome: ProvenanceSessionOutcome?,
        workModel: ProvenanceSessionWorkModel?
    ) -> Date {
        [
            session.updatedAt,
            workModel?.revision.latestSemanticInferenceCreatedAt,
        ].compactMap { $0 }.max() ?? session.updatedAt
    }

    func normalizedRelatedSessionCompletionState(_ status: String) -> String {
        let normalized = status.lowercased()
        if normalized.contains("cancel") { return "cancelled" }
        if normalized.contains("interrupt") { return "interrupted" }
        if normalized.contains("fail") || normalized.contains("error") { return "failed" }
        if normalized.contains("incomplete") { return "incomplete" }
        if normalized.contains("complete")
            || normalized.contains("success")
            || normalized == "done"
            || normalized == "finished"
            || normalized == "stopped"
            || normalized == "closed" {
            return "completed"
        }
        if normalized.contains("active")
            || normalized.contains("running")
            || normalized.contains("started")
            || normalized.contains("progress") {
            return "incomplete"
        }
        return "unknown"
    }

    func normalizedRelatedSessionValue(_ value: String?) -> String? {
        let normalized = value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized?.isEmpty == false ? normalized : nil
    }

    func boundedRelatedSessionItems<T>(
        _ items: [T],
        limit: Int,
        field: String,
        truncated: inout [String]
    ) -> [T] {
        guard items.count > limit else { return items }
        truncated.append(field)
        return Array(items.prefix(limit))
    }

    func maxRelatedSessionDate(_ lhs: Date?, _ rhs: Date?) -> Date? {
        switch (lhs, rhs) {
        case let (lhs?, rhs?):
            return max(lhs, rhs)
        case let (lhs?, nil):
            return lhs
        case let (nil, rhs?):
            return rhs
        case (nil, nil):
            return nil
        }
    }

    func relatedSessionTimestampFingerprint(_ date: Date?) -> String {
        guard let date else { return "" }
        return String(Int64((date.timeIntervalSince1970 * 1_000_000).rounded()))
    }

    func relatedSessionCompletenessNotes() -> [String] {
        [
            "related-session relationships are deterministic facts or existing projections, not semantic relevance scores",
            "SessionWorkModel semantic fields are exposed only with existing semantic provenance and are not relationship reasons",
            "outcome briefs are bounded slices of Session Outcome facts and never include whole transcripts",
        ]
    }
}
