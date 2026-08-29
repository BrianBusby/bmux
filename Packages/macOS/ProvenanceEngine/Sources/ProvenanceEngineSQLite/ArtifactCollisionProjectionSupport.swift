import Foundation
import ProvenanceEngineContracts

struct ArtifactCollisionSessionObservation {
    let profile: RelatedSessionProfile
    let artifactsByPath: [String: [ProvenanceSessionOutcomeArtifact]]
    let observedPathsByPath: [String: Set<String>]
    let evidenceByPath: [String: [ProvenanceArtifactCollisionEvidenceReference]]
    let changedAtByPath: [String: [Date]]
}

struct ArtifactCollisionCandidateDraft {
    let candidate: ProvenanceArtifactCollisionCandidate
    let priority: Int
    let latestObservedAt: Date?
}

struct ArtifactCollisionTimeRange {
    let sessionID: String
    let start: Date?
    let end: Date?
    let isOpen: Bool
}

extension ProvenanceSQLiteRepository {
    func artifactCollisionObservation(
        profile: RelatedSessionProfile
    ) throws -> ArtifactCollisionSessionObservation {
        var artifactsByPath: [String: [ProvenanceSessionOutcomeArtifact]] = [:]
        var observedPathsByPath: [String: Set<String>] = [:]
        var evidenceByPath: [String: [ProvenanceArtifactCollisionEvidenceReference]] = [:]
        var changedAtByPath: [String: [Date]] = [:]

        guard let outcome = profile.outcome else {
            return ArtifactCollisionSessionObservation(
                profile: profile,
                artifactsByPath: artifactsByPath,
                observedPathsByPath: observedPathsByPath,
                evidenceByPath: evidenceByPath,
                changedAtByPath: changedAtByPath
            )
        }

        for artifact in outcome.changedArtifacts {
            guard let normalizedPath = normalizedArtifactCollisionPath(artifact.artifact.path) else {
                continue
            }
            var artifacts = artifactsByPath[normalizedPath] ?? []
            if !artifacts.contains(where: { $0.id == artifact.id }) {
                artifacts.append(artifact)
            }
            artifactsByPath[normalizedPath] = artifacts

            var observedPaths = observedPathsByPath[normalizedPath] ?? []
            observedPaths.insert(artifact.artifact.path)
            observedPathsByPath[normalizedPath] = observedPaths

            let artifactEvidence = artifactCollisionEvidence(
                artifact.artifact.evidence,
                sessionID: profile.session.id,
                turnID: artifact.sourceTurnID
            )
            appendArtifactCollisionEvidence(
                artifactEvidence + [artifactCollisionEvidence(outcome)],
                for: normalizedPath,
                to: &evidenceByPath
            )
            if let latest = try artifactCollisionLatestEventTimestamp(artifact.artifact.evidence) {
                var timestamps = changedAtByPath[normalizedPath] ?? []
                timestamps.append(latest)
                changedAtByPath[normalizedPath] = timestamps
            }
        }

        return ArtifactCollisionSessionObservation(
            profile: profile,
            artifactsByPath: artifactsByPath.mapValues { items in
                items.sorted(by: artifactCollisionArtifactSort)
            },
            observedPathsByPath: observedPathsByPath,
            evidenceByPath: evidenceByPath,
            changedAtByPath: changedAtByPath
        )
    }

    func artifactCollisionEvidence(
        _ outcome: ProvenanceSessionOutcome
    ) -> ProvenanceArtifactCollisionEvidenceReference {
        ProvenanceArtifactCollisionEvidenceReference(
            kind: "session_outcome",
            id: outcome.sessionID,
            projectionRevisionID: outcome.projection.revisionID,
            projectionWatermark: outcome.projection.sourceEvidenceWatermark,
            sessionID: outcome.sessionID,
            field: "session_outcome"
        )
    }

    func artifactCollisionEvidence(
        _ relatedProjection: ProvenanceRelatedSessionProjection
    ) -> ProvenanceArtifactCollisionEvidenceReference {
        ProvenanceArtifactCollisionEvidenceReference(
            kind: "related_session_projection",
            id: relatedProjection.targetSessionID,
            projectionRevisionID: relatedProjection.projection.revisionID,
            projectionWatermark: relatedProjection.projection.sourceEvidenceWatermark,
            sessionID: relatedProjection.targetSessionID,
            field: "related_sessions"
        )
    }

    func artifactCollisionEvidence(
        _ boundary: ProvenanceSessionOutcomeRepositoryBoundary,
        sessionID: String
    ) -> [ProvenanceArtifactCollisionEvidenceReference] {
        artifactCollisionEvidence(boundary.evidence, sessionID: sessionID, turnID: nil)
    }

