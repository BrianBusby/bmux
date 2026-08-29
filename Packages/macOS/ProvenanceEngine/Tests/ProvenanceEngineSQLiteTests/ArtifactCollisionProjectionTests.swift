import Foundation
import ProvenanceEngineContracts
@testable import ProvenanceEngineSQLite
import Testing

@Suite
struct ArtifactCollisionProjectionTests {
    @Test
    func noOverlappingArtifactsReturnsEmptyProjection() async throws {
        let url = RelatedSessionProjectionTestSupport.temporaryDatabaseURL()
        defer { RelatedSessionProjectionTestSupport.removeTemporaryDatabaseDirectory(for: url) }
        let store = try ProvenanceSQLiteRepository(url: url)
        let fixture = RelatedSessionFixture()
        let repo = fixture.repository()
        let targetWorktree = fixture.worktree(
            id: "worktree-target",
            repository: repo,
            path: "/repos/collisions-target",
            branch: "main",
            head: "target-head",
            offset: 1
        )
        let relatedWorktree = fixture.worktree(
            id: "worktree-related",
            repository: repo,
            path: "/repos/collisions-related",
            branch: "main",
            head: "related-head",
            offset: 2
        )
        let target = try await RelatedSessionProjectionTestSupport.seedSession(
            id: "session-target",
            status: "active",
            worktree: targetWorktree,
            repository: repo,
            paths: ["Sources/Target.swift"],
            fixture: fixture,
            into: store
        )
        _ = try await RelatedSessionProjectionTestSupport.seedSession(
            id: "session-related",
            status: "active",
            worktree: relatedWorktree,
            repository: repo,
            paths: ["Sources/Related.swift"],
            fixture: fixture,
            into: store
        )

        let projection = try #require(try await store.artifactCollisions(
            ProvenanceArtifactCollisionRequest(targetSessionID: target.session.id)
        ).projection)

        #expect(projection.candidates.isEmpty)
        #expect(projection.completeness.status == "empty")
        #expect(projection.relatedSessionProjection?.projectionRuleID == "deterministic_related_sessions")
    }

    @Test
    func exactPathOverlapReportsCurrentPossibleCollisionWithEvidence() async throws {
        let url = RelatedSessionProjectionTestSupport.temporaryDatabaseURL()
        defer { RelatedSessionProjectionTestSupport.removeTemporaryDatabaseDirectory(for: url) }
        let store = try ProvenanceSQLiteRepository(url: url)
        let fixture = RelatedSessionFixture()
        let repo = fixture.repository()
        let worktree = fixture.worktree(
            id: "worktree-shared",
            repository: repo,
            path: "/repos/shared",
            branch: "feature/shared",
            head: "shared-head",
            offset: 1
        )
        let target = try await RelatedSessionProjectionTestSupport.seedSession(
            id: "session-target",
            status: "active",
            worktree: worktree,
            repository: repo,
            paths: ["Sources/Shared.swift"],
            fixture: fixture,
            into: store
        )
        _ = try await RelatedSessionProjectionTestSupport.seedSession(
            id: "session-related",
            status: "completed",
            worktree: worktree,
            repository: repo,
            paths: ["Sources/Shared.swift"],
            fixture: fixture,
            into: store
        )

        let projection = try #require(try await store.artifactCollisions(
            ProvenanceArtifactCollisionRequest(targetSessionID: target.session.id)
        ).projection)
        let candidate = try #require(projection.candidates.first)
        let reasonKinds = Set(candidate.reasons.map(\.kind))

        #expect(projection.candidates.count == 1)
        #expect(candidate.state == .current)
        #expect(candidate.artifactIdentity.normalizedPath == "Sources/Shared.swift")
        #expect(candidate.pathBoundary.renameRelationship == "unsupported_without_accepted_rename_evidence")
        #expect(candidate.boundaryComparison.worktreeRelationship == "same_worktree")
        #expect(candidate.boundaryComparison.branchRelationship == "same_branch")
        #expect(candidate.boundaryComparison.headRelationship == "same_head")
        #expect(candidate.temporalOverlap.state == "temporally_overlapping_edits")
        #expect(reasonKinds.contains(.exactPathOverlap))
        #expect(reasonKinds.contains(.sharedRepository))
        #expect(reasonKinds.contains(.sameWorktree))
        #expect(reasonKinds.contains(.sameBranch))
        #expect(reasonKinds.contains(.sameHead))
        #expect(reasonKinds.contains(.temporallyOverlappingEdits))
        #expect(Set(candidate.participants.map(\.sessionID)) == Set(["session-target", "session-related"]))
        #expect(candidate.participants.allSatisfy { !$0.matchedArtifacts.isEmpty })
        #expect(candidate.evidence.contains { $0.kind == "event" && $0.eventSequence != nil })
        #expect(candidate.evidence.contains { $0.kind == "related_session_projection" })
        #expect(candidate.evidence.contains { $0.source == .observed && $0.evidenceOrigin == .codexSession })
        #expect(candidate.notes.contains { $0.contains("not a proven merge conflict") })
    }

    @Test
    func multipleArtifactsAndMultipleRelatedSessionsAreGroupedByPath() async throws {
        let url = RelatedSessionProjectionTestSupport.temporaryDatabaseURL()
        defer { RelatedSessionProjectionTestSupport.removeTemporaryDatabaseDirectory(for: url) }
        let store = try ProvenanceSQLiteRepository(url: url)
        let fixture = RelatedSessionFixture()
        let repo = fixture.repository()
        let targetWorktree = fixture.worktree(
            id: "worktree-target",
            repository: repo,
            path: "/repos/multi-target",
            branch: "main",
            head: "target-head",
            offset: 1
        )
        let relatedOneWorktree = fixture.worktree(
            id: "worktree-related-one",
            repository: repo,
            path: "/repos/multi-related-one",
            branch: "main",
            head: "one-head",
            offset: 2
        )
        let relatedTwoWorktree = fixture.worktree(
            id: "worktree-related-two",
            repository: repo,
            path: "/repos/multi-related-two",
            branch: "main",
            head: "two-head",
            offset: 3
        )
        let target = try await RelatedSessionProjectionTestSupport.seedSession(
            id: "session-target",
            status: "active",
            worktree: targetWorktree,
            repository: repo,
            paths: ["Sources/A.swift", "Sources/B.swift"],
            fixture: fixture,
            into: store
        )
        _ = try await RelatedSessionProjectionTestSupport.seedSession(
            id: "session-related-one",
            status: "active",
            worktree: relatedOneWorktree,
            repository: repo,
            paths: ["Sources/A.swift"],
            fixture: fixture,
            into: store
        )
        _ = try await RelatedSessionProjectionTestSupport.seedSession(
            id: "session-related-two",
            status: "active",
            worktree: relatedTwoWorktree,
            repository: repo,
            paths: ["Sources/A.swift", "Sources/B.swift"],
            fixture: fixture,
            into: store
        )

        let projection = try #require(try await store.artifactCollisions(
            ProvenanceArtifactCollisionRequest(targetSessionID: target.session.id)
        ).projection)
        let candidatesByPath = Dictionary(uniqueKeysWithValues: projection.candidates.map {
            ($0.artifactIdentity.normalizedPath, $0)
        })

        #expect(Set(candidatesByPath.keys) == Set(["Sources/A.swift", "Sources/B.swift"]))
        #expect(candidatesByPath["Sources/A.swift"]?.participants.count == 3)
        #expect(candidatesByPath["Sources/B.swift"]?.participants.count == 2)
    }

    @Test
    func branchWorktreeAndHeadDivergenceRemainBoundaryFacts() async throws {
        let url = RelatedSessionProjectionTestSupport.temporaryDatabaseURL()
        defer { RelatedSessionProjectionTestSupport.removeTemporaryDatabaseDirectory(for: url) }
        let store = try ProvenanceSQLiteRepository(url: url)
        let fixture = RelatedSessionFixture()
        let repo = fixture.repository()
        let targetWorktree = fixture.worktree(
            id: "worktree-target",
            repository: repo,
            path: "/repos/divergent-target",
            branch: "feature/target",
            head: "target-head",
            offset: 1
        )
        let relatedWorktree = fixture.worktree(
            id: "worktree-related",
            repository: repo,
            path: "/repos/divergent-related",
            branch: "feature/related",
            head: "related-head",
            offset: 2
        )
        let target = try await RelatedSessionProjectionTestSupport.seedSession(
            id: "session-target",
            status: "active",
            worktree: targetWorktree,
            repository: repo,
            paths: ["Sources/Shared.swift"],
            fixture: fixture,
            into: store
        )
        _ = try await RelatedSessionProjectionTestSupport.seedSession(
            id: "session-related",
            status: "active",
            worktree: relatedWorktree,
            repository: repo,
            paths: ["Sources/Shared.swift"],
            fixture: fixture,
            into: store
        )

        let candidate = try #require(try await store.artifactCollisions(
            ProvenanceArtifactCollisionRequest(targetSessionID: target.session.id)
        ).projection?.candidates.first)
        let reasonKinds = Set(candidate.reasons.map(\.kind))

        #expect(candidate.boundaryComparison.worktreeRelationship == "different_worktrees")
        #expect(candidate.boundaryComparison.branchRelationship == "different_branches")
        #expect(candidate.boundaryComparison.headRelationship == "divergent_head")
        #expect(reasonKinds.contains(.differentWorktrees))
        #expect(reasonKinds.contains(.differentBranches))
        #expect(reasonKinds.contains(.divergentHead))
    }

    @Test
    func completedOrderedEditsAreHistoricalAndCanBeMarkedStale() async throws {
        let url = RelatedSessionProjectionTestSupport.temporaryDatabaseURL()
        defer { RelatedSessionProjectionTestSupport.removeTemporaryDatabaseDirectory(for: url) }
        let store = try ProvenanceSQLiteRepository(url: url)
        let fixture = RelatedSessionFixture()
        let repo = fixture.repository()
        let targetWorktree = fixture.worktree(
            id: "worktree-target",
            repository: repo,
            path: "/repos/historical-target",
            branch: "main",
            head: "target-head",
            offset: 1
        )
        let relatedWorktree = fixture.worktree(
            id: "worktree-related",
            repository: repo,
            path: "/repos/historical-related",
            branch: "main",
            head: "related-head",
            offset: 2
        )
        let target = try await RelatedSessionProjectionTestSupport.seedSession(
            id: "session-target",
            status: "completed",
            worktree: targetWorktree,
            repository: repo,
            sessionOffset: 10,
            paths: ["Sources/Shared.swift"],
            fixture: fixture,
            into: store
        )
        _ = try await RelatedSessionProjectionTestSupport.seedSession(
            id: "session-related",
            status: "completed",
            worktree: relatedWorktree,
            repository: repo,
            sessionOffset: 80,
            paths: ["Sources/Shared.swift"],
            fixture: fixture,
            into: store
        )

        let historical = try #require(try await store.artifactCollisions(
            ProvenanceArtifactCollisionRequest(targetSessionID: target.session.id)
        ).projection?.candidates.first)
        let stale = try #require(try await store.artifactCollisions(
            ProvenanceArtifactCollisionRequest(
                targetSessionID: target.session.id,
                staleBefore: fixture.time(100)
            )
        ).projection?.candidates.first)

        #expect(historical.state == .historical)
        #expect(historical.temporalOverlap.state == "ordered_edits")
        #expect(Set(historical.reasons.map(\.kind)).contains(.historicalOverlap))
        #expect(stale.state == .stale)
        #expect(Set(stale.reasons.map(\.kind)).contains(.staleOverlap))
        #expect(stale.freshness.staleBefore == fixture.time(100))
    }

    @Test
    func missingBranchHeadAndTimestampEvidenceAreMarkedIncomplete() async throws {
        let url = RelatedSessionProjectionTestSupport.temporaryDatabaseURL()
        defer { RelatedSessionProjectionTestSupport.removeTemporaryDatabaseDirectory(for: url) }
        let store = try ProvenanceSQLiteRepository(url: url)
        let fixture = RelatedSessionFixture()
        let repo = fixture.repository()
        let targetWorktree = fixture.worktree(
            id: "worktree-target",
            repository: repo,
            path: "/repos/incomplete-target",
            branch: nil,
            head: nil,
            offset: 1
        )
        let relatedWorktree = fixture.worktree(
            id: "worktree-related",
            repository: repo,
            path: "/repos/incomplete-related",
            branch: nil,
            head: nil,
            offset: 2
        )
        let target = try await RelatedSessionProjectionTestSupport.seedSession(
            id: "session-target",
            status: "active",
            worktree: targetWorktree,
            repository: repo,
            paths: ["Sources/Shared.swift"],
            fixture: fixture,
            into: store
        )
        _ = try await RelatedSessionProjectionTestSupport.seedSession(
            id: "session-related",
            status: "active",
            worktree: relatedWorktree,
            repository: repo,
            paths: ["Sources/Shared.swift"],
            fixture: fixture,
            into: store
        )
        let database = try ProvenanceSQLiteDatabase(url: url)
        try database.execute("DELETE FROM provenance_events WHERE event_type = 'coding_agent_file_change_attributed'")

        let candidate = try #require(try await store.artifactCollisions(
            ProvenanceArtifactCollisionRequest(targetSessionID: target.session.id)
        ).projection?.candidates.first)

        #expect(candidate.state == .incomplete)
        #expect(candidate.boundaryComparison.branchRelationship == "unknown_branch")
        #expect(candidate.boundaryComparison.headRelationship == "unknown_head")
        #expect(candidate.temporalOverlap.state == "missing_timestamps")
        #expect(candidate.completeness.fields.first { $0.field == "artifact_timestamps" }?.status == "not_observed")
        #expect(Set(candidate.reasons.map(\.kind)).contains(.incompleteEvidence))
    }

    @Test
    func partialBranchAndHeadEvidenceDoesNotClaimSameBoundary() async throws {
        let url = RelatedSessionProjectionTestSupport.temporaryDatabaseURL()
        defer { RelatedSessionProjectionTestSupport.removeTemporaryDatabaseDirectory(for: url) }
        let store = try ProvenanceSQLiteRepository(url: url)
        let fixture = RelatedSessionFixture()
        let repo = fixture.repository()
        let targetWorktree = fixture.worktree(
            id: "worktree-target",
            repository: repo,
            path: "/repos/partial-boundary-target",
            branch: "main",
            head: "target-head",
            offset: 1
        )
        let relatedWorktree = fixture.worktree(
            id: "worktree-related",
            repository: repo,
            path: "/repos/partial-boundary-related",
            branch: nil,
            head: nil,
            offset: 2
        )
        let target = try await RelatedSessionProjectionTestSupport.seedSession(
            id: "session-target",
            status: "active",
            worktree: targetWorktree,
            repository: repo,
            paths: ["Sources/Shared.swift"],
            fixture: fixture,
            into: store
        )
        _ = try await RelatedSessionProjectionTestSupport.seedSession(
            id: "session-related",
            status: "active",
            worktree: relatedWorktree,
            repository: repo,
            paths: ["Sources/Shared.swift"],
            fixture: fixture,
            into: store
        )

        let candidate = try #require(try await store.artifactCollisions(
            ProvenanceArtifactCollisionRequest(targetSessionID: target.session.id)
        ).projection?.candidates.first)
        let reasonKinds = Set(candidate.reasons.map(\.kind))

        #expect(candidate.boundaryComparison.branchRelationship == "unknown_branch")
        #expect(candidate.boundaryComparison.headRelationship == "unknown_head")
        #expect(reasonKinds.contains(.sameBranch) == false)
        #expect(reasonKinds.contains(.sameHead) == false)
    }

    @Test
    func orderingLimitsAndUpdatedAfterAreDeterministic() async throws {
        let url = RelatedSessionProjectionTestSupport.temporaryDatabaseURL()
        defer { RelatedSessionProjectionTestSupport.removeTemporaryDatabaseDirectory(for: url) }
        let store = try ProvenanceSQLiteRepository(url: url)
        let fixture = RelatedSessionFixture()
        let repo = fixture.repository()
        let targetWorktree = fixture.worktree(
            id: "worktree-target",
            repository: repo,
            path: "/repos/limits-target",
            branch: "main",
            head: "target-head",
            offset: 1
        )
        let target = try await RelatedSessionProjectionTestSupport.seedSession(
            id: "session-target",
            status: "active",
            worktree: targetWorktree,
            repository: repo,
            paths: ["Sources/A.swift", "Sources/B.swift", "Sources/C.swift"],
            fixture: fixture,
            into: store
        )
        for (index, path) in ["Sources/A.swift", "Sources/B.swift", "Sources/C.swift"].enumerated() {
            let worktree = fixture.worktree(
                id: "worktree-related-\(index)",
                repository: repo,
                path: "/repos/limits-related-\(index)",
                branch: "main",
                head: "head-\(index)",
                offset: TimeInterval(2 + index)
            )
            _ = try await RelatedSessionProjectionTestSupport.seedSession(
                id: "session-related-\(index)",
                status: "active",
                worktree: worktree,
                repository: repo,
                sessionOffset: TimeInterval(20 + (index * 10)),
                paths: [path],
                fixture: fixture,
                into: store
            )
        }

        let limited = try #require(try await store.artifactCollisions(
            ProvenanceArtifactCollisionRequest(
                targetSessionID: target.session.id,
                limit: 2,
                updatedAfter: fixture.time(30),
                exclusionLimit: 5
            )
        ).projection)

        #expect(limited.candidates.map { $0.artifactIdentity.normalizedPath } == [
            "Sources/C.swift",
            "Sources/B.swift",
        ])
        #expect(limited.excludedCandidates.contains { $0.reason == "outside_recent_boundary" })
        #expect(limited.excludedCandidates.contains { $0.reason == "result_limit" } == false)
    }
}
