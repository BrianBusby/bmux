import Foundation
import ProvenanceEngineContracts

extension ProvenanceSQLiteRepository {
    static let relatedSessionRuleID = "deterministic_related_sessions"
    static let relatedSessionRuleVersion = "1"

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
        let resultLimit = max(0, request.limit)
        let exclusionLimit = max(0, request.exclusionLimit)
        let latestSequence = try relatedSessionLatestLedgerSequence()
        let generatedAt = try relatedSessionEventTimestamp(sequence: latestSequence)
        let requestFingerprint = relatedSessionRequestFingerprint(
            limit: resultLimit,
            updatedAfter: request.updatedAfter,
            exclusionLimit: exclusionLimit
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

            let reasons = relatedSessionReasons(
                target: targetProfile,
                candidate: candidateProfile,
                treeContext: treeContext
            )
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
        let contentFingerprint = relatedSessionContentFingerprint(
            requestFingerprint: requestFingerprint,
            target: targetProfile,
            relatedSessions: Array(relatedSessions),
            excludedCandidates: exclusions
        )
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
        let completeness = relatedSessionProjectionCompleteness(
            target: targetProfile,
            relatedSessions: Array(relatedSessions),
            excludedCandidates: exclusions,
            evaluatedThroughSequence: latestSequence
        )
        return ProvenanceRelatedSessionProjection(
            targetSessionID: request.targetSessionID,
            targetSession: targetProfile.session,
            targetSessionOutcomeProjection: targetProfile.outcome?.projection,
            targetSessionWorkModelRevision: targetProfile.workModel?.revision,
            projection: metadata,
            relatedSessions: Array(relatedSessions),
            excludedCandidates: exclusions,
            completeness: completeness
        )
    }
}