    func artifactCollisionEvidence(
        _ boundary: ProvenanceRelatedSessionWorktreeBoundary,
        sessionID: String
    ) -> [ProvenanceArtifactCollisionEvidenceReference] {
        artifactCollisionEvidence(boundary.evidence, sessionID: sessionID)
    }

    func artifactCollisionEvidence(
        _ evidence: [ProvenanceTurnOutcomeEvidenceReference],
        sessionID: String?,
        turnID: String?
    ) -> [ProvenanceArtifactCollisionEvidenceReference] {
        evidence.map { item in
            ProvenanceArtifactCollisionEvidenceReference(
                kind: "event",
                id: item.eventID,
                eventSequence: item.eventSequence,
                eventType: item.eventType,
                source: item.source,
                evidenceOrigin: item.evidenceOrigin,
                evidenceScope: item.evidenceScope,
                sessionID: sessionID,
                turnID: turnID,
                field: "\(item.recordKind):\(item.recordID)",
                sourceState: item.sourceState
            )
        }
    }

    func artifactCollisionEvidence(
        _ evidence: [ProvenanceRelatedSessionEvidenceReference],
        sessionID: String? = nil
    ) -> [ProvenanceArtifactCollisionEvidenceReference] {
        evidence.map { item in
            ProvenanceArtifactCollisionEvidenceReference(
                kind: item.kind,
                id: item.id,
                eventSequence: item.eventSequence,
                eventType: item.eventType,
                projectionRevisionID: item.projectionRevisionID,
                projectionWatermark: item.projectionWatermark,
                sessionID: sessionID,
                field: item.field,
                sourceState: item.sourceState
            )
        }
    }

    func appendArtifactCollisionEvidence(
        _ evidence: [ProvenanceArtifactCollisionEvidenceReference],
        for key: String,
        to dictionary: inout [String: [ProvenanceArtifactCollisionEvidenceReference]]
    ) {
        dictionary[key] = uniqueArtifactCollisionEvidence((dictionary[key] ?? []) + evidence)
    }

    func appendArtifactCollisionExclusion(
        _ exclusion: ProvenanceArtifactCollisionCandidateExclusion,
        limit: Int,
        to exclusions: inout [ProvenanceArtifactCollisionCandidateExclusion]
    ) {
        guard exclusions.count < limit else { return }
        exclusions.append(exclusion)
    }

    func uniqueArtifactCollisionEvidence(
        _ evidence: [ProvenanceArtifactCollisionEvidenceReference]
    ) -> [ProvenanceArtifactCollisionEvidenceReference] {
        var seen = Set<String>()
        return evidence.sorted(by: artifactCollisionEvidenceSort).filter { item in
            let key = artifactCollisionEvidenceIdentityKey(item)
            return seen.insert(key).inserted
        }
    }

    func artifactCollisionEvidenceIdentityKey(
        _ item: ProvenanceArtifactCollisionEvidenceReference
    ) -> String {
        [
            item.kind,
            item.id,
            item.eventSequence.map(String.init) ?? "",
            item.eventType ?? "",
            item.projectionRevisionID ?? "",
            item.projectionWatermark.map(String.init) ?? "",
            item.source?.rawValue ?? "",
            item.evidenceOrigin?.rawValue ?? "",
            item.evidenceScope.map { "\($0.level.rawValue):\($0.id ?? "")" } ?? "",
            item.sessionID ?? "",
            item.turnID ?? "",
            item.field ?? "",
            item.sourceState ?? "",
        ].joined(separator: "|")
    }

    func artifactCollisionEvidenceSort(
        _ lhs: ProvenanceArtifactCollisionEvidenceReference,
        _ rhs: ProvenanceArtifactCollisionEvidenceReference
    ) -> Bool {
        if lhs.eventSequence ?? -1 != rhs.eventSequence ?? -1 {
            return lhs.eventSequence ?? -1 < rhs.eventSequence ?? -1
        }
        if lhs.kind != rhs.kind { return lhs.kind < rhs.kind }
        if lhs.id != rhs.id { return lhs.id < rhs.id }
        if lhs.projectionRevisionID ?? "" != rhs.projectionRevisionID ?? "" {
            return lhs.projectionRevisionID ?? "" < rhs.projectionRevisionID ?? ""
        }
        if lhs.sessionID ?? "" != rhs.sessionID ?? "" {
            return lhs.sessionID ?? "" < rhs.sessionID ?? ""
        }
        if lhs.turnID ?? "" != rhs.turnID ?? "" {
            return lhs.turnID ?? "" < rhs.turnID ?? ""
        }
        return lhs.field ?? "" < rhs.field ?? ""
    }

