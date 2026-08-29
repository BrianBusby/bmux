import Foundation
import ProvenanceEngineContracts

extension ProvenanceSQLiteRepository {
    func artifactCollisionBoundaryComparison(
        participants: [ProvenanceArtifactCollisionSessionParticipation],
        sharedRepositoryKeys: [String]
    ) -> ProvenanceArtifactCollisionBoundaryComparison {
        let worktreeIDValues = participants.map { participant in
            Set(participant.repositoryBoundaries.compactMap(\.worktreeID)
                + participant.worktreeBoundaries.compactMap(\.worktreeID))
        }
        let branchValues = participants.map { participant in
            Set(participant.repositoryBoundaries.compactMap(\.branch)
                + participant.worktreeBoundaries.compactMap(\.branch))
        }
        let headValues = participants.map { participant in
            Set(participant.repositoryBoundaries.compactMap(\.head)
                + participant.worktreeBoundaries.compactMap(\.head))
        }
        let worktreeIDs = Set(worktreeIDValues.flatMap { Array($0) }).sorted()
        let worktreeBoundaryPaths = Set(participants.flatMap { participant in
            participant.repositoryBoundaries.compactMap(\.worktreePath)
                + participant.worktreeBoundaries.compactMap(\.worktreePath)
        }).sorted()
        let branches = Set(branchValues.flatMap { Array($0) }).sorted()
        let heads = Set(headValues.flatMap { Array($0) }).sorted()
        let evidence = uniqueArtifactCollisionEvidence(participants.flatMap { participant in
            participant.repositoryBoundaries.flatMap {
                artifactCollisionEvidence($0, sessionID: participant.sessionID)
            } + participant.worktreeBoundaries.flatMap {
                artifactCollisionEvidence($0, sessionID: participant.sessionID)
            }
        })
        return ProvenanceArtifactCollisionBoundaryComparison(
            repositoryRelationship: sharedRepositoryKeys.isEmpty
                ? "missing_repository_evidence"
                : "shared_repository",
            worktreeRelationship: artifactCollisionBoundaryRelationship(
                valueSets: worktreeIDValues,
                sameValue: "same_worktree",
                differentValue: "different_worktrees",
                unknownValue: "unknown_worktree"
            ),
            branchRelationship: artifactCollisionBoundaryRelationship(
                valueSets: branchValues,
                sameValue: "same_branch",
                differentValue: "different_branches",
                unknownValue: "unknown_branch"
            ),
            headRelationship: artifactCollisionBoundaryRelationship(
                valueSets: headValues,
                sameValue: "same_head",
                differentValue: "divergent_head",
                unknownValue: "unknown_head"
            ),
            sharedRepositoryKeys: sharedRepositoryKeys,
            worktreeIDs: worktreeIDs,
            worktreePaths: worktreeBoundaryPaths,
            branches: branches,
            heads: heads,
            evidence: evidence
        )
    }

    func artifactCollisionTemporalOverlap(
        participants: [ProvenanceArtifactCollisionSessionParticipation]
    ) -> ProvenanceArtifactCollisionTemporalOverlap {
        let missingTimestampSessionIDs = participants
            .filter { $0.firstObservedChangedAt == nil || $0.lastObservedChangedAt == nil }
            .map(\.sessionID)
            .sorted()
        let evidence = uniqueArtifactCollisionEvidence(participants.flatMap(\.evidence))
        let firstObserved = participants.compactMap(\.firstObservedChangedAt).min()
        let lastObserved = participants.compactMap(\.lastObservedChangedAt).max()
        guard missingTimestampSessionIDs.isEmpty else {
            return ProvenanceArtifactCollisionTemporalOverlap(
                state: "missing_timestamps",
                firstObservedChangedAt: firstObserved,
                lastObservedChangedAt: lastObserved,
                missingTimestampSessionIDs: missingTimestampSessionIDs,
                evidence: evidence
            )
        }

        let ranges = participants.map(artifactCollisionTimeRange)
        let overlaps = artifactCollisionRangesOverlap(ranges)
        return ProvenanceArtifactCollisionTemporalOverlap(
            state: overlaps ? "temporally_overlapping_edits" : "ordered_edits",
            firstObservedChangedAt: firstObserved,
            lastObservedChangedAt: lastObserved,
            missingTimestampSessionIDs: [],
            evidence: evidence
        )
    }

    func artifactCollisionState(
        participants: [ProvenanceArtifactCollisionSessionParticipation],
        latestObservedAt: Date?,
        staleBefore: Date?,
        requiredComplete: Bool
    ) -> ProvenanceArtifactCollisionState {
        guard requiredComplete else { return .incomplete }
        if let staleBefore,
           let latestObservedAt,
           latestObservedAt < staleBefore {
            return .stale
        }
        if participants.contains(where: artifactCollisionParticipantIsCurrent) {
            return .current
        }
        return .historical
    }

