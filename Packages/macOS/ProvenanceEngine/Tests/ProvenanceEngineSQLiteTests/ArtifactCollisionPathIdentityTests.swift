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

    @Test
    func multiRepositoryTargetDoesNotCollidePathFromDifferentRepository() async throws {
        let url = RelatedSessionProjectionTestSupport.temporaryDatabaseURL()
        defer { RelatedSessionProjectionTestSupport.removeTemporaryDatabaseDirectory(for: url) }
        let store = try ProvenanceSQLiteRepository(url: url)
        let fixture = RelatedSessionFixture()
        let targetArtifactRepo = fixture.repository(
            id: "repo-target-artifact",
            path: "/repos/target-artifact",
            remoteSlug: "owner/target-artifact"
        )
        let targetOtherRepo = fixture.repository(
            id: "repo-target-other",
            path: "/repos/target-other",
            remoteSlug: "owner/target-other"
        )
        let targetArtifactWorktree = fixture.worktree(
            id: "worktree-target-artifact",
            repository: targetArtifactRepo,
            path: "/repos/target-artifact",
            branch: "main",
            head: "target-artifact-head",
            offset: 1
        )
        let targetOtherWorktree = fixture.worktree(
            id: "worktree-target-other",
            repository: targetOtherRepo,
            path: "/repos/target-other",
            branch: "main",
            head: "target-other-head",
            offset: 2
        )
        let relatedWorktree = fixture.worktree(
            id: "worktree-related-other-repo",
            repository: targetOtherRepo,
            path: "/repos/related-other-repo",
            branch: "main",
            head: "related-head",
            offset: 3
        )
        let target = try await RelatedSessionProjectionTestSupport.seedSession(
            id: "session-target",
            status: "active",
            worktree: targetArtifactWorktree,
            repository: targetArtifactRepo,
            paths: ["Sources/Shared.swift"],
            fixture: fixture,
            into: store
        )
        try await fixture.appendRepositoryAndWorktree(
            repository: targetOtherRepo,
            worktree: targetOtherWorktree,
            eventID: "event-target-other-worktree",
            into: store
        )
        try await fixture.appendThread(
            fixture.thread(
                id: "thread-target-other-repo",
                sessionID: target.session.id,
                worktreeID: targetOtherWorktree.id,
                providerThreadID: "provider-thread-target-other-repo",
                offset: 30
            ),
            into: store
        )
        let related = try await RelatedSessionProjectionTestSupport.seedSession(
            id: "session-related-other-repo",
            status: "active",
            worktree: relatedWorktree,
            repository: targetOtherRepo,
            paths: ["Sources/Shared.swift"],
            fixture: fixture,
            into: store
        )

        let projection = try #require(try await store.artifactCollisions(
            ProvenanceArtifactCollisionRequest(targetSessionID: target.session.id)
        ).projection)

        #expect(projection.candidates.isEmpty)
        #expect(projection.excludedCandidates.contains {
            $0.sessionID == related.session.id
                && $0.normalizedArtifactPath == "Sources/Shared.swift"
                && $0.reason == "same_path_different_repository"
        })
    }

    @Test
    func participantArtifactsAreScopedToSharedRepositoryPathIdentity() async throws {
        let url = RelatedSessionProjectionTestSupport.temporaryDatabaseURL()
        defer { RelatedSessionProjectionTestSupport.removeTemporaryDatabaseDirectory(for: url) }
        let store = try ProvenanceSQLiteRepository(url: url)
        let fixture = RelatedSessionFixture()
        let targetArtifactRepo = fixture.repository(
            id: "repo-target-artifact",
            path: "/repos/target-artifact",
            remoteSlug: "owner/target-artifact"
        )
        let sharedRepo = fixture.repository(
            id: "repo-shared",
            path: "/repos/shared",
            remoteSlug: "owner/shared"
        )
        let targetArtifactWorktree = fixture.worktree(
            id: "worktree-target-artifact",
            repository: targetArtifactRepo,
            path: "/repos/target-artifact",
            branch: "main",
            head: "target-artifact-head",
            offset: 1
        )
        let targetSharedWorktree = fixture.worktree(
            id: "worktree-target-shared",
            repository: sharedRepo,
            path: "/repos/target-shared",
            branch: "main",
            head: "target-shared-head",
            offset: 2
        )
        let relatedSharedWorktree = fixture.worktree(
            id: "worktree-related-shared",
            repository: sharedRepo,
            path: "/repos/related-shared",
            branch: "main",
            head: "related-shared-head",
            offset: 3
        )
        let target = try await RelatedSessionProjectionTestSupport.seedSession(
            id: "session-target",
            status: "active",
            worktree: targetArtifactWorktree,
            repository: targetArtifactRepo,
            paths: ["Sources/Shared.swift"],
            fixture: fixture,
            into: store
        )
        try await fixture.appendRepositoryAndWorktree(
            repository: sharedRepo,
            worktree: targetSharedWorktree,
            eventID: "event-target-shared-worktree",
            into: store
        )
        let targetSharedThread = fixture.thread(
            id: "thread-target-shared",
            sessionID: target.session.id,
            worktreeID: targetSharedWorktree.id,
            providerThreadID: "provider-thread-target-shared",
            offset: 30
        )
        let targetSharedTurn = fixture.turn(
            id: "turn-target-shared",
            sessionID: target.session.id,
            threadID: targetSharedThread.id,
            providerTurnID: "provider-turn-target-shared",
            startOffset: 31,
            completedOffset: 32
        )
        try await fixture.appendThread(targetSharedThread, into: store)
        try await fixture.appendTurn(targetSharedTurn, into: store)
        try await appendLinkedCollisionChange(
            suffix: "target-shared",
            sessionID: target.session.id,
            threadID: targetSharedThread.id,
            turnID: targetSharedTurn.id,
            repository: sharedRepo,
            worktree: targetSharedWorktree,
            path: "Sources/Shared.swift",
            offset: 33,
            fixture: fixture,
            store: store
        )
        _ = try await RelatedSessionProjectionTestSupport.seedSession(
            id: "session-related-shared",
            status: "active",
            worktree: relatedSharedWorktree,
            repository: sharedRepo,
            sessionOffset: 40,
            paths: ["Sources/Shared.swift"],
            fixture: fixture,
            into: store
        )

        let candidate = try #require(try await store.artifactCollisions(
            ProvenanceArtifactCollisionRequest(targetSessionID: target.session.id)
        ).projection?.candidates.first)
        let targetParticipant = try #require(candidate.participants.first {
            $0.sessionID == target.session.id
        })

        #expect(targetParticipant.matchedArtifacts.map(\.sourceTurnID) == ["turn-target-shared"])
        #expect(targetParticipant.repositoryBoundaries.contains { $0.repositoryID == "repo-target-artifact" } == false)
        #expect(candidate.artifactIdentity.repositoryKeys.contains("repository_id:repo-shared"))
        #expect(candidate.artifactIdentity.repositoryKeys.contains("repository_id:repo-target-artifact") == false)
    }

    private func appendLinkedCollisionChange(
        suffix: String,
        sessionID: String,
        threadID: String,
        turnID: String,
        repository: ProvenanceRepositoryRecord,
        worktree: ProvenanceWorktreeRecord,
        path: String,
        offset: TimeInterval,
        fixture: RelatedSessionFixture,
        store: ProvenanceSQLiteRepository
    ) async throws {
        let changeSet = ProvenanceChangeSetRecord(
            id: "change-set-\(suffix)",
            worktreeID: worktree.id,
            summary: "Linked artifact path identity evidence",
            diffFingerprint: "diff-\(suffix)",
            createdAt: fixture.time(offset)
        )
        let fileChange = ProvenanceFileChangeRecord(
            id: "file-change-\(suffix)",
            changeSetID: changeSet.id,
            repositoryID: repository.id,
            worktreeID: worktree.id,
            path: path,
            status: "modified",
            attributionSource: .observed,
            attributionConfidence: .high,
            updatedAt: fixture.time(offset + 1)
        )
        let attribution = ProvenanceCodingAgentFileChangeAttributionRecord(
            id: "file-attribution-\(suffix)",
            sessionID: sessionID,
            threadID: threadID,
            turnID: turnID,
            provider: "codex",
            operationID: "operation-\(suffix)",
            changeSetID: changeSet.id,
            fileChangeIDs: [fileChange.id],
            paths: [path],
            summary: "Changed \(path)",
            observedAt: fixture.time(offset + 2),
            source: .observed,
            confidence: .high
        )
        try await fixture.append(
            eventID: "event-path-file-change-\(suffix)",
            eventType: "file_modified",
            timestamp: fileChange.updatedAt,
            repositoryID: repository.id,
            worktreeID: worktree.id,
            sessionID: sessionID,
            payload: ProvenanceEventPayload(changeSet: changeSet, fileChanges: [fileChange]),
            into: store
        )
        try await fixture.appendFileAttribution(attribution, into: store)
    }

}
