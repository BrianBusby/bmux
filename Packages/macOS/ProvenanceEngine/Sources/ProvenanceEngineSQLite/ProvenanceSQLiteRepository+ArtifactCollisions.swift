import Foundation
import ProvenanceEngineContracts

extension ProvenanceSQLiteRepository {
    static let artifactCollisionRuleID = "deterministic_artifact_collision_awareness"
    static let artifactCollisionRuleVersion = "1"

    func artifactCollisionRecord(_ request: ProvenanceArtifactCollisionRequest) throws
        -> ProvenanceArtifactCollisionResponse {
        guard try session(id: request.targetSessionID) != nil else {
            return ProvenanceArtifactCollisionResponse(
                found: false,
                reason: "no_session",
                targetSessionID: request.targetSessionID,
                projection: nil
            )
        }

        if let revisionID = request.revisionID {
            return try artifactCollisionRevisionResponse(
                targetSessionID: request.targetSessionID,
                revisionID: revisionID
            )
        }

        let projection = try projectedArtifactCollisions(request)
        let projectionData = try payloadEncoder.encode(projection)
        guard let projectionJSON = String(data: projectionData, encoding: .utf8) else {
            throw ProvenanceSQLiteError.sqlite(message: "failed to encode artifact-collision projection")
        }

        try insertArtifactCollisionRevision(projection, projectionJSON: projectionJSON)
        try upsertLatestArtifactCollision(projection)
        return ProvenanceArtifactCollisionResponse(
            found: true,
            targetSessionID: request.targetSessionID,
            projection: projection
        )
    }

