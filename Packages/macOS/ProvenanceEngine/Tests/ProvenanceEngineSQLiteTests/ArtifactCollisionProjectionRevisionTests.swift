import Foundation
import ProvenanceEngineContracts
@testable import ProvenanceEngineSQLite
import Testing

@Suite
struct ArtifactCollisionProjectionRevisionTests {
    @Test
    func duplicateEvidenceAndRebuildKeepStableRevisionIdentity() async throws {
        let url = RelatedSessionProjectionTestSupport.temporaryDatabaseURL()
        defer { RelatedSessionProjectionTestSupport.removeTemporaryDatabaseDirectory(for: url) }
        let store = try ProvenanceSQLiteRepository(url: url)
        let fixture = RelatedSessionFixture()
        let repo = fixture.repository()
        let targetWorktree = fixture.worktree(
            id: "worktree-target",
            repository: repo,
            path: "/repos/revision-target",
            branch: "main",
            head: "target-head",
            offset: 1
        )
        let relatedWorktree = fixture.worktree(
            id: "worktree-related",
            repository: repo,
            path: "/repos/revision-related",
            branch: "main",
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
        let related = try await RelatedSessionProjectionTestSupport.seedSession(
            id: "session-related",
            status: "active",
            worktree: relatedWorktree,
            repository: repo,
            paths: ["Sources/Shared.swift"],
            fixture: fixture,
            into: store
        )
        let first = try #require(try await store.artifactCollisions(
            ProvenanceArtifactCollisionRequest(targetSessionID: target.session.id)
        ).projection)
        let firstRevisionCount = try await store.storageSummary().artifactCollisionRevisionCount
        let second = try #require(try await store.artifactCollisions(
            ProvenanceArtifactCollisionRequest(targetSessionID: target.session.id)
        ).projection)

        #expect(second.projection.revisionID == first.projection.revisionID)
        #expect(try await store.storageSummary().artifactCollisionRevisionCount == firstRevisionCount)

        try await fixture.appendFileAttribution(
            fixture.fileAttribution(
                paths: ["Sources/Shared.swift"],
                sessionID: related.session.id,
                threadID: related.thread.id,
                turnID: related.turn.id,
                offset: 40,
                idSuffix: related.turn.id
            ),
            eventID: "event-duplicate-collision-attribution",
            into: store
        )
        let afterDuplicate = try #require(try await store.artifactCollisions(
            ProvenanceArtifactCollisionRequest(targetSessionID: target.session.id)
        ).projection)

        #expect(afterDuplicate.projection.revisionID == first.projection.revisionID)
        #expect((afterDuplicate.projection.sourceEvidenceWatermark ?? 0) > (first.projection.sourceEvidenceWatermark ?? 0))
        #expect(try await store.storageSummary().artifactCollisionRevisionCount == firstRevisionCount)

        _ = try await store.rebuildProjectionsFromEventLedger(batchSize: 2)
        let afterRebuild = try #require(try await store.artifactCollisions(
            ProvenanceArtifactCollisionRequest(targetSessionID: target.session.id)
        ).projection)

        #expect(afterRebuild == afterDuplicate)
    }

    @Test
    func correctedOutOfOrderEvidenceCreatesAndRetiresCandidatesDeterministically() async throws {
        let url = RelatedSessionProjectionTestSupport.temporaryDatabaseURL()
        defer { RelatedSessionProjectionTestSupport.removeTemporaryDatabaseDirectory(for: url) }
        let store = try ProvenanceSQLiteRepository(url: url)
        let fixture = RelatedSessionFixture()
        let repo = fixture.repository()
        let targetWorktree = fixture.worktree(
            id: "worktree-target",
            repository: repo,
            path: "/repos/corrected-target",
            branch: "main",
            head: "target-head",
            offset: 1
        )
        let relatedWorktree = fixture.worktree(
            id: "worktree-related",
            repository: repo,
            path: "/repos/corrected-related",
            branch: "main",
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
        let related = try await RelatedSessionProjectionTestSupport.seedSession(
            id: "session-related",
            status: "active",
            worktree: relatedWorktree,
            repository: repo,
            paths: ["Sources/Other.swift"],
            fixture: fixture,
            into: store
        )

        let before = try #require(try await store.artifactCollisions(
            ProvenanceArtifactCollisionRequest(targetSessionID: target.session.id)
        ).projection)

        #expect(before.candidates.isEmpty)

        try await fixture.appendFileAttribution(
            fixture.fileAttribution(
                paths: ["Sources/Shared.swift"],
                sessionID: related.session.id,
                threadID: related.thread.id,
                turnID: related.turn.id,
                offset: 5,
                idSuffix: related.turn.id
            ),
            eventID: "event-late-corrected-shared-path",
            into: store
        )
        let afterCorrection = try #require(try await store.artifactCollisions(
            ProvenanceArtifactCollisionRequest(targetSessionID: target.session.id)
        ).projection)
        let activeRevisionID = afterCorrection.projection.revisionID

        #expect(afterCorrection.candidates.map { $0.artifactIdentity.normalizedPath } == ["Sources/Shared.swift"])
        #expect(afterCorrection.projection.revisionID != before.projection.revisionID)
        #expect(afterCorrection.candidates.first?.evidence.contains { $0.id == "event-late-corrected-shared-path" } == true)

        try await fixture.appendFileAttribution(
            fixture.fileAttribution(
                paths: ["Sources/Retired.swift"],
                sessionID: related.session.id,
                threadID: related.thread.id,
                turnID: related.turn.id,
                offset: 6,
                idSuffix: related.turn.id
            ),
            eventID: "event-late-corrected-retired-path",
            into: store
        )
        let afterRetirement = try #require(try await store.artifactCollisions(
            ProvenanceArtifactCollisionRequest(targetSessionID: target.session.id)
        ).projection)
        let historicalRevision = try #require(try await store.artifactCollisions(
            ProvenanceArtifactCollisionRequest(
                targetSessionID: target.session.id,
                revisionID: activeRevisionID
            )
        ).projection)

        #expect(afterRetirement.candidates.isEmpty)
        #expect(afterRetirement.projection.revisionID != activeRevisionID)
        #expect(historicalRevision.candidates.count == 1)
        #expect(historicalRevision.projection.revisionID == activeRevisionID)
    }

    @Test
    func artifactPathFilterCreatesSeparateStableRequestRevision() async throws {
        let url = RelatedSessionProjectionTestSupport.temporaryDatabaseURL()
        defer { RelatedSessionProjectionTestSupport.removeTemporaryDatabaseDirectory(for: url) }
        let store = try ProvenanceSQLiteRepository(url: url)
        let fixture = RelatedSessionFixture()
        let repo = fixture.repository()
        let worktree = fixture.worktree(
            id: "worktree-filter",
            repository: repo,
            path: "/repos/filter",
            branch: "main",
            head: "filter-head",
            offset: 1
        )
        let target = try await RelatedSessionProjectionTestSupport.seedSession(
            id: "session-target",
            status: "active",
            worktree: worktree,
            repository: repo,
            paths: ["Sources/A.swift", "Sources/B.swift"],
            fixture: fixture,
            into: store
        )
        _ = try await RelatedSessionProjectionTestSupport.seedSession(
            id: "session-related",
            status: "active",
            worktree: worktree,
            repository: repo,
            paths: ["Sources/A.swift", "Sources/B.swift"],
            fixture: fixture,
            into: store
        )

        let all = try #require(try await store.artifactCollisions(
            ProvenanceArtifactCollisionRequest(targetSessionID: target.session.id)
        ).projection)
        let filtered = try #require(try await store.artifactCollisions(
            ProvenanceArtifactCollisionRequest(
                targetSessionID: target.session.id,
                artifactPath: "./Sources/B.swift"
            )
        ).projection)

        #expect(all.candidates.count == 2)
        #expect(filtered.candidates.map { $0.artifactIdentity.normalizedPath } == ["Sources/B.swift"])
        #expect(filtered.projection.normalizedArtifactPath == "Sources/B.swift")
        #expect(filtered.projection.requestFingerprint != all.projection.requestFingerprint)
    }
}
