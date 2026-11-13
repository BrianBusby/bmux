import Foundation
import ProvenanceEngineContracts
@testable import ProvenanceEngineSQLite
import Testing

@Suite
struct TaskRelevanceEvidenceTests {
    @Test
    func objectiveSelectionRetainsRecordedBlockerResolutionEvidence() async throws {
        typealias Support = RelatedSessionWorkStateSemanticTestSupport
        let url = RelatedSessionProjectionTestSupport.temporaryDatabaseURL()
        defer { RelatedSessionProjectionTestSupport.removeTemporaryDatabaseDirectory(for: url) }
        let store = try ProvenanceSQLiteRepository(url: url)
        let seeded = try await Support.seedWorkStateSessions(into: store)
        let projection = try #require(try await store.relatedSessions(
            .init(targetSessionID: seeded.target.session.id, objective: "Work on session")
        ).projection)
        let brief = try #require(projection.relatedSessions.first { $0.sessionID == seeded.bypassed.session.id })
        let blockers = try Support.blockerPayload(from: brief)
        let blocker = try #require(blockers.blockers.first)
        #expect(blocker.state == .reportedBypassed)
        #expect(blocker.sourceEvidenceRefs.contains { $0.id == seeded.bypassedResolutionEvidenceID })
        #expect(brief.relationshipReasons.contains { $0.kind == .objectiveTextMatch })
    }

    @Test
    func pathSelectionHasStableLimitAndReportsOmissions() async throws {
        let url = RelatedSessionProjectionTestSupport.temporaryDatabaseURL()
        defer { RelatedSessionProjectionTestSupport.removeTemporaryDatabaseDirectory(for: url) }
        let store = try ProvenanceSQLiteRepository(url: url)
        let fixture = RelatedSessionFixture()
        let repo = fixture.repository(id: "eval-repo", path: "/repos/eval", remoteSlug: "owner/eval")
        for (id, offset) in [("caller", 1), ("budget-1", 50), ("budget-2", 40), ("budget-3", 30), ("budget-4", 20)] {
            let worktree = fixture.worktree(id: "worktree-\(id)", repository: repo, path: "/worktrees/\(id)",
                branch: id, head: "head-\(id)", offset: Double(offset))
            _ = try await RelatedSessionProjectionTestSupport.seedSession(
                id: id, status: "completed", worktree: worktree, repository: repo, sessionOffset: Double(offset),
                paths: id == "caller" ? [] : ["Sources/Example.swift"], fixture: fixture, into: store
            )
        }
        let request = ProvenanceRelatedSessionRequest(targetSessionID: "caller", limit: 2,
            artifactPath: "Sources/Example.swift")
        let first = try #require(try await store.relatedSessions(request).projection)
        let second = try #require(try await store.relatedSessions(request).projection)
        #expect(first.relatedSessions.map(\.sessionID) == ["budget-1", "budget-2"])
        #expect(first.excludedCandidates.map(\.sessionID) == ["budget-3", "budget-4"])
        #expect(first.excludedCandidates.allSatisfy { $0.reason == "result_limit" && !$0.evidence.isEmpty })
        #expect(first.projection.revisionID == second.projection.revisionID)
        #expect(first.completeness.fields.contains { $0.field == "task_selector_evidence" && $0.status == "partial" })
    }

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
            ("ticket-exact", "completed", repo, "feature/ticket", "Fix ticket work", []),
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

        let display = ProvenanceWorkspaceDisplayRecord(
            id: "display-ticket-exact", workspaceID: "workspace-ticket-exact", repositoryID: repo.id,
            ticketIDs: ["EVAL-42"], observedAt: fixture.time(40), updatedAt: fixture.time(40)
        )
        try await fixture.append(eventID: "event-ticket-display", eventType: .workspaceDisplayObserved,
            timestamp: fixture.time(40), repositoryID: repo.id, worktreeID: nil, sessionID: nil,
            payload: ProvenanceEventPayload(workspaceDisplay: display), into: store)
        let otherDisplay = ProvenanceWorkspaceDisplayRecord(
            id: "display-other", workspaceID: "workspace-other-repo", repositoryID: otherRepo.id,
            ticketIDs: ["EVAL-42"], observedAt: fixture.time(40), updatedAt: fixture.time(40)
        )
        try await fixture.append(eventID: "event-other-ticket-display", eventType: .workspaceDisplayObserved,
            timestamp: fixture.time(40), repositoryID: otherRepo.id, worktreeID: nil, sessionID: nil,
            payload: ProvenanceEventPayload(workspaceDisplay: otherDisplay), into: store)

        let response = try await store.relatedSessions(.init(targetSessionID: "caller", limit: 10))
        let projection = try #require(response.projection)
        #expect(Set(projection.relatedSessions.map(\.sessionID)) == ["path-active", "path-history", "unrelated", "ticket-exact"])
        for id in ["path-active", "path-history"] {
            let brief = try #require(projection.relatedSessions.first { $0.sessionID == id })
            let artifact = try #require(brief.outcomeBrief?.changedArtifacts.first {
                $0.artifact.path == "Sources/Example.swift"
            })
            #expect(!artifact.sourceTurnOutcomeRevisionID.isEmpty)
            #expect(brief.worktreeBoundaries.contains { $0.branch == "feature/\(id == "path-active" ? "active" : "history")" })
        }
        let request = ProvenanceRelatedSessionRequest(
            targetSessionID: "caller", limit: 5, artifactPath: "Sources/Example.swift"
        )
        let selected = try #require(try await store.relatedSessions(request).projection)
        #expect(Set(selected.relatedSessions.map(\.sessionID)) == ["path-active", "path-history"])
        for brief in selected.relatedSessions {
            let reason = try #require(brief.relationshipReasons.first { $0.kind == .requestedArtifact })
            #expect(reason.relatedValue == "Sources/Example.swift")
            #expect(reason.evidence.contains { $0.projectionRevisionID != nil })
        }
        let repeated = try #require(try await store.relatedSessions(request).projection)
        #expect(repeated.projection.revisionID == selected.projection.revisionID)
        #expect(repeated.relatedSessions.map(\.sessionID) == selected.relatedSessions.map(\.sessionID))
        let missing = try #require(try await store.relatedSessions(
            .init(targetSessionID: "caller", artifactPath: "Sources/Missing.swift")
        ).projection)
        #expect(missing.relatedSessions.isEmpty)
        let objectiveSelected = try #require(try await store.relatedSessions(
            .init(targetSessionID: "caller", objective: "repair cache invalidation")
        ).projection)
        #expect(objectiveSelected.relatedSessions.map(\.sessionID) == ["path-history"])
        let objectiveReason = try #require(objectiveSelected.relatedSessions.first?.relationshipReasons.first {
            $0.kind == .objectiveTextMatch
        })
        #expect(objectiveReason.evidence.contains { $0.projectionRevisionID != nil })
        let combined = try #require(try await store.relatedSessions(
            .init(targetSessionID: "caller", artifactPath: "Sources/Example.swift", objective: "repair cache")
        ).projection)
        #expect(combined.relatedSessions.map(\.sessionID) == ["path-history"])
        let ticketSelected = try #require(try await store.relatedSessions(
            .init(targetSessionID: "caller", ticket: "EVAL-42")
        ).projection)
        #expect(ticketSelected.relatedSessions.map(\.sessionID) == ["ticket-exact"])
        let ticketReason = try #require(ticketSelected.relatedSessions.first?.relationshipReasons.first {
            $0.kind == .currentWorkspaceTicket
        })
        #expect(ticketReason.evidence.contains { $0.id == "event-ticket-display" && $0.eventSequence != nil })
        let missingTicket = try #require(try await store.relatedSessions(
            .init(targetSessionID: "caller", ticket: "EVAL-420")
        ).projection)
        #expect(missingTicket.relatedSessions.isEmpty)
        #expect(missingTicket.completeness.fields.contains {
            $0.field == "task_selector_evidence" && $0.reason == "task_evidence_coverage_unknown"
        })
        let history = try #require(projection.relatedSessions.first { $0.sessionID == "path-history" })
        let objective = try #require(history.outcomeBrief?.objectives.first { $0.text == "Repair cache invalidation" })
        #expect(!objective.sourceTurnOutcomeRevisionID.isEmpty)
        #expect(!objective.evidence.isEmpty)
    }
    @Test
    func selectorsRespectEvidenceRepositoryAndObservationTime() async throws {
        let url = RelatedSessionProjectionTestSupport.temporaryDatabaseURL()
        defer { RelatedSessionProjectionTestSupport.removeTemporaryDatabaseDirectory(for: url) }
        let store = try ProvenanceSQLiteRepository(url: url)
        let fixture = RelatedSessionFixture()
        let repoA = fixture.repository(id: "repo-a", path: "/repos/a", remoteSlug: "owner/a")
        let repoB = fixture.repository(id: "repo-b", path: "/repos/b", remoteSlug: "owner/b")
        let treeA = fixture.worktree(id: "tree-a", repository: repoA, path: "/trees/a", branch: "a", head: "a", offset: 1)
        let treeB = fixture.worktree(id: "tree-b", repository: repoB, path: "/trees/b", branch: "b", head: "b", offset: 2)
        _ = try await RelatedSessionProjectionTestSupport.seedSession(
            id: "caller", status: "active", worktree: treeA, repository: repoA, fixture: fixture, into: store)
        let candidate = try await RelatedSessionProjectionTestSupport.seedSession(
            id: "multi", status: "completed", worktree: treeB, repository: repoB,
            promptText: "Old objective", paths: ["Sources/Example.swift"], fixture: fixture, into: store)
        let extraThread = fixture.thread(id: "thread-multi-a", sessionID: candidate.session.id,
            worktreeID: treeA.id, providerThreadID: "provider-multi-a", offset: 20)
        try await fixture.appendThread(extraThread, into: store)
        let display = ProvenanceWorkspaceDisplayRecord(
            id: "display-multi", workspaceID: "workspace-multi", repositoryID: repoB.id,
            ticketIDs: ["B-42"], observedAt: fixture.time(30), updatedAt: fixture.time(30))
        try await fixture.append(eventID: "event-multi-display", eventType: .workspaceDisplayObserved,
            timestamp: fixture.time(30), repositoryID: repoB.id, worktreeID: treeB.id, sessionID: nil,
            payload: ProvenanceEventPayload(workspaceDisplay: display), into: store)
        let path = try #require(try await store.relatedSessions(
            .init(targetSessionID: "caller", artifactPath: "Sources/Example.swift")).projection)
        #expect(path.relatedSessions.isEmpty)
        let ticket = try #require(try await store.relatedSessions(
            .init(targetSessionID: "caller", ticket: "B-42")).projection)
        #expect(ticket.relatedSessions.isEmpty)

        let callerB = try await RelatedSessionProjectionTestSupport.seedSession(
            id: "caller-b", status: "active", worktree: treeB, repository: repoB, fixture: fixture, into: store)
        let selected = try #require(try await store.relatedSessions(
            .init(targetSessionID: callerB.session.id, artifactPath: "Sources/Example.swift")).projection)
        let pathReason = try #require(selected.relatedSessions.first { $0.sessionID == "multi" }?
            .relationshipReasons.first { $0.kind == .requestedArtifact })
        #expect(pathReason.observedAt == fixture.time(17))
        let objective = try #require(try await store.relatedSessions(
            .init(targetSessionID: callerB.session.id, objective: "Old objective")).projection)
        let objectiveReason = try #require(objective.relatedSessions.first { $0.sessionID == "multi" }?
            .relationshipReasons.first { $0.kind == .objectiveTextMatch })
        #expect(objectiveReason.observedAt == fixture.time(13))
    }

}