    func projectedArtifactCollisions(
        _ request: ProvenanceArtifactCollisionRequest
    ) throws -> ProvenanceArtifactCollisionProjection {
        let resultLimit = max(0, request.limit)
        let relatedSessionLimit = max(0, request.relatedSessionLimit)
        let exclusionLimit = max(0, request.exclusionLimit)
        let normalizedArtifactPath = normalizedArtifactCollisionPath(request.artifactPath)
        let latestSequence = try relatedSessionLatestLedgerSequence()
        let generatedAt = try relatedSessionEventTimestamp(sequence: latestSequence)
        let requestFingerprint = artifactCollisionRequestFingerprint(
            limit: resultLimit,
            relatedSessionLimit: relatedSessionLimit,
            exclusionLimit: exclusionLimit,
            artifactPath: request.artifactPath,
            normalizedArtifactPath: normalizedArtifactPath,
            updatedAfter: request.updatedAfter,
            staleBefore: request.staleBefore
        )

        let targetProfile = try requireRelatedSessionProfile(
            relatedSessionProfile(sessionID: request.targetSessionID),
            sessionID: request.targetSessionID
        )
        let targetObservation = try artifactCollisionObservation(profile: targetProfile)
        let relatedProjection = try relatedSessionRecord(
            ProvenanceRelatedSessionRequest(
                targetSessionID: request.targetSessionID,
                limit: relatedSessionLimit,
                updatedAfter: nil,
                exclusionLimit: exclusionLimit
            )
        ).projection

        var exclusions: [ProvenanceArtifactCollisionCandidateExclusion] = []
        if request.artifactPath != nil, normalizedArtifactPath == nil {
            appendArtifactCollisionExclusion(
                ProvenanceArtifactCollisionCandidateExclusion(
                    artifactPath: request.artifactPath,
                    reason: "invalid_artifact_path"
                ),
                limit: exclusionLimit,
                to: &exclusions
            )
        }
        if targetProfile.outcome == nil {
            appendArtifactCollisionExclusion(
                ProvenanceArtifactCollisionCandidateExclusion(
                    sessionID: targetProfile.session.id,
                    reason: "missing_target_session_outcome"
                ),
                limit: exclusionLimit,
                to: &exclusions
            )
        }
        if targetObservation.artifactsByPath.isEmpty {
            appendArtifactCollisionExclusion(
                ProvenanceArtifactCollisionCandidateExclusion(
                    sessionID: targetProfile.session.id,
                    reason: "no_target_changed_artifacts",
                    evidence: targetProfile.outcome.map { [artifactCollisionEvidence($0)] } ?? []
                ),
                limit: exclusionLimit,
                to: &exclusions
            )
        }

        var relatedObservations: [ArtifactCollisionSessionObservation] = []
        for brief in relatedProjection?.relatedSessions ?? [] {
            guard let relatedProfile = try relatedSessionProfile(sessionID: brief.sessionID) else {
                appendArtifactCollisionExclusion(
                    ProvenanceArtifactCollisionCandidateExclusion(
                        sessionID: brief.sessionID,
                        reason: "missing_related_session_projection",
                        evidence: artifactCollisionEvidence(brief.evidence, sessionID: brief.sessionID)
                    ),
                    limit: exclusionLimit,
                    to: &exclusions
                )
                continue
            }
            relatedObservations.append(try artifactCollisionObservation(profile: relatedProfile))
        }

        var drafts: [ArtifactCollisionCandidateDraft] = []
        let targetPaths = targetObservation.artifactsByPath.keys.sorted().filter { path in
            normalizedArtifactPath.map { $0 == path } ?? true
        }
        for path in targetPaths {
            var matchingRelated: [(observation: ArtifactCollisionSessionObservation, repositoryKeys: [String])] = []
            let targetPathRepositoryKeys = targetObservation.repositoryKeysByPath[path] ?? []
            for relatedObservation in relatedObservations.sorted(by: { $0.profile.session.id < $1.profile.session.id }) {
                guard relatedObservation.artifactsByPath[path] != nil else { continue }
                let relatedPathRepositoryKeys = relatedObservation.repositoryKeysByPath[path] ?? []
                let sharedRepositoryKeys = targetPathRepositoryKeys
                    .intersection(relatedPathRepositoryKeys)
                    .sorted()
                guard !sharedRepositoryKeys.isEmpty else {
                    let reason = targetPathRepositoryKeys.isEmpty || relatedPathRepositoryKeys.isEmpty
                        ? "missing_artifact_repository_evidence"
                        : "same_path_different_repository"
                    appendArtifactCollisionExclusion(
                        ProvenanceArtifactCollisionCandidateExclusion(
                            sessionID: relatedObservation.profile.session.id,
                            artifactPath: relatedObservation.observedPathsByPath[path]?.sorted().first,
                            normalizedArtifactPath: path,
                            reason: reason,
                            evidence: uniqueArtifactCollisionEvidence(
                                (targetObservation.evidenceByPath[path] ?? [])
                                    + (relatedObservation.evidenceByPath[path] ?? [])
                                    + (targetObservation.repositoryEvidenceByPath[path] ?? [])
                                    + (relatedObservation.repositoryEvidenceByPath[path] ?? [])
                            )
                        ),
                        limit: exclusionLimit,
                        to: &exclusions
                    )
                    continue
                }
                matchingRelated.append((relatedObservation, sharedRepositoryKeys))
            }
            guard !matchingRelated.isEmpty else { continue }

            let sharedRepositoryKeys = Set(matchingRelated.flatMap(\.repositoryKeys)).sorted()
            let observations = [targetObservation] + matchingRelated.map(\.observation)
            let draft = try artifactCollisionCandidateDraft(
                normalizedPath: path,
                sharedRepositoryKeys: sharedRepositoryKeys,
                observations: observations,
                relatedProjection: relatedProjection,
                staleBefore: request.staleBefore,
                sourceWatermark: latestSequence
            )

            if let updatedAfter = request.updatedAfter,
               let latestObservedAt = draft.latestObservedAt,
               latestObservedAt < updatedAfter {
                appendArtifactCollisionExclusion(
                    ProvenanceArtifactCollisionCandidateExclusion(
                        artifactPath: draft.candidate.artifactIdentity.observedPaths.first,
                        normalizedArtifactPath: path,
                        reason: "outside_recent_boundary",
                        evidence: draft.candidate.evidence
                    ),
                    limit: exclusionLimit,
                    to: &exclusions
                )
                continue
            }
            drafts.append(draft)
        }

        let sortedDrafts = drafts.sorted(by: artifactCollisionCandidateSort)
        let candidates = sortedDrafts.prefix(resultLimit).map(\.candidate)
        for draft in sortedDrafts.dropFirst(resultLimit) {
            appendArtifactCollisionExclusion(
                ProvenanceArtifactCollisionCandidateExclusion(
                    artifactPath: draft.candidate.artifactIdentity.observedPaths.first,
                    normalizedArtifactPath: draft.candidate.artifactIdentity.normalizedPath,
                    reason: "result_limit",
                    evidence: draft.candidate.evidence
                ),
                limit: exclusionLimit,
                to: &exclusions
            )
        }

        let contentFingerprint = artifactCollisionContentFingerprint(
            requestFingerprint: requestFingerprint,
            target: targetProfile,
            relatedProjection: relatedProjection,
            candidates: Array(candidates),
            excludedCandidates: exclusions
        )
        let revisionID = stableIDFactory.id(
            prefix: "artifact-collision-revision",
            value: [
                request.targetSessionID,
                Self.artifactCollisionRuleID,
                Self.artifactCollisionRuleVersion,
                requestFingerprint,
                contentFingerprint,
            ].joined(separator: "\n")
        )
        let metadata = ProvenanceArtifactCollisionProjectionMetadata(
            revisionID: revisionID,
            projectionRuleID: Self.artifactCollisionRuleID,
            projectionRuleVersion: Self.artifactCollisionRuleVersion,
            requestFingerprint: requestFingerprint,
            contentFingerprint: contentFingerprint,
            resultLimit: resultLimit,
            relatedSessionLimit: relatedSessionLimit,
            exclusionLimit: exclusionLimit,
            artifactPath: request.artifactPath,
            normalizedArtifactPath: normalizedArtifactPath,
            updatedAfter: request.updatedAfter,
            staleBefore: request.staleBefore,
            sourceEvidenceWatermark: latestSequence,
            generatedAt: generatedAt ?? targetProfile.session.updatedAt
        )
        let completeness = artifactCollisionProjectionCompleteness(
            target: targetProfile,
            relatedProjection: relatedProjection,
            targetObservation: targetObservation,
            candidates: Array(candidates),
            excludedCandidates: exclusions,
            evaluatedThroughSequence: latestSequence
        )
        return ProvenanceArtifactCollisionProjection(
            targetSessionID: request.targetSessionID,
            targetSession: targetProfile.session,
            targetSessionOutcomeProjection: targetProfile.outcome?.projection,
            relatedSessionProjection: relatedProjection?.projection,
            projection: metadata,
            candidates: Array(candidates),
            excludedCandidates: exclusions,
            completeness: completeness
        )
    }

