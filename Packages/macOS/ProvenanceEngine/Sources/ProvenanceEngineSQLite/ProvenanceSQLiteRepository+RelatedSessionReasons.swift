import Foundation
import ProvenanceEngineContracts

extension ProvenanceSQLiteRepository {
    func relatedSessionReasons(
        target: RelatedSessionProfile,
        candidate: RelatedSessionProfile,
        treeContext: RelatedSessionTreeContext
    ) -> [ProvenanceRelatedSessionRelationshipReason] {
        var reasons: [ProvenanceRelatedSessionRelationshipReason] = []

        for key in target.worktreeKeys.intersection(candidate.worktreeKeys).sorted() {
            reasons.append(relatedSessionReason(
                .sameWorktree,
                key: key,
                targetEvidence: target.worktreeEvidence,
                candidateEvidence: candidate.worktreeEvidence,
                target: target,
                candidate: candidate
            ))
        }

        for key in target.branchKeys.intersection(candidate.branchKeys).sorted() {
            reasons.append(relatedSessionReason(
                .sameBranch,
                key: key,
                targetEvidence: target.branchEvidence,
                candidateEvidence: candidate.branchEvidence,
                target: target,
                candidate: candidate
            ))
        }

        for key in target.repositoryKeys.intersection(candidate.repositoryKeys).sorted() {
            reasons.append(relatedSessionReason(
                .sameRepository,
                key: key,
                targetEvidence: target.repositoryEvidence,
                candidateEvidence: candidate.repositoryEvidence,
                target: target,
                candidate: candidate
            ))
        }

        for key in target.providerThreadKeys.intersection(candidate.providerThreadKeys).sorted() {
            reasons.append(relatedSessionReason(
                .sharedProviderThread,
                key: key,
                targetEvidence: target.providerThreadEvidence,
                candidateEvidence: candidate.providerThreadEvidence,
                target: target,
                candidate: candidate
            ))
        }

        for key in target.externalIdentityKeys.intersection(candidate.externalIdentityKeys).sorted() {
            reasons.append(relatedSessionReason(
                .sharedExternalIdentity,
                key: key,
                targetEvidence: target.externalIdentityEvidence,
                candidateEvidence: candidate.externalIdentityEvidence,
                target: target,
                candidate: candidate
            ))
        }

        if !target.repositoryKeys.intersection(candidate.repositoryKeys).isEmpty
            || !target.worktreeKeys.intersection(candidate.worktreeKeys).isEmpty {
            for key in target.artifactKeys.intersection(candidate.artifactKeys).sorted() {
                reasons.append(relatedSessionReason(
                    .sharedChangedArtifact,
                    key: key,
                    targetEvidence: target.artifactEvidence,
                    candidateEvidence: candidate.artifactEvidence,
                    target: target,
                    candidate: candidate
                ))
            }
        }

        if let path = treeContext.ancestors[candidate.session.id] {
            reasons.append(relatedSessionTreeReason(
                .sessionTreeAncestor,
                target: target.session.id,
                candidate: candidate.session.id,
                path: path
            ))
        }
        if let path = treeContext.descendants[candidate.session.id] {
            reasons.append(relatedSessionTreeReason(
                .sessionTreeDescendant,
                target: target.session.id,
                candidate: candidate.session.id,
                path: path
            ))
        }
        if let path = treeContext.siblings[candidate.session.id] {
            reasons.append(relatedSessionTreeReason(
                .sessionTreeSibling,
                target: target.session.id,
                candidate: candidate.session.id,
                path: path
            ))
        }

        return reasons.sorted(by: relatedSessionReasonSort)
    }

    func relatedSessionReason(
        _ kind: ProvenanceRelatedSessionRelationshipKind,
        key: String,
        targetEvidence: [String: [ProvenanceRelatedSessionEvidenceReference]],
        candidateEvidence: [String: [ProvenanceRelatedSessionEvidenceReference]],
        target: RelatedSessionProfile,
        candidate: RelatedSessionProfile
    ) -> ProvenanceRelatedSessionRelationshipReason {
        let evidence = uniqueRelatedSessionEvidence(
            (targetEvidence[key] ?? []) + (candidateEvidence[key] ?? [])
        )
        return ProvenanceRelatedSessionRelationshipReason(
            kind: kind,
            targetValue: key,
            relatedValue: key,
            evidence: evidence,
            observedAt: maxRelatedSessionDate(target.observedAt[key], candidate.observedAt[key])
        )
    }