    func artifactCollisionArtifactSort(
        _ lhs: ProvenanceSessionOutcomeArtifact,
        _ rhs: ProvenanceSessionOutcomeArtifact
    ) -> Bool {
        if lhs.artifact.path != rhs.artifact.path { return lhs.artifact.path < rhs.artifact.path }
        if lhs.sourceTurnID != rhs.sourceTurnID { return lhs.sourceTurnID < rhs.sourceTurnID }
        return lhs.id < rhs.id
    }

    func artifactCollisionCandidateSort(
        _ lhs: ArtifactCollisionCandidateDraft,
        _ rhs: ArtifactCollisionCandidateDraft
    ) -> Bool {
        if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
        let lhsTime = lhs.latestObservedAt?.timeIntervalSince1970 ?? -Double.greatestFiniteMagnitude
        let rhsTime = rhs.latestObservedAt?.timeIntervalSince1970 ?? -Double.greatestFiniteMagnitude
        if lhsTime != rhsTime { return lhsTime > rhsTime }
        if lhs.candidate.artifactIdentity.normalizedPath != rhs.candidate.artifactIdentity.normalizedPath {
            return lhs.candidate.artifactIdentity.normalizedPath < rhs.candidate.artifactIdentity.normalizedPath
        }
        return lhs.candidate.id < rhs.candidate.id
    }

    func artifactCollisionCandidatePriority(
        _ state: ProvenanceArtifactCollisionState,
        temporalState: String
    ) -> Int {
        let statePriority: Int
        switch state {
        case .current:
            statePriority = 100
        case .incomplete:
            statePriority = 90
        case .historical:
            statePriority = 70
        case .stale:
            statePriority = 50
        }
        let temporalPriority = temporalState == "temporally_overlapping_edits" ? 5 : 0
        return statePriority + temporalPriority
    }

    func normalizedArtifactCollisionPath(_ path: String?) -> String? {
        guard let path else { return nil }
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let usesAbsoluteRoot = trimmed.hasPrefix("/")
        let usesCurrentDirectoryPrefix = trimmed.hasPrefix("./")
        let replaced = trimmed.replacingOccurrences(of: "\\", with: "/")
        var components: [String] = []
        for component in replaced.split(separator: "/", omittingEmptySubsequences: false) {
            let value = String(component)
            if value.isEmpty || value == "." {
                continue
            }
            if value == ".." {
                if !components.isEmpty, components.last != ".." {
                    components.removeLast()
                } else if !usesAbsoluteRoot {
                    components.append(value)
                }
                continue
            }
            components.append(value)
        }

        let normalized = components.joined(separator: "/")
        if normalized.isEmpty {
            return usesAbsoluteRoot ? "/" : nil
        }
        if usesAbsoluteRoot {
            return "/\(normalized)"
        }
        if usesCurrentDirectoryPrefix {
            return normalized
        }
        return normalized
    }

    func artifactCollisionLatestEventTimestamp(
        _ evidence: [ProvenanceTurnOutcomeEvidenceReference]
    ) throws -> Date? {
        let timestamps = try evidence.compactMap { reference in
            try event(id: reference.eventID)?.timestamp
        }
        if !evidence.isEmpty,
           evidence.allSatisfy({ $0.sourceState == "duplicated" }) {
            return timestamps.min()
        }
        return timestamps.max()
    }

    func artifactCollisionRequestFingerprint(
        limit: Int,
        relatedSessionLimit: Int,
        exclusionLimit: Int,
        artifactPath: String?,
        normalizedArtifactPath: String?,
        updatedAfter: Date?,
        staleBefore: Date?
    ) -> String {
        stableIDFactory.id(
            prefix: "artifact-collision-request",
            value: [
                "schema=1",
                "limit=\(limit)",
                "related_session_limit=\(relatedSessionLimit)",
                "exclusion_limit=\(exclusionLimit)",
                "artifact_path=\(artifactPath ?? "")",
                "normalized_artifact_path=\(normalizedArtifactPath ?? "")",
                "updated_after=\(artifactCollisionTimestampFingerprint(updatedAfter))",
                "stale_before=\(artifactCollisionTimestampFingerprint(staleBefore))",
            ].joined(separator: "\n")
        )
    }

    func artifactCollisionTimestampFingerprint(_ date: Date?) -> String {
        guard let date else { return "" }
        return String(Int64((date.timeIntervalSince1970 * 1_000_000).rounded()))
    }
}