    private func artifactCollisionCandidateDraft(
        normalizedPath: String,
        sharedRepositoryKeys: [String],
        observations: [ArtifactCollisionSessionObservation],
        relatedProjection: ProvenanceRelatedSessionProjection?,
        staleBefore: Date?,
        sourceWatermark: Int?
    ) throws -> ArtifactCollisionCandidateDraft {
        let candidateRepositoryKeys = Set(sharedRepositoryKeys)
        let participants = try observations.map {
            try artifactCollisionParticipation(
                observation: $0,
                normalizedPath: normalizedPath,
                repositoryKeys: candidateRepositoryKeys,
                sourceWatermark: sourceWatermark
            )
        }.sorted { lhs, rhs in
            lhs.sessionID < rhs.sessionID
        }
        let participantEvidence = participants.flatMap(\.evidence)
        let projectionEvidence = relatedProjection.map { [artifactCollisionEvidence($0)] } ?? []
        let evidence = uniqueArtifactCollisionEvidence(participantEvidence + projectionEvidence)
        let observedPaths = Set(participants.flatMap {
            $0.matchedArtifacts.map(\.artifact.path)
        }).sorted()
        let artifactIdentityID = stableIDFactory.id(
            prefix: "artifact-collision-artifact",
            value: [
                "rule=\(Self.artifactCollisionRuleID)",
                "version=\(Self.artifactCollisionRuleVersion)",
                "path=\(normalizedPath)",
                "repositories=\(sharedRepositoryKeys.joined(separator: ","))",
            ].joined(separator: "\n")
        )
        let artifactIdentity = ProvenanceArtifactCollisionArtifactIdentity(
            id: artifactIdentityID,
            observedPaths: observedPaths,
            normalizedPath: normalizedPath,
            repositoryKeys: sharedRepositoryKeys,
            relationshipKind: "exact_path",
            caseSensitivity: "case_sensitive",
            renameSupport: "unsupported_without_accepted_rename_evidence",
            evidence: evidence
        )
        let pathBoundary = ProvenanceArtifactCollisionPathBoundary(
            observedPaths: observedPaths,
            normalizedPath: normalizedPath,
            pathRelationship: "exact_path",
            repositoryKeys: sharedRepositoryKeys,
            caseSensitivity: "case_sensitive",
            renameRelationship: "unsupported_without_accepted_rename_evidence",
            evidence: evidence
        )
        let boundaryComparison = artifactCollisionBoundaryComparison(
            participants: participants,
            sharedRepositoryKeys: sharedRepositoryKeys
        )
        let temporalOverlap = artifactCollisionTemporalOverlap(participants: participants)
        let latestObservedAt = participants.compactMap(\.lastObservedChangedAt).max()
        let requiredComplete = artifactCollisionRequiredEvidenceComplete(
            participants: participants,
            sharedRepositoryKeys: sharedRepositoryKeys
        )
        let state = artifactCollisionState(
            participants: participants,
            latestObservedAt: latestObservedAt,
            staleBefore: staleBefore,
            requiredComplete: requiredComplete
        )
        let freshness = ProvenanceArtifactCollisionFreshness(
            state: state,
            latestArtifactObservedAt: latestObservedAt,
            staleBefore: staleBefore,
            sourceEvidenceWatermark: sourceWatermark,
            relatedSessionProjectionRevisionID: relatedProjection?.projection.revisionID,
            relatedSessionProjectionWatermark: relatedProjection?.projection.sourceEvidenceWatermark
        )
        let reasons = artifactCollisionReasons(
            normalizedPath: normalizedPath,
            sharedRepositoryKeys: sharedRepositoryKeys,
            boundaryComparison: boundaryComparison,
            temporalOverlap: temporalOverlap,
            state: state,
            evidence: evidence
        )
        let completeness = artifactCollisionCandidateCompleteness(
            participants: participants,
            sharedRepositoryKeys: sharedRepositoryKeys,
            relatedProjection: relatedProjection,
            evaluatedThroughSequence: sourceWatermark
        )
        let candidateID = stableIDFactory.id(
            prefix: "artifact-collision-candidate",
            value: [
                Self.artifactCollisionRuleID,
                Self.artifactCollisionRuleVersion,
                normalizedPath,
                sharedRepositoryKeys.joined(separator: ","),
                participants.map(\.sessionID).joined(separator: ","),
            ].joined(separator: "\n")
        )
        let candidate = ProvenanceArtifactCollisionCandidate(
            id: candidateID,
            state: state,
            artifactIdentity: artifactIdentity,
            pathBoundary: pathBoundary,
            participants: participants,
            boundaryComparison: boundaryComparison,
            temporalOverlap: temporalOverlap,
            reasons: reasons,
            freshness: freshness,
            evidence: evidence,
            completeness: completeness,
            notes: artifactCollisionCandidateNotes()
        )
        return ArtifactCollisionCandidateDraft(
            candidate: candidate,
            priority: artifactCollisionCandidatePriority(state, temporalState: temporalOverlap.state),
            latestObservedAt: latestObservedAt
        )
    }