    func relatedSessionTreeReason(
        _ kind: ProvenanceRelatedSessionRelationshipKind,
        target: String,
        candidate: String,
        path: RelatedSessionTreePath
    ) -> ProvenanceRelatedSessionRelationshipReason {
        let evidence = uniqueRelatedSessionEvidence(
            path.relationships.map { relatedSessionEvidence($0, field: kind.rawValue) }
        )
        return ProvenanceRelatedSessionRelationshipReason(
            kind: kind,
            targetValue: target,
            relatedValue: candidate,
            relationshipDepth: path.depth,
            evidence: evidence,
            observedAt: path.relationships.map(\.updatedAt).max()
        )
    }

    func relatedSessionBrief(
        profile: RelatedSessionProfile,
        reasons: [ProvenanceRelatedSessionRelationshipReason],
        sourceWatermark: Int?,
        projectionGeneratedAt: Date?
    ) -> ProvenanceRelatedSessionBrief {
        let outcomeBrief = profile.outcome.map(relatedSessionOutcomeBrief)
        let relationshipEvidence = reasons.flatMap(\.evidence)
        let evidence = uniqueRelatedSessionEvidence(
            profile.sourceEvidence + relationshipEvidence + profile.worktreeBoundaries.flatMap(\.evidence)
        )
        let freshness = ProvenanceRelatedSessionFreshness(
            relationshipEvidenceWatermark: sourceWatermark,
            relationshipObservedAt: reasons.compactMap(\.observedAt).max(),
            sessionOutcomeGeneratedAt: profile.outcome?.projection.generatedAt,
            sessionWorkModelLatestSemanticInferenceCreatedAt: profile.workModel?.revision
                .latestSemanticInferenceCreatedAt,
            projectionGeneratedAt: projectionGeneratedAt,
            state: profile.outcome == nil ? "partial" : "available"
        )
        return ProvenanceRelatedSessionBrief(
            sessionID: profile.session.id,
            session: profile.session,
            externalIdentities: profile.externalIdentities,
            providerThreadIdentities: profile.providerThreadIdentities,
            repositoryBoundaries: profile.repositoryBoundaries,
            worktreeBoundaries: profile.worktreeBoundaries,
            lifecycleState: profile.session.status,
            completionState: profile.outcome?.completionState ?? normalizedRelatedSessionCompletionState(profile.session.status),
            sessionOutcomeRevisionID: profile.outcome?.projection.revisionID,
            sessionOutcomeProjection: profile.outcome?.projection,
            outcomeBrief: outcomeBrief,
            relationshipReasons: reasons,
            freshness: freshness,
            semanticFields: profile.semanticFields,
            sessionWorkModelRevision: profile.workModel?.revision,
            evidence: evidence,
            completeness: relatedSessionBriefCompleteness(
                profile: profile,
                reasons: reasons,
                evaluatedThroughSequence: sourceWatermark
            )
        )
    }

    func relatedSessionOutcomeBrief(
        outcome: ProvenanceSessionOutcome
    ) -> ProvenanceRelatedSessionOutcomeBrief {
        var truncatedFields: [String] = []
        return ProvenanceRelatedSessionOutcomeBrief(
            objectives: boundedRelatedSessionItems(outcome.objectives, limit: 2, field: "objectives", truncated: &truncatedFields),
            planItems: boundedRelatedSessionItems(outcome.planItems, limit: 5, field: "plan_items", truncated: &truncatedFields),
            actionsCompleted: boundedRelatedSessionItems(
                outcome.actionsCompleted,
                limit: 5,
                field: "actions_completed",
                truncated: &truncatedFields
            ),
            commandsCompleted: boundedRelatedSessionItems(
                outcome.commandsCompleted,
                limit: 5,
                field: "commands_completed",
                truncated: &truncatedFields
            ),
            changedArtifacts: boundedRelatedSessionItems(
                outcome.changedArtifacts,
                limit: 10,
                field: "changed_artifacts",
                truncated: &truncatedFields
            ),
            validationsAttempted: boundedRelatedSessionItems(
                outcome.validationsAttempted,
                limit: 5,
                field: "validations_attempted",
                truncated: &truncatedFields
            ),
            blockers: boundedRelatedSessionItems(outcome.blockers, limit: 5, field: "blockers", truncated: &truncatedFields),
            unresolvedItems: boundedRelatedSessionItems(
                outcome.unresolvedItems,
                limit: 5,
                field: "unresolved_items",
                truncated: &truncatedFields
            ),
            latestResumePoint: outcome.latestResumePoint,
            truncatedFields: truncatedFields
        )
    }

