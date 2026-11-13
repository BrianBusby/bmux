import Foundation
import ProvenanceEngineContracts

extension ProvenanceSQLiteRepository {
    static let relatedSessionRuleID = "deterministic_related_sessions"
    static let relatedSessionRuleVersion = "2"

    func relatedSessionRecord(_ request: ProvenanceRelatedSessionRequest) throws
        -> ProvenanceRelatedSessionResponse {
        guard try session(id: request.targetSessionID) != nil else {
            return ProvenanceRelatedSessionResponse(
                found: false,
                reason: "no_session",
                targetSessionID: request.targetSessionID,
                projection: nil
            )
        }

        if let revisionID = request.revisionID {
            return try relatedSessionRevisionResponse(
                targetSessionID: request.targetSessionID,
                revisionID: revisionID
            )
        }

        let projection = try projectedRelatedSessions(request)
        let projectionData = try payloadEncoder.encode(projection)
        guard let projectionJSON = String(data: projectionData, encoding: .utf8) else {
            throw ProvenanceSQLiteError.sqlite(message: "failed to encode related-session projection")
        }

        try insertRelatedSessionRevision(projection, projectionJSON: projectionJSON)
        try upsertLatestRelatedSession(projection)
        return ProvenanceRelatedSessionResponse(
            found: true,
            targetSessionID: request.targetSessionID,
            projection: projection
        )
    }