    func artifactCollisionReasons(
        normalizedPath: String,
        sharedRepositoryKeys: [String],
        boundaryComparison: ProvenanceArtifactCollisionBoundaryComparison,
        temporalOverlap: ProvenanceArtifactCollisionTemporalOverlap,
        state: ProvenanceArtifactCollisionState,
        evidence: [ProvenanceArtifactCollisionEvidenceReference]
    ) -> [ProvenanceArtifactCollisionReason] {
        var reasons = [
            ProvenanceArtifactCollisionReason(
                kind: .exactPathOverlap,
                targetValue: normalizedPath,
                relatedValue: normalizedPath,
                observedAt: temporalOverlap.lastObservedChangedAt,
                evidence: evidence
            ),
            ProvenanceArtifactCollisionReason(
                kind: .sharedRepository,
                targetValue: sharedRepositoryKeys.joined(separator: ","),
                relatedValue: sharedRepositoryKeys.joined(separator: ","),
                observedAt: temporalOverlap.lastObservedChangedAt,
                evidence: boundaryComparison.evidence
            ),
        ]
        reasons.append(contentsOf: artifactCollisionBoundaryReasons(
            boundaryComparison: boundaryComparison,
            observedAt: temporalOverlap.lastObservedChangedAt
        ))
        if temporalOverlap.state == "temporally_overlapping_edits" {
            reasons.append(ProvenanceArtifactCollisionReason(
                kind: .temporallyOverlappingEdits,
                observedAt: temporalOverlap.lastObservedChangedAt,
                evidence: temporalOverlap.evidence
            ))
        }
        switch state {
        case .historical:
            reasons.append(ProvenanceArtifactCollisionReason(
                kind: .historicalOverlap,
                observedAt: temporalOverlap.lastObservedChangedAt,
                evidence: evidence
            ))
        case .stale:
            reasons.append(ProvenanceArtifactCollisionReason(
                kind: .staleOverlap,
                observedAt: temporalOverlap.lastObservedChangedAt,
                evidence: evidence
            ))
        case .incomplete:
            reasons.append(ProvenanceArtifactCollisionReason(
                kind: .incompleteEvidence,
                observedAt: temporalOverlap.lastObservedChangedAt,
                evidence: evidence
            ))
        case .current:
            break
        }
        return reasons.sorted(by: artifactCollisionReasonSort)
    }

    func artifactCollisionRequiredEvidenceComplete(
        participants: [ProvenanceArtifactCollisionSessionParticipation],
        sharedRepositoryKeys: [String]
    ) -> Bool {
        guard participants.count >= 2,
              !sharedRepositoryKeys.isEmpty else {
            return false
        }
        return participants.allSatisfy { participant in
            participant.sessionOutcomeRevisionID != nil
                && !participant.matchedArtifacts.isEmpty
                && participant.lastObservedChangedAt != nil
                && (!participant.repositoryBoundaries.isEmpty || !participant.worktreeBoundaries.isEmpty)
        }
    }

    private func artifactCollisionBoundaryRelationship(
        valueSets: [Set<String>],
        sameValue: String,
        differentValue: String,
        unknownValue: String
    ) -> String {
        guard !valueSets.isEmpty,
              valueSets.allSatisfy({ !$0.isEmpty }) else {
            return unknownValue
        }
        let values = Set(valueSets.flatMap { Array($0) })
        guard !values.isEmpty else { return unknownValue }
        return values.count == 1 ? sameValue : differentValue
    }

    private func artifactCollisionBoundaryReasons(
        boundaryComparison: ProvenanceArtifactCollisionBoundaryComparison,
        observedAt: Date?
    ) -> [ProvenanceArtifactCollisionReason] {
        var reasons: [ProvenanceArtifactCollisionReason] = []
        if let kind = artifactCollisionBoundaryReasonKind(boundaryComparison.worktreeRelationship) {
            reasons.append(ProvenanceArtifactCollisionReason(
                kind: kind,
                targetValue: boundaryComparison.worktreeIDs.joined(separator: ","),
                relatedValue: boundaryComparison.worktreeIDs.joined(separator: ","),
                observedAt: observedAt,
                evidence: boundaryComparison.evidence
            ))
        }
        if let kind = artifactCollisionBoundaryReasonKind(boundaryComparison.branchRelationship) {
            reasons.append(ProvenanceArtifactCollisionReason(
                kind: kind,
                targetValue: boundaryComparison.branches.joined(separator: ","),
                relatedValue: boundaryComparison.branches.joined(separator: ","),
                observedAt: observedAt,
                evidence: boundaryComparison.evidence
            ))
        }
        if let kind = artifactCollisionBoundaryReasonKind(boundaryComparison.headRelationship) {
            reasons.append(ProvenanceArtifactCollisionReason(
                kind: kind,
                targetValue: boundaryComparison.heads.joined(separator: ","),
                relatedValue: boundaryComparison.heads.joined(separator: ","),
                observedAt: observedAt,
                evidence: boundaryComparison.evidence
            ))
        }
        return reasons
    }

