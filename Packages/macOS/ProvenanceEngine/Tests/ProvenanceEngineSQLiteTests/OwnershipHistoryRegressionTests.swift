import Foundation
import ProvenanceEngineContracts
@testable import ProvenanceEngineSQLite
import Testing

@Suite struct OwnershipHistoryRegressionTests {
    @Test func priorCrossSessionRevisionsDoNotExposeDisputedEvidence() async throws {
        let url = RelatedSessionProjectionTestSupport.temporaryDatabaseURL()
        defer { RelatedSessionProjectionTestSupport.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)
        let fixture = RelatedSessionFixture()
        let repo = fixture.repository()
        let targetWorktree = fixture.worktree(id: "target-wt", repository: repo, path: "/repos/target", branch: "main", head: "a", offset: 1)
        let relatedWorktree = fixture.worktree(id: "related-wt", repository: repo, path: "/repos/related", branch: "main", head: "b", offset: 2)
        let target = try await RelatedSessionProjectionTestSupport.seedSession(id: "target", status: "active", worktree: targetWorktree,
            repository: repo, paths: ["Sources/Shared.swift"], fixture: fixture, into: repository)
        let related = try await RelatedSessionProjectionTestSupport.seedSession(id: "related", status: "active", worktree: relatedWorktree,
            repository: repo, paths: ["Sources/Shared.swift"], fixture: fixture, into: repository)
        let relatedSnapshot = try #require(try await repository.relatedSessions(.init(targetSessionID: target.session.id)).projection)
        #expect(relatedSnapshot.relatedSessions.contains { $0.sessionID == related.session.id })
        let collisionSnapshot = try #require(try await repository.artifactCollisions(.init(targetSessionID: target.session.id)).projection)
        #expect(collisionSnapshot.candidates.contains { $0.participants.contains { $0.sessionID == related.session.id } })
        let oldTurn = related.turn
        let collision = ProvenanceCodingAgentTurnRecord(id: oldTurn.id, sessionID: target.session.id,
            provider: oldTurn.provider, providerTurnID: oldTurn.providerTurnID, status: oldTurn.status,
            startedAt: oldTurn.startedAt, updatedAt: oldTurn.updatedAt, source: oldTurn.source, confidence: oldTurn.confidence)
        try await repository.appendEvent(.init(id: "conflicting-turn", eventType: .codingAgentTurnObserved,
            timestamp: collision.updatedAt, sessionID: target.session.id, source: .observed, confidence: .high,
            payload: .init(codingAgentTurn: collision)))
        let oldRelated = try await repository.relatedSessions(.init(targetSessionID: target.session.id,
            revisionID: relatedSnapshot.projection.revisionID))
        #expect(!oldRelated.found)
        #expect(oldRelated.reason == "ownership_unresolved")
        let oldCollision = try await repository.artifactCollisions(.init(targetSessionID: target.session.id,
            revisionID: collisionSnapshot.projection.revisionID))
        #expect(!oldCollision.found)
        #expect(oldCollision.reason == "ownership_unresolved")
        #expect(try await repository.relatedSessions(.init(targetSessionID: target.session.id)).found)
    }
}
