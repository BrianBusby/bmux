import Foundation
import ProvenanceEngineContracts
@testable import ProvenanceEngineSQLite
import Testing

@Suite
struct RelatedSessionProjectionRevisionTests {
    @Test
    func revisionsFreshnessDuplicatesAndRebuildsRemainDeterministic() async throws {
        let url = RelatedSessionProjectionTestSupport.temporaryDatabaseURL()
        defer { RelatedSessionProjectionTestSupport.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)
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
            branch: "other",
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
            into: repository
        )
        let related = try await RelatedSessionProjectionTestSupport.seedSession(
            id: "session-related",
            status: "completed",
            worktree: relatedWorktree,
            repository: repo,
            paths: ["Sources/Shared.swift"],
            fixture: fixture,
            into: repository
        )
        let first = try #require(try await repository.relatedSessions(
            ProvenanceRelatedSessionRequest(targetSessionID: target.session.id)
        ).projection)
        let firstRevisionCount = try await repository.storageSummary().relatedSessionRevisionCount
        let second = try #require(try await repository.relatedSessions(
            ProvenanceRelatedSessionRequest(targetSessionID: target.session.id)
        ).projection)

        #expect(second.projection.revisionID == first.projection.revisionID)
        #expect(try await repository.storageSummary().relatedSessionRevisionCount == firstRevisionCount)

        let duplicateAttribution = fixture.fileAttribution(
            paths: ["Sources/Shared.swift"],
            sessionID: related.session.id,
            threadID: related.thread.id,
            turnID: related.turn.id,
            offset: 40,
            idSuffix: related.turn.id
        )
        try await fixture.appendFileAttribution(
            duplicateAttribution,
            eventID: "event-duplicate-related-artifact",
            into: repository
        )
        let afterDuplicate = try #require(try await repository.relatedSessions(
            ProvenanceRelatedSessionRequest(targetSessionID: target.session.id)
        ).projection)

        #expect(afterDuplicate.projection.revisionID == first.projection.revisionID)
        #expect(afterDuplicate.projection.sourceEvidenceWatermark != first.projection.sourceEvidenceWatermark)
        #expect(try await repository.storageSummary().relatedSessionRevisionCount == firstRevisionCount)

        _ = try await repository.rebuildProjectionsFromEventLedger(batchSize: 2)
        let afterRebuild = try #require(try await repository.relatedSessions(
            ProvenanceRelatedSessionRequest(targetSessionID: target.session.id)
        ).projection)

        #expect(afterRebuild == afterDuplicate)
    }

    @Test
    func lateCorrectedAndOutOfOrderEvidenceChangesRevisionDeterministically() async throws {
        let url = RelatedSessionProjectionTestSupport.temporaryDatabaseURL()
        defer { RelatedSessionProjectionTestSupport.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)
        let fixture = RelatedSessionFixture()
        let repo = fixture.repository()
        let targetWorktree = fixture.worktree(
            id: "worktree-target",
            repository: repo,
            path: "/repos/correction-target",
            branch: "feature/correct",
            head: "target-head",
            offset: 10
        )
        let relatedWorktree = fixture.worktree(
            id: "worktree-related",
            repository: repo,
            path: "/repos/correction-related",
            branch: "feature/old",
            head: "old-head",
            offset: 11
        )
        let target = try await RelatedSessionProjectionTestSupport.seedSession(
            id: "session-target",
            status: "active",
            worktree: targetWorktree,
            repository: repo,
            fixture: fixture,
            into: repository
        )
        _ = try await RelatedSessionProjectionTestSupport.seedSession(
            id: "session-related",
            status: "completed",
            worktree: relatedWorktree,
            repository: repo,
            fixture: fixture,
            into: repository
        )
        let before = try #require(try await repository.relatedSessions(
            ProvenanceRelatedSessionRequest(targetSessionID: target.session.id)
        ).projection)
        let beforeBrief = try #require(before.relatedSessions.first { $0.sessionID == "session-related" })

        #expect(beforeBrief.relationshipReasons.map(\.kind).contains(.sameRepository))
        #expect(beforeBrief.relationshipReasons.map(\.kind).contains(.sameBranch) == false)

        let correctedWorktree = fixture.worktree(
            id: relatedWorktree.id,
            repository: repo,
            path: relatedWorktree.path,
            branch: "feature/correct",
            head: "corrected-head",
            offset: 5
        )
        try await fixture.appendRepositoryAndWorktree(
            repository: repo,
            worktree: correctedWorktree,
            into: repository
        )
        let after = try #require(try await repository.relatedSessions(
            ProvenanceRelatedSessionRequest(targetSessionID: target.session.id)
        ).projection)
        let afterBrief = try #require(after.relatedSessions.first { $0.sessionID == "session-related" })

        #expect(after.projection.revisionID != before.projection.revisionID)
        #expect((after.projection.sourceEvidenceWatermark ?? 0) > (before.projection.sourceEvidenceWatermark ?? 0))
        #expect(afterBrief.relationshipReasons.map(\.kind).contains(.sameBranch))
        #expect(afterBrief.worktreeBoundaries.first?.head == "corrected-head")
    }

    @Test
    func correctedHeadBoundaryChangesProjectionRevision() async throws {
        let url = RelatedSessionProjectionTestSupport.temporaryDatabaseURL()
        defer { RelatedSessionProjectionTestSupport.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)
        let fixture = RelatedSessionFixture()
        let repo = fixture.repository()
        let targetWorktree = fixture.worktree(
            id: "worktree-target",
            repository: repo,
            path: "/repos/head-target",
            branch: "main",
            head: "target-head",
            offset: 1
        )
        let relatedWorktree = fixture.worktree(
            id: "worktree-related",
            repository: repo,
            path: "/repos/head-related",
            branch: "other",
            head: "old-head",
            offset: 2
        )
        let target = try await RelatedSessionProjectionTestSupport.seedSession(
            id: "session-target",
            status: "active",
            worktree: targetWorktree,
            repository: repo,
            fixture: fixture,
            into: repository
        )
        _ = try await RelatedSessionProjectionTestSupport.seedSession(
            id: "session-related",
            status: "completed",
            worktree: relatedWorktree,
            repository: repo,
            fixture: fixture,
            into: repository
        )
        let before = try #require(try await repository.relatedSessions(
            ProvenanceRelatedSessionRequest(targetSessionID: target.session.id)
        ).projection)
        let beforeBrief = try #require(before.relatedSessions.first { $0.sessionID == "session-related" })

        #expect(beforeBrief.worktreeBoundaries.first?.head == "old-head")

        let correctedWorktree = fixture.worktree(
            id: relatedWorktree.id,
            repository: repo,
            path: relatedWorktree.path,
            branch: relatedWorktree.branch,
            head: "corrected-head",
            offset: 20
        )
        try await fixture.appendRepositoryAndWorktree(
            repository: repo,
            worktree: correctedWorktree,
            eventID: "event-corrected-related-head",
            into: repository
        )
        let after = try #require(try await repository.relatedSessions(
            ProvenanceRelatedSessionRequest(targetSessionID: target.session.id)
        ).projection)
        let afterBrief = try #require(after.relatedSessions.first { $0.sessionID == "session-related" })

        #expect(after.projection.revisionID != before.projection.revisionID)
        #expect(afterBrief.relationshipReasons.map(\.kind).contains(.sameRepository))
        #expect(afterBrief.relationshipReasons.map(\.kind).contains(.sameBranch) == false)
        #expect(afterBrief.worktreeBoundaries.first?.head == "corrected-head")
    }

    @Test
    func partialEvidenceKeepsFactsAvailableWithoutInventingMissingBoundaries() async throws {
        let url = RelatedSessionProjectionTestSupport.temporaryDatabaseURL()
        defer { RelatedSessionProjectionTestSupport.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)
        let fixture = RelatedSessionFixture()
        let target = fixture.session(
            id: "session-target",
            worktreeID: nil,
            status: "active",
            offset: 1
        )
        let child = fixture.session(
            id: "session-child",
            worktreeID: nil,
            status: "interrupted",
            offset: 2
        )

        try await fixture.appendSession(target, into: repository)
        try await fixture.appendSession(child, into: repository)
        try await fixture.appendRelationship(
            fixture.relationship(
                sessionID: child.id,
                parentSessionID: target.id,
                rootSessionID: target.id,
                depth: 1,
                offset: 3
            ),
            into: repository
        )

        let projection = try #require(try await repository.relatedSessions(
            ProvenanceRelatedSessionRequest(targetSessionID: target.id)
        ).projection)
        let brief = try #require(projection.relatedSessions.first)

        #expect(brief.sessionID == child.id)
        #expect(brief.relationshipReasons.map(\.kind) == [.sessionTreeDescendant])
        #expect(brief.repositoryBoundaries.isEmpty)
        #expect(brief.worktreeBoundaries.isEmpty)
        #expect(brief.completeness.status == "partial")
        #expect(brief.completeness.fields.first { $0.field == "worktree_boundaries" }?.status == "not_observed")
        #expect(brief.sessionOutcomeRevisionID != nil)
        #expect(brief.outcomeBrief?.objectives.isEmpty == true)
    }

    @Test
    func recentBoundaryExcludesStaleRelatedSessionsWithBoundedExplanation() async throws {
        let url = RelatedSessionProjectionTestSupport.temporaryDatabaseURL()
        defer { RelatedSessionProjectionTestSupport.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)
        let fixture = RelatedSessionFixture()
        let repo = fixture.repository()
        let worktree = fixture.worktree(
            id: "worktree-recent",
            repository: repo,
            path: "/repos/recent",
            branch: "main",
            head: "recent-head",
            offset: 1
        )
        let target = try await RelatedSessionProjectionTestSupport.seedSession(
            id: "session-target",
            status: "active",
            worktree: worktree,
            repository: repo,
            sessionOffset: 20,
            fixture: fixture,
            into: repository
        )
        _ = try await RelatedSessionProjectionTestSupport.seedSession(
            id: "session-stale",
            status: "completed",
            worktree: worktree,
            repository: repo,
            sessionOffset: 2,
            fixture: fixture,
            into: repository
        )

        let projection = try #require(try await repository.relatedSessions(
            ProvenanceRelatedSessionRequest(
                targetSessionID: target.session.id,
                updatedAfter: fixture.time(10),
                exclusionLimit: 1
            )
        ).projection)

        #expect(projection.relatedSessions.isEmpty)
        #expect(projection.excludedCandidates.map(\.sessionID) == ["session-stale"])
        #expect(projection.excludedCandidates.map(\.reason) == ["outside_recent_boundary"])
    }

    @Test
    func sessionWorkModelSemanticFieldsRemainSeparateFromRelationshipReasons() async throws {
        let url = RelatedSessionProjectionTestSupport.temporaryDatabaseURL()
        defer { RelatedSessionProjectionTestSupport.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)
        let fixture = RelatedSessionFixture()
        let repo = fixture.repository()
        let worktree = fixture.worktree(
            id: "worktree-semantic",
            repository: repo,
            path: "/repos/semantic",
            branch: "main",
            head: "semantic-head",
            offset: 1
        )
        let target = try await RelatedSessionProjectionTestSupport.seedSession(
            id: "session-target",
            status: "active",
            worktree: worktree,
            repository: repo,
            fixture: fixture,
            into: repository
        )
        let related = try await RelatedSessionProjectionTestSupport.seedSession(
            id: "session-related",
            status: "active",
            worktree: worktree,
            repository: repo,
            promptText: "Implement cross-session work awareness.",
            includeReasoning: true,
            fixture: fixture,
            into: repository
        )
        _ = try await repository.publishCodingAgentSessionSemanticInferences(
            ProvenanceCodingAgentSessionSemanticInferenceRequest(
                sessionID: related.session.id,
                createdAt: fixture.time(60)
            )
        )

        let projection = try #require(try await repository.relatedSessions(
            ProvenanceRelatedSessionRequest(targetSessionID: target.session.id)
        ).projection)
        let brief = try #require(projection.relatedSessions.first { $0.sessionID == related.session.id })

        #expect(brief.semanticFields.isEmpty == false)
        #expect(brief.sessionWorkModelRevision?.semanticInferenceIDs.isEmpty == false)
        #expect(brief.semanticFields.allSatisfy { $0.record != nil })
        #expect(brief.relationshipReasons.map(\.kind).contains(.sameWorktree))
        #expect(brief.relationshipReasons.allSatisfy {
            $0.kind != .sharedExternalIdentity && $0.kind != .sharedProviderThread
        })
    }

    @Test
    func unsupportedAssistantProseDoesNotCreateRelationshipFacts() async throws {
        let url = RelatedSessionProjectionTestSupport.temporaryDatabaseURL()
        defer { RelatedSessionProjectionTestSupport.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)
        let fixture = RelatedSessionFixture()
        let targetRepo = fixture.repository(
            id: "repository-target",
            path: "/repos/target",
            remoteSlug: "owner/target",
            offset: 1
        )
        let targetWorktree = fixture.worktree(
            id: "worktree-target",
            repository: targetRepo,
            path: "/repos/target",
            branch: "main",
            head: "target-head",
            offset: 2
        )
        let unrelatedRepo = fixture.repository(
            id: "repository-unrelated",
            path: "/repos/unrelated",
            remoteSlug: "owner/unrelated",
            offset: 3
        )
        let unrelatedWorktree = fixture.worktree(
            id: "worktree-unrelated",
            repository: unrelatedRepo,
            path: "/repos/unrelated",
            branch: "other",
            head: "unrelated-head",
            offset: 4
        )
        let target = try await RelatedSessionProjectionTestSupport.seedSession(
            id: "session-target",
            status: "active",
            worktree: targetWorktree,
            repository: targetRepo,
            fixture: fixture,
            into: repository
        )
        let unrelated = try await RelatedSessionProjectionTestSupport.seedSession(
            id: "session-unrelated",
            status: "active",
            worktree: unrelatedWorktree,
            repository: unrelatedRepo,
            promptText: "This prose says it shares session-target work, but it is not evidence.",
            fixture: fixture,
            into: repository
        )
        let assistant = ProvenanceCodingAgentAssistantMessageRecord(
            id: "assistant-unrelated",
            sessionID: unrelated.session.id,
            threadID: unrelated.thread.id,
            turnID: unrelated.turn.id,
            provider: "codex",
            itemID: "assistant-unrelated-item",
            text: "I am working in the same repository and branch as session-target.",
            completedAt: fixture.time(50),
            source: .observed,
            confidence: .high
        )
        try await fixture.append(
            eventID: "event-assistant-unrelated",
            eventType: .codingAgentAssistantMessageCompleted,
            timestamp: assistant.completedAt,
            repositoryID: nil,
            worktreeID: nil,
            sessionID: assistant.sessionID,
            payload: ProvenanceEventPayload(codingAgentAssistantMessage: assistant),
            into: repository
        )

        let projection = try #require(try await repository.relatedSessions(
            ProvenanceRelatedSessionRequest(targetSessionID: target.session.id)
        ).projection)

        #expect(projection.relatedSessions.isEmpty)
    }
}