    private func artifactCollisionBoundaryReasonKind(_ value: String) -> ProvenanceArtifactCollisionReasonKind? {
        switch value {
        case "same_worktree":
            return .sameWorktree
        case "different_worktrees":
            return .differentWorktrees
        case "same_branch":
            return .sameBranch
        case "different_branches":
            return .differentBranches
        case "same_head":
            return .sameHead
        case "divergent_head":
            return .divergentHead
        default:
            return nil
        }
    }

    private func artifactCollisionReasonSort(
        _ lhs: ProvenanceArtifactCollisionReason,
        _ rhs: ProvenanceArtifactCollisionReason
    ) -> Bool {
        let lhsPriority = artifactCollisionReasonPriority(lhs.kind)
        let rhsPriority = artifactCollisionReasonPriority(rhs.kind)
        if lhsPriority != rhsPriority { return lhsPriority > rhsPriority }
        if lhs.kind.rawValue != rhs.kind.rawValue { return lhs.kind.rawValue < rhs.kind.rawValue }
        if lhs.targetValue ?? "" != rhs.targetValue ?? "" { return lhs.targetValue ?? "" < rhs.targetValue ?? "" }
        return lhs.relatedValue ?? "" < rhs.relatedValue ?? ""
    }

    private func artifactCollisionReasonPriority(_ kind: ProvenanceArtifactCollisionReasonKind) -> Int {
        switch kind {
        case .exactPathOverlap:
            return 100
        case .sharedRepository:
            return 95
        case .sameWorktree:
            return 90
        case .sameBranch:
            return 85
        case .sameHead:
            return 80
        case .temporallyOverlappingEdits:
            return 75
        case .differentWorktrees:
            return 70
        case .differentBranches:
            return 65
        case .divergentHead:
            return 60
        case .incompleteEvidence:
            return 55
        case .historicalOverlap:
            return 50
        case .staleOverlap:
            return 45
        case .unsupportedRenameIdentity:
            return 10
        }
    }

    private func artifactCollisionParticipantIsCurrent(
        _ participant: ProvenanceArtifactCollisionSessionParticipation
    ) -> Bool {
        let lifecycle = participant.lifecycleState.lowercased()
        let completion = participant.completionState.lowercased()
        if completion == "incomplete" || completion == "active" || completion == "running" {
            return true
        }
        return lifecycle.contains("active")
            || lifecycle.contains("running")
            || lifecycle.contains("started")
            || lifecycle.contains("progress")
    }

    private func artifactCollisionTimeRange(
        _ participant: ProvenanceArtifactCollisionSessionParticipation
    ) -> ArtifactCollisionTimeRange {
        let start = participant.session.startedAt ?? participant.firstObservedChangedAt
        let knownEnd = [
            participant.session.updatedAt,
            participant.lastObservedChangedAt,
        ].compactMap { $0 }.max()
        let isOpen = artifactCollisionParticipantIsCurrent(participant)
        return ArtifactCollisionTimeRange(
            sessionID: participant.sessionID,
            start: start,
            end: isOpen ? nil : knownEnd,
            isOpen: isOpen
        )
    }

    private func artifactCollisionRangesOverlap(
        _ ranges: [ArtifactCollisionTimeRange]
    ) -> Bool {
        guard ranges.count >= 2,
              ranges.allSatisfy({ $0.start != nil }) else {
            return false
        }
        for lhsIndex in ranges.indices {
            for rhsIndex in ranges.indices where rhsIndex > lhsIndex {
                if artifactCollisionRangesOverlap(ranges[lhsIndex], ranges[rhsIndex]) {
                    return true
                }
            }
        }
        return false
    }

    private func artifactCollisionRangesOverlap(
        _ lhs: ArtifactCollisionTimeRange,
        _ rhs: ArtifactCollisionTimeRange
    ) -> Bool {
        guard let lhsStart = lhs.start,
              let rhsStart = rhs.start else {
            return false
        }
        let lhsEnd = lhs.end ?? Date.distantFuture
        let rhsEnd = rhs.end ?? Date.distantFuture
        return max(lhsStart, rhsStart) <= min(lhsEnd, rhsEnd)
    }

    func artifactCollisionProjectionNotes() -> [String] {
        [
            "artifact collision awareness reports possible factual overlap, not semantic incompatibility",
            "candidate discovery uses exact normalized paths inside shared repository identity boundaries",
            "stable rename identity is unsupported unless accepted rename evidence is added by a later rule version",
            "the read model does not coordinate sessions, mutate worktrees, inject prompts, or retain raw transcripts",
        ]
    }

    func artifactCollisionCandidateNotes() -> [String] {
        [
            "possible collision means PE found overlapping artifact evidence, not a proven merge conflict",
            "branch, worktree, and HEAD differences are reported as boundaries rather than coordination instructions",
        ]
    }
}
