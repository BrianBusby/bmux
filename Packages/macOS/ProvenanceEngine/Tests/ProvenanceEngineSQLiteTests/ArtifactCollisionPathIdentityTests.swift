import Foundation
import ProvenanceEngineContracts
@testable import ProvenanceEngineSQLite
import Testing

@Suite
struct ArtifactCollisionPathIdentityTests {
    @Test
    func pathNormalizationIsExactCaseSensitiveAndDoesNotUseSimilarity() async throws {
        let url = RelatedSessionProjectionTestSupport.temporaryDatabaseURL()
        defer { RelatedSessionProjectionTestSupport.removeTemporaryDatabaseDirectory(for: url) }
        let store = try ProvenanceSQLiteRepository(url: url)
        let fixture = RelatedSessionFixture()
        let repo = fixture.repository()
        let worktree = fixture.worktree(
            id: "worktree-normalize",
            repository: repo,
            path: "/repos/normalize",
            branch: "main",
            head: "head",
            offset: 1
        )
        let target = try await RelatedSessionProjectionTestSupport.seedSession(
            id: "session-target",
            status: "active",
            worktree: worktree,
            repository: repo,
            paths: ["./Sources/../Sources/File.swift"],
            fixture: fixture,
            into: store
        )
        _ = try await RelatedSessionProjectionTestSupport.seedSession(
            id: "session-exact",
            status: "active",
            worktree: worktree,
            repository: repo,
            paths: ["Sources/File.swift"],
            fixture: fixture,
            into: store
        )
        _ = try await RelatedSessionProjectionTestSupport.seedSession(
            id: "session-case",
            status: "active",
            worktree: worktree,
            repository: repo,
            paths: ["sources/File.swift"],
            fixture: fixture,
            into: store
        )
        _ = try await RelatedSessionProjectionTestSupport.seedSession(
            id: "session-same-name",
            status: "active",
            worktree: worktree,
            repository: repo,
            paths: ["Tests/File.swift"],
            fixture: fixture,
            into: store
        )
        _ = try await RelatedSessionProjectionTestSupport.seedSession(
            id: "session-similar",
            status: "active",
            worktree: worktree,
            repository: repo,
            paths: ["Sources/File.swift.bak"],
            fixture: fixture,
            into: store
        )

        let projection = try #require(try await store.artifactCollisions(
            ProvenanceArtifactCollisionRequest(targetSessionID: target.session.id)
        ).projection)
        let candidate = try #require(projection.candidates.first)

        #expect(projection.candidates.count == 1)
        #expect(candidate.artifactIdentity.normalizedPath == "Sources/File.swift")
        #expect(candidate.pathBoundary.caseSensitivity == "case_sensitive")
        #expect(Set(candidate.participants.map(\.sessionID)) == Set(["session-target", "session-exact"]))
    }

    @Test
    func samePathInDifferentRepositoriesIsExplainedButNotReturnedAsCollision() async throws {
        let url = RelatedSessionProjectionTestSupport.temporaryDatabaseURL()
        defer { RelatedSessionProjectionTestSupport.removeTemporaryDatabaseDirectory(for: url) }
        let store = try ProvenanceSQLiteRepository(url: url)
        let fixture = RelatedSessionFixture()
        let targetRepo = fixture.repository(id: "repo-target", path: "/repos/target", remoteSlug: "owner/target")
        let relatedRepo = fixture.repository(id: "repo-related", path: "/repos/related", remoteSlug: "owner/related")
        let targetWorktree = fixture.worktree(
            id: "worktree-target",
            repository: targetRepo,
            path: "/repos/target",
            branch: "main",
            head: "target-head",
            offset: 1
        )
        let relatedWorktree = fixture.worktree(
            id: "worktree-related",
            repository: relatedRepo,
            path: "/repos/related",
            branch: "main",
            head: "related-head",
            offset: 2
        )
        let target = try await RelatedSessionProjectionTestSupport.seedSession(
            id: "session-target",
            status: "active",
            worktree: targetWorktree,
            repository: targetRepo,
            paths: ["Sources/Shared.swift"],
            fixture: fixture,
            into: store
        )
        let related = try await RelatedSessionProjectionTestSupport.seedSession(
            id: "session-related",
            status: "active",
            worktree: relatedWorktree,
            repository: relatedRepo,
            paths: ["Sources/Shared.swift"],
            fixture: fixture,
            into: store
        )
        try await fixture.appendRelationship(
            fixture.relationship(
                sessionID: related.session.id,
                parentSessionID: target.session.id,
                rootSessionID: target.session.id,
                depth: 1,
                offset: 40
            ),
            into: store
        )

        let projection = try #require(try await store.artifactCollisions(
            ProvenanceArtifactCollisionRequest(targetSessionID: target.session.id)
        ).projection)

        #expect(projection.candidates.isEmpty)
        #expect(projection.excludedCandidates.contains { $0.reason == "same_path_different_repository" })
    }

}