    func projectedRelatedSessions(
        _ request: ProvenanceRelatedSessionRequest
    ) throws -> ProvenanceRelatedSessionProjection {
        if let path = request.artifactPath {
            let components = path.split(separator: "/", omittingEmptySubsequences: false)
            guard !path.isEmpty, !path.hasPrefix("/"),
                  components.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }) else {
                throw ProvenanceSQLiteError.sqlite(message: "invalid repository-relative artifact path")
            }
        }
        if let objective = request.objective, objective.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ProvenanceSQLiteError.sqlite(message: "invalid objective text")
        }
        if let ticket = request.ticket, ticket.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ProvenanceSQLiteError.sqlite(message: "invalid ticket ID")
        }
        let resultLimit = max(0, request.limit)
        let exclusionLimit = max(0, request.exclusionLimit)
        let latestSequence = try relatedSessionLatestLedgerSequence()
        let generatedAt = try relatedSessionEventTimestamp(sequence: latestSequence)
        let requestFingerprint = relatedSessionRequestFingerprint(
            limit: resultLimit,
            updatedAfter: request.updatedAfter,
            exclusionLimit: exclusionLimit,
            artifactPath: request.artifactPath,
            objective: request.objective,
            ticket: request.ticket
        )
        let target = try relatedSessionProfile(sessionID: request.targetSessionID)
        let targetProfile = try requireRelatedSessionProfile(target, sessionID: request.targetSessionID)
        let treeContext = try relatedSessionTreeContext(targetSessionID: request.targetSessionID)
        var candidates: [RelatedSessionCandidateBrief] = []
        var exclusions: [ProvenanceRelatedSessionCandidateExclusion] = []

        for candidateID in try relatedSessionCandidateSessionIDs(excluding: request.targetSessionID) {
            guard let candidateProfile = try relatedSessionProfile(sessionID: candidateID) else {
                try appendRelatedSessionExclusion(
                    ProvenanceRelatedSessionCandidateExclusion(
                        sessionID: candidateID,
                        reason: "missing_session_projection",
                        evidence: []
                    ),
                    limit: exclusionLimit,
                    to: &exclusions
                )
                continue
            }

            var reasons = relatedSessionReasons(
                target: targetProfile,
                candidate: candidateProfile,
                treeContext: treeContext
            )
            if let path = request.artifactPath {
                let key = relatedSessionArtifactKey(path)
                guard !targetProfile.repositoryKeys.intersection(candidateProfile.repositoryKeys).isEmpty,
                      candidateProfile.artifactKeys.contains(key) else { continue }
                reasons.append(ProvenanceRelatedSessionRelationshipReason(
                    kind: .requestedArtifact, targetValue: path, relatedValue: path,
                    evidence: candidateProfile.artifactEvidence[key] ?? [],
                    observedAt: candidateProfile.observedAt[key]
                ))
                reasons.sort(by: relatedSessionReasonSort)
            }
            if let objective = request.objective {
                guard !targetProfile.repositoryKeys.intersection(candidateProfile.repositoryKeys).isEmpty,
                      let outcome = candidateProfile.outcome else { continue }
                let matches = outcome.objectives.filter {
                    $0.text.range(of: objective, options: [.caseInsensitive, .literal]) != nil
                }
                guard !matches.isEmpty else { continue }
                let evidence = uniqueRelatedSessionEvidence(
                    matches.flatMap { relatedSessionEvidence($0.evidence) } + [relatedSessionEvidence(outcome)]
                )
                reasons.append(ProvenanceRelatedSessionRelationshipReason(
                    kind: .objectiveTextMatch, targetValue: objective, relatedValue: objective,
                    evidence: evidence, observedAt: outcome.projection.generatedAt
                ))
                reasons.sort(by: relatedSessionReasonSort)
            }
            if let ticket = request.ticket {
                guard !targetProfile.repositoryKeys.intersection(candidateProfile.repositoryKeys).isEmpty,
                      let reason = try relatedSessionCurrentTicketReason(ticket, candidate: candidateProfile) else { continue }
                reasons.append(reason)
                reasons.sort(by: relatedSessionReasonSort)
            }
            guard !reasons.isEmpty else { continue }

            if let updatedAfter = request.updatedAfter,
               candidateProfile.freshnessDate < updatedAfter {
                try appendRelatedSessionExclusion(
                    ProvenanceRelatedSessionCandidateExclusion(
                        sessionID: candidateID,
                        reason: "outside_recent_boundary",
                        evidence: [
                            ProvenanceRelatedSessionEvidenceReference(
                                kind: "session",
                                id: candidateID,
                                field: "updated_at"
                            ),
                        ]
                    ),
                    limit: exclusionLimit,
                    to: &exclusions
                )
                continue
            }

            let brief = relatedSessionBrief(
                profile: candidateProfile,
                reasons: reasons,
                sourceWatermark: latestSequence,
                projectionGeneratedAt: generatedAt
            )
            candidates.append(RelatedSessionCandidateBrief(
                brief: brief,
                relationshipStrength: reasons.map { relatedSessionReasonPriority($0.kind) }.max() ?? 0,
                freshnessDate: candidateProfile.freshnessDate
            ))
        }

        let sortedCandidates = candidates.sorted(by: relatedSessionCandidateSort)
        let relatedSessions = sortedCandidates.prefix(resultLimit).map(\.brief)
        for candidate in sortedCandidates.dropFirst(resultLimit) {
            try appendRelatedSessionExclusion(
                ProvenanceRelatedSessionCandidateExclusion(
                    sessionID: candidate.brief.sessionID,
                    reason: "result_limit",
                    evidence: uniqueRelatedSessionEvidence(candidate.brief.relationshipReasons.flatMap(\.evidence))
                ),
                limit: exclusionLimit,
                to: &exclusions
            )
        }
        let hasSelectors = request.artifactPath != nil || request.objective != nil || request.ticket != nil
        let omittedCount = max(0, sortedCandidates.count - resultLimit)
        let baseContentFingerprint = relatedSessionContentFingerprint(
            requestFingerprint: requestFingerprint,
            target: targetProfile,
            relatedSessions: Array(relatedSessions),
            excludedCandidates: exclusions
        )
        let contentFingerprint = hasSelectors
            ? stableIDFactory.id(prefix: "related-session-content", value: "\(baseContentFingerprint)\nomitted=\(omittedCount)")
            : baseContentFingerprint
        let revisionID = stableIDFactory.id(
            prefix: "related-session-revision",
            value: [
                request.targetSessionID,
                Self.relatedSessionRuleID,
                Self.relatedSessionRuleVersion,
                requestFingerprint,
                contentFingerprint,
            ].joined(separator: "\n")
        )
        let metadata = ProvenanceRelatedSessionProjectionMetadata(
            revisionID: revisionID,
            projectionRuleID: Self.relatedSessionRuleID,
            projectionRuleVersion: Self.relatedSessionRuleVersion,
            requestFingerprint: requestFingerprint,
            contentFingerprint: contentFingerprint,
            resultLimit: resultLimit,
            exclusionLimit: exclusionLimit,
            updatedAfter: request.updatedAfter,
            sourceEvidenceWatermark: latestSequence,
            generatedAt: generatedAt ?? targetProfile.session.updatedAt
        )
        let baseCompleteness = relatedSessionProjectionCompleteness(
            target: targetProfile,
            relatedSessions: Array(relatedSessions),
            excludedCandidates: exclusions,
            evaluatedThroughSequence: latestSequence
        )
        let completeness: ProvenanceRelatedSessionCompleteness
        if hasSelectors {
            let reason = targetProfile.repositoryKeys.isEmpty
                ? "target_repository_unavailable" : "task_evidence_coverage_unknown"
            completeness = ProvenanceRelatedSessionCompleteness(
                status: relatedSessions.isEmpty ? "empty" : "partial", evaluatedThroughSequence: latestSequence,
                fields: baseCompleteness.fields + [.init(field: "task_selector_evidence", status: "partial", reason: reason)],
                notes: baseCompleteness.notes + [
                    "task selectors require all supplied conditions within the caller's repository; missing source metadata may hide matches",
                    "ticket matches describe current workspace metadata; its validity during a historical session is unknown",
                ]
            )
        } else {
            completeness = baseCompleteness
        }
        return ProvenanceRelatedSessionProjection(
            targetSessionID: request.targetSessionID,
            targetSession: targetProfile.session,
            targetSessionOutcomeProjection: targetProfile.outcome?.projection,
            targetSessionWorkModelRevision: targetProfile.workModel?.revision,
            projection: metadata,
            relatedSessions: Array(relatedSessions),
            excludedCandidates: exclusions,
            candidatesOmittedForLimit: hasSelectors ? omittedCount : nil,
            completeness: completeness
        )
    }
}
