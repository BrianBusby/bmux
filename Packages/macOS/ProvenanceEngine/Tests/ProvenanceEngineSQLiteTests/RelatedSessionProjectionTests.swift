import Foundation
import ProvenanceEngineContracts
@testable import ProvenanceEngineSQLite
import Testing

@Suite
struct RelatedSessionProjectionTests {
    @Test
    func noRelatedSessionsReturnsEmptyProjection() async throws {
        let url = RelatedSessionProjectionTestSupport.temporaryDatabaseURL()
        defer { RelatedSessionProjectionTestSupport.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)
        let fixture = RelatedSessionFixture()
        let repo = fixture.repository()
        let worktree = fixture.worktree(
            id: "worktree-target",
            repository: repo,
            path: "/repos/related",
            branch: "main",
            head: "target-head",
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

        let response = try await repository.relatedSessions(
            ProvenanceRelatedSessionRequest(targetSessionID: target.session.id)
        )
        let projection = try #require(response.projection)

        #expect(response.found == true)
        #expect(projection.relatedSessions.isEmpty)
        #expect(projection.completeness.status == "empty")
        #expect(projection.projection.resultLimit == 10)
        #expect(projection.projection.exclusionLimit == 10)
    }

    @Test
    func repositoryWorktreeBranchAndArtifactReasonsAreExplicitAndBounded() async throws {
        let url = RelatedSessionProjectionTestSupport.temporaryDatabaseURL()
        defer { RelatedSessionProjectionTestSupport.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)
        let fixture = RelatedSessionFixture()
        let repo = fixture.repository()
        let targetWorktree = fixture.worktree(
            id: "worktree-target",
            repository: repo,
            path: "/repos/related",
            branch: "feature/shared",
            head: "target-head",
            offset: 1
        )
        let sameBranchWorktree = fixture.worktree(
            id: "worktree-same-branch",
            repository: repo,
            path: "/repos/related-same-branch",
            branch: "feature/shared",
            head: "same-branch-head",
            offset: 2
        )
        let differentBranchWorktree = fixture.worktree(
            id: "worktree-different-branch",
            repository: repo,
            path: "/repos/related-different-branch",
            branch: "feature/other",
            head: "other-head",
            offset: 3
        )
        let otherRepo = fixture.repository(
            id: "repository-other",
            path: "/repos/other",
            remoteSlug: "owner/other",
            offset: 4
        )
        let unrelatedWorktree = fixture.worktree(
            id: "worktree-unrelated",
            repository: otherRepo,
            path: "/repos/other",
            branch: "feature/shared",
            head: "other-head",
            offset: 5
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
        _ = try await RelatedSessionProjectionTestSupport.seedSession(
            id: "session-same-worktree",
            status: "completed",
            worktree: targetWorktree,
            repository: repo,
            paths: ["Sources/SameWorktree.swift"],
            fixture: fixture,
            into: repository
        )
        _ = try await RelatedSessionProjectionTestSupport.seedSession(
            id: "session-same-branch",
            status: "completed",
            worktree: sameBranchWorktree,
            repository: repo,
            paths: ["Sources/Shared.swift"],
            fixture: fixture,
            into: repository
        )
        _ = try await RelatedSessionProjectionTestSupport.seedSession(
            id: "session-different-branch",
            status: "completed",
            worktree: differentBranchWorktree,
            repository: repo,
            paths: ["Sources/Other.swift"],
            fixture: fixture,
            into: repository
        )
        _ = try await RelatedSessionProjectionTestSupport.seedSession(
            id: "session-unrelated",
            status: "completed",
            worktree: unrelatedWorktree,
            repository: otherRepo,
            paths: ["Sources/Shared.swift"],
            fixture: fixture,
            into: repository
        )

        let projection = try #require(try await repository.relatedSessions(
            ProvenanceRelatedSessionRequest(targetSessionID: target.session.id, limit: 10)
        ).projection)
        let sameWorktreeBrief = try #require(projection.relatedSessions.first {
            $0.sessionID == "session-same-worktree"
        })
        let sameBranchBrief = try #require(projection.relatedSessions.first {
            $0.sessionID == "session-same-branch"
        })
        let differentBranchBrief = try #require(projection.relatedSessions.first {
            $0.sessionID == "session-different-branch"
        })

        #expect(projection.relatedSessions.map(\.sessionID).contains("session-unrelated") == false)
        #expect(sameWorktreeBrief.relationshipReasons.map(\.kind).contains(.sameWorktree))
        #expect(sameWorktreeBrief.relationshipReasons.map(\.kind).contains(.sameRepository))
        #expect(sameBranchBrief.relationshipReasons.map(\.kind).contains(.sameBranch))
        #expect(sameBranchBrief.relationshipReasons.map(\.kind).contains(.sameRepository))
        #expect(sameBranchBrief.relationshipReasons.map(\.kind).contains(.sharedChangedArtifact))
        #expect(differentBranchBrief.relationshipReasons.map(\.kind).contains(.sameRepository))
        #expect(differentBranchBrief.relationshipReasons.map(\.kind).contains(.sameBranch) == false)
        #expect(sameBranchBrief.outcomeBrief?.changedArtifacts.map(\.artifact.path) == ["Sources/Shared.swift"])
        #expect(sameBranchBrief.sessionOutcomeRevisionID == sameBranchBrief.sessionOutcomeProjection?.revisionID)
        #expect(sameBranchBrief.worktreeBoundaries.first?.branch == "feature/shared")
        #expect(sameBranchBrief.worktreeBoundaries.first?.head == "same-branch-head")
        #expect(sameBranchBrief.relationshipReasons.allSatisfy { !$0.evidence.isEmpty })
    }

    @Test
    func sessionTreeParentChildAndSiblingReasonsAreReturned() async throws {
        let url = RelatedSessionProjectionTestSupport.temporaryDatabaseURL()
        defer { RelatedSessionProjectionTestSupport.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)
        let fixture = RelatedSessionFixture()
        let repo = fixture.repository()
        let worktree = fixture.worktree(
            id: "worktree-tree",
            repository: repo,
            path: "/repos/tree",
            branch: "tree",
            head: "tree-head",
            offset: 1
        )
        let parent = try await RelatedSessionProjectionTestSupport.seedSession(
            id: "session-parent",
            status: "active",
            worktree: worktree,
            repository: repo,
            fixture: fixture,
            into: repository
        )
        let target = try await RelatedSessionProjectionTestSupport.seedSession(
            id: "session-target",
            status: "active",
            worktree: worktree,
            repository: repo,
            fixture: fixture,
            into: repository
        )
        let sibling = try await RelatedSessionProjectionTestSupport.seedSession(
            id: "session-sibling",
            status: "completed",
            worktree: worktree,
            repository: repo,
            fixture: fixture,
            into: repository
        )
        let child = try await RelatedSessionProjectionTestSupport.seedSession(
            id: "session-child",
            status: "active",
            worktree: worktree,
            repository: repo,
            fixture: fixture,
            into: repository
        )
        try await fixture.appendRelationship(
            fixture.relationship(
                sessionID: target.session.id,
                parentSessionID: parent.session.id,
                rootSessionID: parent.session.id,
                depth: 1,
                offset: 20
            ),
            into: repository
        )
        try await fixture.appendRelationship(
            fixture.relationship(
                sessionID: sibling.session.id,
                parentSessionID: parent.session.id,
                rootSessionID: parent.session.id,
                depth: 1,
                offset: 21
            ),
            into: repository
        )
        try await fixture.appendRelationship(
            fixture.relationship(
                sessionID: child.session.id,
                parentSessionID: target.session.id,
                rootSessionID: parent.session.id,
                depth: 2,
                offset: 22
            ),
            into: repository
        )

        let projection = try #require(try await repository.relatedSessions(
            ProvenanceRelatedSessionRequest(targetSessionID: target.session.id)
        ).projection)
        let ancestorBrief = try #require(projection.relatedSessions.first { $0.sessionID == parent.session.id })
        let siblingBrief = try #require(projection.relatedSessions.first { $0.sessionID == sibling.session.id })
        let descendantBrief = try #require(projection.relatedSessions.first { $0.sessionID == child.session.id })

        #expect(ancestorBrief.relationshipReasons.map(\.kind).contains(.sessionTreeAncestor))
        #expect(descendantBrief.relationshipReasons.map(\.kind).contains(.sessionTreeDescendant))
        #expect(siblingBrief.relationshipReasons.map(\.kind).contains(.sessionTreeSibling))
        #expect(ancestorBrief.relationshipReasons.first { $0.kind == .sessionTreeAncestor }?.relationshipDepth == 1)
        #expect(descendantBrief.relationshipReasons.first { $0.kind == .sessionTreeDescendant }?.relationshipDepth == 1)
        #expect(siblingBrief.relationshipReasons.first { $0.kind == .sessionTreeSibling }?.relationshipDepth == 1)
    }

    @Test
    func lifecycleAndCompletionStatesComeFromSessionOutcome() async throws {
        let url = RelatedSessionProjectionTestSupport.temporaryDatabaseURL()
        defer { RelatedSessionProjectionTestSupport.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)
        let fixture = RelatedSessionFixture()
        let repo = fixture.repository()
        let worktree = fixture.worktree(
            id: "worktree-lifecycle",
            repository: repo,
            path: "/repos/lifecycle",
            branch: "main",
            head: "life-head",
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
        for status in ["active", "completed", "interrupted", "incomplete"] {
            _ = try await RelatedSessionProjectionTestSupport.seedSession(
                id: "session-\(status)",
                status: status,
                worktree: worktree,
                repository: repo,
                fixture: fixture,
                into: repository
            )
        }

        let projection = try #require(try await repository.relatedSessions(
            ProvenanceRelatedSessionRequest(targetSessionID: target.session.id, limit: 10)
        ).projection)
        let states = Dictionary(uniqueKeysWithValues: projection.relatedSessions.map {
            ($0.sessionID, ($0.lifecycleState, $0.completionState))
        })

        #expect(states["session-active"]?.0 == "active")
        #expect(states["session-active"]?.1 == "incomplete")
        #expect(states["session-completed"]?.1 == "completed")
        #expect(states["session-interrupted"]?.1 == "interrupted")
        #expect(states["session-incomplete"]?.1 == "incomplete")
    }

    @Test
    func deterministicOrderingAndLimitsUseStrengthFreshnessAndStableID() async throws {
        let url = RelatedSessionProjectionTestSupport.temporaryDatabaseURL()
        defer { RelatedSessionProjectionTestSupport.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)
        let fixture = RelatedSessionFixture()
        let repo = fixture.repository()
        let targetWorktree = fixture.worktree(
            id: "worktree-target",
            repository: repo,
            path: "/repos/order-target",
            branch: "feature/order",
            head: "target-head",
            offset: 1
        )
        let branchWorktree = fixture.worktree(
            id: "worktree-branch",
            repository: repo,
            path: "/repos/order-branch",
            branch: "feature/order",
            head: "branch-head",
            offset: 3
        )
        let repoOnlyWorktree = fixture.worktree(
            id: "worktree-repo-only",
            repository: repo,
            path: "/repos/order-repo",
            branch: "feature/repo",
            head: "repo-head",
            offset: 4
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
            id: "session-repo-only",
            status: "completed",
            worktree: repoOnlyWorktree,
            repository: repo,
            sessionOffset: 30,
            fixture: fixture,
            into: repository
        )
        _ = try await RelatedSessionProjectionTestSupport.seedSession(
            id: "session-same-branch",
            status: "completed",
            worktree: branchWorktree,
            repository: repo,
            sessionOffset: 20,
            fixture: fixture,
            into: repository
        )
        _ = try await RelatedSessionProjectionTestSupport.seedSession(
            id: "session-same-worktree",
            status: "completed",
            worktree: targetWorktree,
            repository: repo,
            sessionOffset: 10,
            fixture: fixture,
            into: repository
        )

        let projection = try #require(try await repository.relatedSessions(
            ProvenanceRelatedSessionRequest(targetSessionID: target.session.id, limit: 2)
        ).projection)

        #expect(projection.relatedSessions.map(\.sessionID) == [
            "session-same-worktree",
            "session-same-branch",
        ])
        #expect(projection.excludedCandidates.map(\.sessionID) == ["session-repo-only"])
        #expect(projection.excludedCandidates.map(\.reason) == ["result_limit"])
    }

    @Test
    func briefsCarryWorkStateSemanticsWithScopedEvidenceAndAvailability() async throws {
        typealias Support = RelatedSessionWorkStateSemanticTestSupport
        let url = RelatedSessionProjectionTestSupport.temporaryDatabaseURL()
        defer { RelatedSessionProjectionTestSupport.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)
        let seeded = try await Support.seedWorkStateSessions(into: repository)

        let projection = try #require(try await repository.relatedSessions(
            ProvenanceRelatedSessionRequest(targetSessionID: seeded.target.session.id, limit: 10)
        ).projection)
        let openBrief = try #require(projection.relatedSessions.first {
            $0.sessionID == seeded.open.session.id
        })
        let bypassedBrief = try #require(projection.relatedSessions.first {
            $0.sessionID == seeded.bypassed.session.id
        })
        let openMilestones = try Support.milestonePayload(from: openBrief)
        let bypassedMilestones = try Support.milestonePayload(from: bypassedBrief)
        let openBlockers = try Support.blockerPayload(from: openBrief)
        let bypassedBlockers = try Support.blockerPayload(from: bypassedBrief)
        let openApproaches = try Support.approachPayload(from: openBrief)
        let openBlockerField = try Support.semanticField(.blockers, in: openBrief)
        let bypassedBlockerField = try Support.semanticField(.blockers, in: bypassedBrief)
        let openApproachField = try Support.semanticField(.approachChanges, in: openBrief)

        #expect(openBrief.semanticFields.map(\.kind) == Support.expectedSemanticFieldKinds)
        #expect(openMilestones.milestones.first?.title == bypassedMilestones.milestones.first?.title)
        #expect(openBlockerField.scopeID == seeded.open.session.id)
        #expect(bypassedBlockerField.scopeID == seeded.bypassed.session.id)
        #expect(openBlockers.blockers.first?.affectedActivity == "run package suite")
        #expect(openBlockers.blockers.first?.state == .reportedOpen)
        #expect(bypassedBlockers.blockers.first?.affectedActivity == "run package suite")
        #expect(bypassedBlockers.blockers.first?.state == .reportedBypassed)
        #expect(openApproachField.scopeID == seeded.open.session.id)
        #expect(openApproaches.approachChanges.first?.state == .reportedReplaced)
        #expect(openBlockers.blockers.first?.sourceEvidenceRefs == [
            .init(kind: "coding_agent_assistant_message", id: seeded.openEvidenceID),
        ])
        #expect(bypassedBlockers.blockers.first?.sourceEvidenceRefs.contains {
            $0.kind == "coding_agent_assistant_message" && $0.id == seeded.bypassedResolutionEvidenceID
        } == true)
        #expect(openBlockerField.record?.supportingEvidenceRefs.contains {
            $0.kind == "coding_agent_assistant_message" && $0.id == seeded.openEvidenceID
        } == true)
        #expect(openBlockerField.record?.producerID == ProvenanceCodingAgentSessionSemanticInferenceProducer.producerID)
        #expect(openBlockerField.record?.producerVersion == ProvenanceCodingAgentSessionSemanticInferenceProducer.producerVersion)
        #expect(Support.availability(.blockers, in: openBrief)?.status == "observed")
        #expect(Support.availability(.approachChanges, in: openBrief)?.status == "observed")
        #expect(openBrief.relationshipReasons.allSatisfy {
            ![.sameRepository, .sameWorktree, .sameBranch].contains($0.kind) || !$0.evidence.isEmpty
        })
    }
}
