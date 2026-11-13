import Foundation
import ProvenanceEngineContracts
@testable import ProvenanceEngineSQLite
import Testing

@Suite
struct TaskRelevanceEvidenceTests {
    @Test
    func freshCallerCanInspectPathAndObjectiveSourceFactsInRepositoryPeers() async throws {
        let url = RelatedSessionProjectionTestSupport.temporaryDatabaseURL()
        defer { RelatedSessionProjectionTestSupport.removeTemporaryDatabaseDirectory(for: url) }
        let store = try ProvenanceSQLiteRepository(url: url)
        let fixture = RelatedSessionFixture()
        let repo = fixture.repository(id: "eval-repo", path: "/repos/eval", remoteSlug: "owner/eval")
        let otherRepo = fixture.repository(id: "other-repo", path: "/repos/other", remoteSlug: "owner/other")
        let sessions: [(String, String, ProvenanceRepositoryRecord, String, String, [String])] = [
            ("caller", "active", repo, "caller", "Work on a fresh task", []),
            ("path-active", "active", repo, "feature/active", "Inspect shared code", ["Sources/Example.swift"]),
            ("path-history", "completed", repo, "feature/history", "Repair cache invalidation", ["Sources/Example.swift"]),
            ("unrelated", "completed", repo, "feature/other", "Change sidebar", ["Sources/Sidebar.swift"]),
            ("other-repo", "completed", otherRepo, "feature/other", "Inspect shared code", ["Sources/Example.swift"]),
        ]
        for (index, item) in sessions.enumerated() {
            let (id, status, repository, branch, prompt, paths) = item
            let worktree = fixture.worktree(id: "worktree-\(id)", repository: repository,
                path: "/worktrees/\(id)", branch: branch, head: "head-\(id)", offset: Double(index + 1))
            _ = try await RelatedSessionProjectionTestSupport.seedSession(
                id: id, status: status, worktree: worktree, repository: repository,
                promptText: prompt, paths: paths, fixture: fixture, into: store
            )
        }

        let response = try await store.relatedSessions(.init(targetSessionID: "caller", limit: 10))
        let projection = try #require(response.projection)
        #expect(Set(projection.relatedSessions.map(\.sessionID)) == ["path-active", "path-history", "unrelated"])
        for id in ["path-active", "path-history"] {
            let brief = try #require(projection.relatedSessions.first { $0.sessionID == id })
            let artifact = try #require(brief.outcomeBrief?.changedArtifacts.first {
                $0.artifact.path == "Sources/Example.swift"
            })
            #expect(!artifact.sourceTurnOutcomeRevisionID.isEmpty)
            #expect(brief.worktreeBoundaries.contains { $0.branch == "feature/\(id == "path-active" ? "active" : "history")" })
        }
        let history = try #require(projection.relatedSessions.first { $0.sessionID == "path-history" })
        let objective = try #require(history.outcomeBrief?.objectives.first { $0.text == "Repair cache invalidation" })
        #expect(!objective.sourceTurnOutcomeRevisionID.isEmpty)
        #expect(!objective.evidence.isEmpty)
    }
}