    private func artifactCollisionParticipation(
        observation: ArtifactCollisionSessionObservation,
        normalizedPath: String,
        repositoryKeys: Set<String>,
        sourceWatermark: Int?
    ) throws -> ProvenanceArtifactCollisionSessionParticipation {
        let profile = observation.profile
        let artifacts = (observation.artifactsByPath[normalizedPath] ?? []).filter { artifact in
            let artifactRepositoryKeys = observation.repositoryKeysByArtifactID[artifact.id] ?? []
            return !artifactRepositoryKeys.intersection(repositoryKeys).isEmpty
        }
        let changedTimes = try artifacts.compactMap {
            try artifactCollisionLatestEventTimestamp($0.artifact.evidence)
        }
        let artifactEvidence = uniqueArtifactCollisionEvidence(artifacts.flatMap {
            observation.evidenceByArtifactID[$0.id] ?? []
        })
        let repositoryBoundaries = try artifactCollisionRepositoryBoundaries(
            profile.repositoryBoundaries,
            matching: repositoryKeys
        )
        let worktreeBoundaries = try artifactCollisionWorktreeBoundaries(
            profile.worktreeBoundaries,
            matching: repositoryKeys
        )
        let boundaryEvidence = repositoryBoundaries.flatMap {
            artifactCollisionEvidence($0, sessionID: profile.session.id)
        } + worktreeBoundaries.flatMap {
            artifactCollisionEvidence($0, sessionID: profile.session.id)
        }
        let evidence = uniqueArtifactCollisionEvidence(artifactEvidence + boundaryEvidence)
        let completeness = artifactCollisionParticipationCompleteness(
            profile: profile,
            artifacts: artifacts,
            changedTimes: changedTimes,
            evidence: evidence,
            evaluatedThroughSequence: sourceWatermark
        )
        let participationID = stableIDFactory.id(
            prefix: "artifact-collision-participation",
            value: [
                profile.session.id,
                profile.outcome?.projection.revisionID ?? "",
                normalizedPath,
                artifacts.map(\.id).joined(separator: ","),
            ].joined(separator: "\n")
        )
        return ProvenanceArtifactCollisionSessionParticipation(
            id: participationID,
            sessionID: profile.session.id,
            session: profile.session,
            lifecycleState: profile.session.status,
            completionState: profile.outcome?.completionState
                ?? normalizedRelatedSessionCompletionState(profile.session.status),
            sessionOutcomeRevisionID: profile.outcome?.projection.revisionID,
            sessionOutcomeProjection: profile.outcome?.projection,
            matchedArtifacts: artifacts,
            repositoryBoundaries: repositoryBoundaries,
            worktreeBoundaries: worktreeBoundaries,
            firstObservedChangedAt: changedTimes.min(),
            lastObservedChangedAt: changedTimes.max(),
            evidence: evidence,
            completeness: completeness
        )
    }

    private func artifactCollisionRepositoryBoundaries(
        _ boundaries: [ProvenanceSessionOutcomeRepositoryBoundary],
        matching repositoryKeys: Set<String>
    ) throws -> [ProvenanceSessionOutcomeRepositoryBoundary] {
        try boundaries.filter { boundary in
            try !artifactCollisionRepositoryKeys(
                repositoryID: boundary.repositoryID,
                repositoryPath: boundary.repositoryPath
            ).intersection(repositoryKeys).isEmpty
        }
    }

    private func artifactCollisionWorktreeBoundaries(
        _ boundaries: [ProvenanceRelatedSessionWorktreeBoundary],
        matching repositoryKeys: Set<String>
    ) throws -> [ProvenanceRelatedSessionWorktreeBoundary] {
        try boundaries.filter { boundary in
            try !artifactCollisionRepositoryKeys(
                repositoryID: boundary.repositoryID,
                repositoryPath: boundary.repositoryPath
            ).intersection(repositoryKeys).isEmpty
        }
    }
}
