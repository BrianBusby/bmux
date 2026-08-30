import Foundation
import ProvenanceEngineContracts
@testable import ProvenanceEngineSQLite
import Testing

@Suite
struct ArtifactCollisionChangeSetEvidenceTests {
    @Test
    func linkedFileChangesAndChangeSetsAreCarriedAsEvidence() async throws {
        let url = RelatedSessionProjectionTestSupport.temporaryDatabaseURL()
        defer { RelatedSessionProjectionTestSupport.removeTemporaryDatabaseDirectory(for: url) }
        let store = try ProvenanceSQLiteRepository(url: url)
        let fixture = RelatedSessionFixture()
        let repository = fixture.repository()
        let targetWorktree = fixture.worktree(
            id: "worktree-target",
            repository: repository,
            path: "/repos/linked-target",
            branch: "feature/linked",
            head: "target-head",
            offset: 1
        )
        let relatedWorktree = fixture.worktree(
            id: "worktree-related",
            repository: repository,
            path: "/repos/linked-related",
            branch: "feature/linked",
            head: "related-head",
            offset: 2
        )
        let target = try await RelatedSessionProjectionTestSupport.seedSession(
            id: "session-target",
            status: "active",
            worktree: targetWorktree,
            repository: repository,
            fixture: fixture,
            into: store
        )
        _ = try await RelatedSessionProjectionTestSupport.seedSession(
            id: "session-related",
            status: "active",
            worktree: relatedWorktree,
            repository: repository,
            fixture: fixture,
            into: store
        )
        try await appendLinkedChange(
            suffix: "target",
            sessionID: target.session.id,
            threadID: target.thread.id,
            turnID: target.turn.id,
            repository: repository,
            worktree: targetWorktree,
            path: "Sources/Linked.swift",
            offset: 50,
            fixture: fixture,
            store: store
        )
        try await appendLinkedChange(
            suffix: "related",
            sessionID: "session-related",
            threadID: "thread-session-related",
            turnID: "turn-session-related",
            repository: repository,
            worktree: relatedWorktree,
            path: "Sources/Linked.swift",
            offset: 55,
            fixture: fixture,
            store: store
        )

        let candidate = try #require(try await store.artifactCollisions(
            ProvenanceArtifactCollisionRequest(targetSessionID: target.session.id)
        ).projection?.candidates.first)
        let artifacts = candidate.participants.flatMap(\.matchedArtifacts).map(\.artifact)
        let evidenceFields = Set(candidate.evidence.compactMap(\.field))

        #expect(Set(artifacts.compactMap(\.fileChangeID)) == Set(["file-change-target", "file-change-related"]))
        #expect(Set(artifacts.compactMap(\.changeSetID)) == Set(["change-set-target", "change-set-related"]))
        #expect(evidenceFields.contains("file_change:file-change-target"))
        #expect(evidenceFields.contains("file_change:file-change-related"))
        #expect(evidenceFields.contains("coding_agent_file_change_attribution:file-attribution-target"))
        #expect(evidenceFields.contains("coding_agent_file_change_attribution:file-attribution-related"))
        #expect(candidate.evidence.contains {
            $0.kind == "event" && $0.eventType == "file_modified" && $0.id == "event-file-change-target"
        })
    }

    private func appendLinkedChange(
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
            summary: "Linked artifact collision evidence",
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
            eventID: "event-file-change-\(suffix)",
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
