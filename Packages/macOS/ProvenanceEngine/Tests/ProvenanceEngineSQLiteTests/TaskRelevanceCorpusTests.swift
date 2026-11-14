import Foundation
import ProvenanceEngineContracts
@testable import ProvenanceEngineSQLite
import Testing

@Suite
struct TaskRelevanceCorpusTests {
    @Test
    func declaredCorpusMeetsRequiredRecallAndEvidenceCoverage() async throws {
        let url = RelatedSessionProjectionTestSupport.temporaryDatabaseURL()
        defer { RelatedSessionProjectionTestSupport.removeTemporaryDatabaseDirectory(for: url) }
        let store = try ProvenanceSQLiteRepository(url: url)
        let client: any ProvenanceEngineClient = store
        let fixture = RelatedSessionFixture()
        let repo = fixture.repository(id: "eval-repo", path: "/repos/eval", remoteSlug: "owner/eval")
        let other = fixture.repository(id: "other-repo", path: "/repos/other", remoteSlug: "owner/other")
        let entries: [(String, String, String, [String], Int)] = [
            ("caller", "active", "Start task", [], 1),
            ("path-active", "active", "Inspect shared subsystem", ["Sources/Example.swift"], 10),
            ("path-history", "completed", "Earlier shared work", ["Sources/Example.swift"], 20),
            ("ticket-exact", "completed", "Ticket work", [], 30),
            ("objective-attempt", "completed", "Repair cache invalidation", [], 40),
            ("blocker-old", "completed", "Investigate package blocker", [], 50),
            ("blocker-resolution", "completed", "Investigate package blocker", [], 60),
            ("unrelated", "completed", "Change sidebar", ["Sources/Sidebar.swift"], 70),
            ("other-repo", "completed", "Inspect shared subsystem", ["Sources/Example.swift"], 80),
            ("budget-1", "completed", "Budget one", ["Sources/Budget.swift"], 140),
            ("budget-2", "completed", "Budget two", ["Sources/Budget.swift"], 130),
            ("budget-3", "completed", "Budget three", ["Sources/Budget.swift"], 120),
            ("budget-4", "completed", "Budget four", ["Sources/Budget.swift"], 110),
        ]
        var seeded: [String: SeededRelatedSession] = [:]
        for (id, status, prompt, paths, offset) in entries {
            let repository = id == "other-repo" ? other : repo
            let worktree = fixture.worktree(id: "worktree-\(id)", repository: repository,
                path: "/worktrees/\(id)", branch: "branch/\(id)", head: "head-\(id)", offset: Double(offset))
            seeded[id] = try await RelatedSessionProjectionTestSupport.seedSession(
                id: id, status: status, worktree: worktree, repository: repository,
                sessionOffset: Double(offset), promptText: prompt, paths: paths, fixture: fixture, into: store
            )
        }
        let display = ProvenanceWorkspaceDisplayRecord(id: "display-ticket-exact", workspaceID: "workspace-ticket-exact",
            repositoryID: repo.id, ticketIDs: ["EVAL-42"], observedAt: fixture.time(200), updatedAt: fixture.time(200))
        try await fixture.append(eventID: "event-corpus-ticket", eventType: .workspaceDisplayObserved,
            timestamp: fixture.time(200), repositoryID: repo.id, worktreeID: nil, sessionID: nil,
            payload: .init(workspaceDisplay: display), into: store)
        let attempt = try #require(seeded["objective-attempt"])
        let failed = ProvenanceCodingAgentCommandRecord(id: "command-failed-attempt", sessionID: attempt.session.id,
            threadID: attempt.thread.id, turnID: attempt.turn.id, provider: "codex", operationID: "failed-attempt",
            command: "swift test --filter Cache", cwd: "/worktrees/objective-attempt", status: "failed", exitCode: 1,
            outputSummary: "database unavailable", startedAt: fixture.time(44), completedAt: fixture.time(45),
            source: .observed, confidence: .high)
        try await fixture.appendCommand(failed, into: store)
        for id in ["blocker-old", "blocker-resolution"] {
            let item = try #require(seeded[id])
            _ = try await RelatedSessionWorkStateSemanticTestSupport.appendAssistantMessage(
                "Blocker: activity=run package suite; condition=database offline", id: "\(id)-open",
                sessionID: item.session.id, threadID: item.thread.id, turnID: item.turn.id,
                offset: id == "blocker-old" ? 58 : 68, fixture: fixture, into: store)
            if id == "blocker-resolution" {
                _ = try await RelatedSessionWorkStateSemanticTestSupport.appendAssistantMessage(
                    "Blocker resolved: activity=run package suite; condition=database offline; outcome=bypassed",
                    id: "blocker-resolution-resolved", sessionID: item.session.id, threadID: item.thread.id,
                    turnID: item.turn.id, offset: 69, fixture: fixture, into: store)
            }
            _ = try await RelatedSessionWorkStateSemanticTestSupport.publishSemantics(
                sessionID: id, offset: 210, fixture: fixture, into: store)
        }
        let cases: [(ProvenanceRelatedSessionRequest, Set<String>, ProvenanceRelatedSessionRelationshipKind)] = [
            (.init(targetSessionID: "caller", limit: 5, artifactPath: "Sources/Example.swift"), ["path-active", "path-history"], .requestedArtifact),
            (.init(targetSessionID: "caller", limit: 5, ticket: "EVAL-42"), ["ticket-exact"], .currentWorkspaceTicket),
            (.init(targetSessionID: "caller", limit: 5, objective: "repair cache invalidation"), ["objective-attempt"], .objectiveTextMatch),
            (.init(targetSessionID: "caller", limit: 5, objective: "investigate package blocker"), ["blocker-old", "blocker-resolution"], .objectiveTextMatch),
        ]
        for (request, expected, kind) in cases {
            let projection = try #require(try await client.relatedSessions(request).projection)
            #expect(Set(projection.relatedSessions.map(\.sessionID)) == expected)
            for result in projection.relatedSessions {
                let reason = try #require(result.relationshipReasons.first { $0.kind == kind })
                #expect(reason.evidence.contains { $0.projectionRevisionID != nil || $0.eventSequence != nil })
            }
            if expected.contains("objective-attempt") {
                let attempted = try #require(projection.relatedSessions.first { $0.sessionID == "objective-attempt" })
                #expect(attempted.outcomeBrief?.validationsAttempted.contains {
                    $0.validation.command == "swift test --filter Cache" && $0.validation.resultStatus == "failed"
                } == true)
            }
            if kind == .objectiveTextMatch && expected.contains("blocker-resolution") {
                let resolved = try #require(projection.relatedSessions.first { $0.sessionID == "blocker-resolution" })
                let blockers = try RelatedSessionWorkStateSemanticTestSupport.blockerPayload(from: resolved)
                #expect(blockers.blockers.first?.state == .reportedBypassed)
                #expect(blockers.blockers.first?.sourceEvidenceRefs.contains { $0.id == "blocker-resolution-resolved" } == true)
                let references = try #require(blockers.blockers.first?.sourceEvidenceRefs)
                let original = try #require(references.firstIndex { $0.id == "blocker-resolution-open" })
                let resolution = try #require(references.firstIndex { $0.id == "blocker-resolution-resolved" })
                #expect(original < resolution)
            }
        }
        let budgetRequest = ProvenanceRelatedSessionRequest(targetSessionID: "caller", limit: 2, artifactPath: "Sources/Budget.swift")
        let budget = try #require(try await client.relatedSessions(budgetRequest).projection)
        let repeated = try #require(try await client.relatedSessions(budgetRequest).projection)
        #expect(budget.relatedSessions.map(\.sessionID) == ["budget-1", "budget-2"])
        #expect(budget.relatedSessions.allSatisfy { brief in
            brief.relationshipReasons.contains { reason in
                reason.kind == .requestedArtifact && reason.evidence.contains { $0.projectionRevisionID != nil }
            }
        })
        #expect(budget.excludedCandidates.map(\.sessionID) == ["budget-3", "budget-4"])
        #expect(budget.projection.revisionID == repeated.projection.revisionID)
        let cappedExclusions = try #require(try await client.relatedSessions(
            .init(targetSessionID: "caller", limit: 2, exclusionLimit: 1, artifactPath: "Sources/Budget.swift")
        ).projection)
        let encoded = try JSONEncoder().encode(cappedExclusions)
        let object = try #require(try JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        #expect(object["candidatesOmittedForLimit"] as? Int == 2)
        #expect(cappedExclusions.excludedCandidates.count == 1)
        let noMatch = try #require(try await client.relatedSessions(.init(targetSessionID: "caller", ticket: "EVAL-999")).projection)
        #expect(noMatch.relatedSessions.isEmpty)
        #expect(noMatch.completeness.fields.contains { $0.field == "task_selector_evidence" && $0.status == "partial" })
    }
}