    func relatedSessionProjectionCompleteness(
        target: RelatedSessionProfile,
        relatedSessions: [ProvenanceRelatedSessionBrief],
        excludedCandidates: [ProvenanceRelatedSessionCandidateExclusion],
        evaluatedThroughSequence: Int?
    ) -> ProvenanceRelatedSessionCompleteness {
        let fields = [
            relatedSessionAvailability(
                field: "target_session_outcome",
                observed: target.outcome != nil,
                reason: "no_target_session_outcome",
                evidence: target.outcome.map { [relatedSessionEvidence($0)] } ?? []
            ),
            relatedSessionAvailability(
                field: "target_session_work_model",
                observed: target.workModel != nil,
                reason: "no_target_session_work_model",
                evidence: target.workModel.map { [relatedSessionEvidence($0)] } ?? []
            ),
            relatedSessionAvailability(
                field: "related_sessions",
                observed: !relatedSessions.isEmpty,
                reason: "no_related_sessions"
            ),
            relatedSessionAvailability(
                field: "candidate_exclusions",
                observed: !excludedCandidates.isEmpty,
                reason: "no_excluded_candidates"
            ),
        ]
        let status = relatedSessions.isEmpty ? "empty" : (fields.allSatisfy { $0.status == "observed" } ? "complete" : "partial")
        return ProvenanceRelatedSessionCompleteness(
            status: status,
            evaluatedThroughSequence: evaluatedThroughSequence,
            fields: fields,
            notes: relatedSessionCompletenessNotes()
        )
    }

    func relatedSessionBriefCompleteness(
        profile: RelatedSessionProfile,
        reasons: [ProvenanceRelatedSessionRelationshipReason],
        evaluatedThroughSequence: Int?
    ) -> ProvenanceRelatedSessionCompleteness {
        let fields = [
            relatedSessionAvailability(
                field: "relationship_reasons",
                observed: !reasons.isEmpty,
                reason: "no_relationship_reason",
                evidence: reasons.flatMap(\.evidence)
            ),
            relatedSessionAvailability(
                field: "session_outcome",
                observed: profile.outcome != nil,
                reason: "no_session_outcome",
                evidence: profile.outcome.map { [relatedSessionEvidence($0)] } ?? []
            ),
            relatedSessionAvailability(
                field: "worktree_boundaries",
                observed: !profile.worktreeBoundaries.isEmpty,
                reason: "no_repository_worktree_or_branch_evidence",
                evidence: profile.worktreeBoundaries.flatMap(\.evidence)
            ),
            relatedSessionAvailability(
                field: "provider_identity",
                observed: !profile.providerThreadIdentities.isEmpty || !profile.externalIdentities.isEmpty,
                reason: "no_provider_or_external_identity"
            ),
            relatedSessionAvailability(
                field: "semantic_fields",
                observed: !profile.semanticFields.isEmpty,
                reason: "no_active_session_work_model_semantic_fields",
                evidence: profile.workModel.map { [relatedSessionEvidence($0)] } ?? []
            ),
        ] + profile.semanticFields.map {
            relatedSessionSemanticAvailability(field: $0, workModel: profile.workModel)
        }
        return ProvenanceRelatedSessionCompleteness(
            status: fields.allSatisfy { $0.status == "observed" } ? "complete" : "partial",
            evaluatedThroughSequence: evaluatedThroughSequence,
            fields: fields,
            notes: relatedSessionCompletenessNotes()
        )
    }

    func relatedSessionAvailability(
        field: String,
        observed: Bool,
        reason: String,
        evidence: [ProvenanceRelatedSessionEvidenceReference] = []
    ) -> ProvenanceRelatedSessionAvailability {
        ProvenanceRelatedSessionAvailability(
            field: field,
            status: observed ? "observed" : "not_observed",
            reason: observed ? nil : reason,
            evidence: evidence
        )
    }
}
