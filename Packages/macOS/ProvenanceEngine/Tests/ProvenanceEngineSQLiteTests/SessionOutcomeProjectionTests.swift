import Foundation
import ProvenanceEngineContracts
@testable import ProvenanceEngineSQLite
import Testing

@Suite
struct SessionOutcomeProjectionTests {
    @Test
    func sessionOutcomeAggregatesOneTurnAndTracksExactRevision() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)
        let fixture = TurnOutcomeFixture(suffix: "session-one")

        try await Self.seed(fixture.normalEvents, into: repository)

        let response = try await repository.sessionOutcome(
            ProvenanceSessionOutcomeRequest(sessionID: fixture.session.id)
        )
        let outcome = try #require(response.outcome)
        let turnOutcome = try #require(
            try await repository.turnOutcome(
                ProvenanceTurnOutcomeRequest(turnID: fixture.turnCompleted.id)
            ).outcome
        )

        #expect(response.found)
        #expect(response.reason == nil)
        #expect(outcome.schemaVersion == 1)
        #expect(outcome.sessionID == fixture.session.id)
        #expect(outcome.session == fixture.session)
        #expect(outcome.projection.projectionRuleID == "deterministic_session_outcome")
        #expect(outcome.projection.projectionRuleVersion == "1")
        #expect(outcome.projection.sourceEvidenceWatermark == fixture.normalEvents.count)
        #expect(outcome.constituentTurns.map(\.turnID) == [fixture.turnCompleted.id])
        #expect(outcome.constituentTurns.first?.turnOutcomeRevisionID == turnOutcome.projection.revisionID)
        #expect(outcome.constituentTurns.first?.turnOutcomeContentFingerprint == turnOutcome.projection.contentFingerprint)
        #expect(outcome.turnOutcomes == [turnOutcome])
        #expect(outcome.objectives.map(\.text) == [fixture.prompt.text])
        #expect(outcome.commandsCompleted.map(\.command.classification.kind) == ["test", "git_inspection"])
        #expect(outcome.validationsAttempted.map(\.validation.resultStatus) == ["passed"])
        #expect(outcome.changedArtifacts.map(\.artifact.path) == [fixture.fileChange.path])
        #expect(outcome.decisions.isEmpty)
        #expect(outcome.blockers.isEmpty)
        #expect(outcome.unresolvedItems.map(\.text) == ["Document the turn outcome contract"])
        #expect(outcome.latestResumePoint?.text == "Document the turn outcome contract")
        #expect(outcome.repositoryBoundaries.map(\.worktreeID) == [fixture.worktree.id])
        #expect(outcome.lifecycleState == "completed")
        #expect(outcome.completionState == "completed")
        #expect(outcome.completeness.status == "partial")
        #expect(outcome.completeness.fields.first { $0.field == "decisions" }?.status == "not_observed")
        #expect(try await repository.storageSummary().codingAgentSessionOutcomeCount == 1)
        #expect(try await repository.storageSummary().codingAgentSessionOutcomeRevisionCount >= 1)

        let specific = try await repository.sessionOutcome(
            ProvenanceSessionOutcomeRequest(
                sessionID: fixture.session.id,
                revisionID: outcome.projection.revisionID
            )
        )
        #expect(specific.found)
        #expect(specific.outcome == outcome)
    }

    @Test
    func sessionOutcomeOrdersTurnsAndReconcilesPlanStateAcrossTurns() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)
        let sessionID = "session-plan-reconcile"
        let first = TurnOutcomeFixture(suffix: "plan-first", sessionID: sessionID)
        let second = TurnOutcomeFixture(suffix: "plan-second", sessionID: sessionID)
        let firstPlan = first.plan(steps: [
            ProvenanceCodingAgentPlanStepRecord(
                id: "shared",
                order: 0,
                text: "Wire session outcome projection",
                status: "in_progress"
            ),
        ])
        let secondPlan = second.plan(steps: [
            ProvenanceCodingAgentPlanStepRecord(
                id: "shared",
                order: 0,
                text: "Wire session outcome projection",
                status: "completed"
            ),
            ProvenanceCodingAgentPlanStepRecord(
                id: "next",
                order: 1,
                text: "Document remaining limitations",
                status: "pending"
            ),
        ])

        try await Self.seed(
            first.baseEvents(turnStatus: "completed") + [
                first.event(
                    id: "event-plan-reconcile-first",
                    eventType: .codingAgentPlanUpdated,
                    timestamp: first.time(4),
                    payload: ProvenanceEventPayload(codingAgentPlanUpdate: firstPlan)
                ),
            ] + second.baseEvents(turnStatus: "completed") + [
                second.event(
                    id: "event-plan-reconcile-second",
                    eventType: .codingAgentPlanUpdated,
                    timestamp: second.time(14),
                    payload: ProvenanceEventPayload(codingAgentPlanUpdate: secondPlan)
                ),
            ],
            into: repository
        )

        let outcome = try #require(
            try await repository.sessionOutcome(
                ProvenanceSessionOutcomeRequest(sessionID: sessionID)
            ).outcome
        )
        #expect(outcome.constituentTurns.map(\.turnID) == [
            first.turnCompleted.id,
            second.turnCompleted.id,
        ])
        #expect(outcome.constituentTurns.map(\.order) == [0, 1])
        #expect(outcome.planItems.map(\.text) == [
            "Wire session outcome projection",
            "Document remaining limitations",
        ])
        #expect(outcome.planItems.map(\.status) == ["completed", "pending"])
        let reconciled = try #require(outcome.planItems.first)
        #expect(reconciled.firstObservedTurnID == first.turnCompleted.id)
        #expect(reconciled.latestObservedTurnID == second.turnCompleted.id)
        #expect(reconciled.latestTurnOutcomeRevisionID == outcome.constituentTurns[1].turnOutcomeRevisionID)
        #expect(outcome.unresolvedItems.map(\.text).contains("Document remaining limitations"))
        #expect(outcome.latestResumePoint?.text == "Document remaining limitations")
    }

    @Test
    func sessionOutcomeRepresentsLifecycleStatesAndStableMissingReasons() async throws {
        let cases = [
            ("active", "incomplete"),
            ("completed", "completed"),
            ("interrupted", "interrupted"),
            ("started", "incomplete"),
        ]
        for (status, expectedCompletion) in cases {
            let url = Self.temporaryDatabaseURL()
            defer { Self.removeTemporaryDatabaseDirectory(for: url) }
            let repository = try ProvenanceSQLiteRepository(url: url)
            let fixture = TurnOutcomeFixture(
                suffix: "session-\(status)",
                sessionStatus: status
            )

            try await Self.seed(fixture.baseEvents(turnStatus: status), into: repository)
            let outcome = try #require(
                try await repository.sessionOutcome(
                    ProvenanceSessionOutcomeRequest(sessionID: fixture.session.id)
                ).outcome
            )
            #expect(outcome.lifecycleState == status)
            #expect(outcome.completionState == expectedCompletion)
        }

        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)
        let fixture = TurnOutcomeFixture(suffix: "session-missing-revision")
        try await Self.seed(fixture.baseEvents(turnStatus: "completed"), into: repository)

        #expect(try await repository.sessionOutcome(
            ProvenanceSessionOutcomeRequest(sessionID: "session-missing")
        ) == ProvenanceSessionOutcomeResponse(
            found: false,
            reason: "no_session",
            sessionID: "session-missing",
            outcome: nil
        ))
        let missingRevision = try await repository.sessionOutcome(
            ProvenanceSessionOutcomeRequest(
                sessionID: fixture.session.id,
                revisionID: "session-outcome-revision-missing"
            )
        )
        #expect(missingRevision.found == false)
        #expect(missingRevision.reason == "no_revision")
    }

    @Test
    func sessionOutcomeKeepsKnownSessionWithNoTurnsPartial() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)
        let fixture = TurnOutcomeFixture(suffix: "no-turns")

        try await Self.seed([
            fixture.event(
                id: "event-no-turn-session",
                eventType: .sessionObserved,
                timestamp: fixture.time(1),
                payload: ProvenanceEventPayload(session: fixture.session)
            ),
        ], into: repository)

        let outcome = try #require(
            try await repository.sessionOutcome(
                ProvenanceSessionOutcomeRequest(sessionID: fixture.session.id)
            ).outcome
        )
        #expect(outcome.constituentTurns.isEmpty)
        #expect(outcome.turnOutcomes.isEmpty)
        #expect(outcome.completeness.status == "partial")
        #expect(outcome.completeness.fields.first { $0.field == "constituent_turns" }?.reason == "no_turn_outcomes")
    }

    @Test
    func sessionOutcomeNoopsDuplicateEvidenceAndPreservesLatestRevision() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)
        let fixture = TurnOutcomeFixture(suffix: "session-duplicate")
        let commandText = ["swift", "test"].joined(separator: " ")
        let command = fixture.command(
            id: "session-command-overlap",
            command: commandText,
            status: "succeeded",
            exitCode: 0
        )

        try await Self.seed(fixture.baseEvents(turnStatus: "completed"), into: repository)
        try await Self.append(
            fixture.event(
                id: "event-session-overlap-transcript",
                eventType: .codingAgentCommandCompleted,
                timestamp: fixture.time(4),
                payload: ProvenanceEventPayload(codingAgentCommand: command),
                origin: .codexSession
            ),
            into: repository
        )
        let firstOutcome = try #require(
            try await repository.sessionOutcome(
                ProvenanceSessionOutcomeRequest(sessionID: fixture.session.id)
            ).outcome
        )
        let revisionID = firstOutcome.projection.revisionID
        let revisionCount = try await repository.storageSummary().codingAgentSessionOutcomeRevisionCount

        try await Self.append(
            fixture.event(
                id: "event-session-overlap-hook",
                eventType: .codingAgentCommandCompleted,
                timestamp: fixture.time(5),
                payload: ProvenanceEventPayload(codingAgentCommand: command),
                origin: "codex-hook"
            ),
            into: repository
        )
        let secondOutcome = try #require(
            try await repository.sessionOutcome(
                ProvenanceSessionOutcomeRequest(sessionID: fixture.session.id)
            ).outcome
        )

        #expect(secondOutcome.projection.revisionID == revisionID)
        #expect(try await repository.storageSummary().codingAgentSessionOutcomeRevisionCount == revisionCount)
        #expect(secondOutcome.commandsCompleted.count == 1)
        #expect(secondOutcome.commandsCompleted.first?.command.evidence.count == 2)
        #expect(secondOutcome.commandsCompleted.first?.command.evidence.allSatisfy { $0.sourceState == "duplicated" } == true)
    }

    @Test
    func sessionOutcomeCreatesNewRevisionForLateAndCorrectedFacts() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)
        let fixture = TurnOutcomeFixture(suffix: "session-late")
        let commandText = ["swift", "test"].joined(separator: " ")
        let failedCommand = fixture.command(id: "session-command-corrected", command: commandText, status: "failed", exitCode: 1)
        let passedCommand = fixture.command(id: "session-command-corrected", command: commandText, status: "succeeded", exitCode: 0)

        try await Self.seed(fixture.baseEvents(turnStatus: "completed"), into: repository)
        try await Self.append(
            fixture.event(
                id: "event-session-late-command-failed",
                eventType: .codingAgentCommandCompleted,
                timestamp: fixture.time(5),
                payload: ProvenanceEventPayload(codingAgentCommand: failedCommand)
            ),
            into: repository
        )
        let failedOutcome = try #require(
            try await repository.sessionOutcome(
                ProvenanceSessionOutcomeRequest(sessionID: fixture.session.id)
            ).outcome
        )
        #expect(failedOutcome.objectives.isEmpty)
        #expect(failedOutcome.validationsAttempted.map(\.validation.resultStatus) == ["failed"])

        try await Self.append(
            fixture.event(
                id: "event-session-late-prompt",
                eventType: .codingAgentPromptSubmitted,
                timestamp: fixture.time(1),
                payload: ProvenanceEventPayload(codingAgentPrompt: fixture.prompt)
            ),
            into: repository
        )
        let promptOutcome = try #require(
            try await repository.sessionOutcome(
                ProvenanceSessionOutcomeRequest(sessionID: fixture.session.id)
            ).outcome
        )
        #expect(promptOutcome.objectives.map(\.text) == [fixture.prompt.text])
        #expect(promptOutcome.projection.revisionID != failedOutcome.projection.revisionID)

        try await Self.append(
            fixture.event(
                id: "event-session-late-command-corrected",
                eventType: .codingAgentCommandCompleted,
                timestamp: fixture.time(6),
                payload: ProvenanceEventPayload(codingAgentCommand: passedCommand),
                source: .reconciled
            ),
            into: repository
        )
        let correctedOutcome = try #require(
            try await repository.sessionOutcome(
                ProvenanceSessionOutcomeRequest(sessionID: fixture.session.id)
            ).outcome
        )
        #expect(correctedOutcome.validationsAttempted.map(\.validation.resultStatus) == ["passed"])
        #expect(correctedOutcome.projection.revisionID != promptOutcome.projection.revisionID)

        let historical = try #require(
            try await repository.sessionOutcome(
                ProvenanceSessionOutcomeRequest(
                    sessionID: fixture.session.id,
                    revisionID: failedOutcome.projection.revisionID
                )
            ).outcome
        )
        #expect(historical.validationsAttempted.map(\.validation.resultStatus) == ["failed"])
        #expect(try await repository.storageSummary().codingAgentSessionOutcomeRevisionCount >= 3)
    }

    @Test
    func sessionOutcomeRebuildProducesTheSameLatestOutcome() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)
        let fixture = TurnOutcomeFixture(suffix: "session-rebuild")
        try await Self.seed(fixture.normalEvents, into: repository)
        let before = try #require(
            try await repository.sessionOutcome(
                ProvenanceSessionOutcomeRequest(sessionID: fixture.session.id)
            ).outcome
        )

        #expect(try await repository.rebuildProjectionsFromEventLedger(batchSize: 2) == fixture.normalEvents.count)
        let after = try #require(
            try await repository.sessionOutcome(
                ProvenanceSessionOutcomeRequest(sessionID: fixture.session.id)
            ).outcome
        )

        #expect(after == before)
    }

    @Test
    func sessionOutcomePreservesMultipleRepositoryBoundaries() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)
        let sessionID = "session-boundaries"
        let first = TurnOutcomeFixture(
            suffix: "boundary-one",
            branch: "feature/one",
            head: "abc111",
            pathSuffix: "boundary-one",
            sessionID: sessionID,
            usesSessionWorktree: false
        )
        let second = TurnOutcomeFixture(
            suffix: "boundary-two",
            branch: "feature/two",
            head: "def222",
            pathSuffix: "boundary-two",
            sessionID: sessionID,
            usesSessionWorktree: false
        )

        try await Self.seed(
            first.baseEvents(turnStatus: "completed")
                + second.baseEvents(turnStatus: "completed"),
            into: repository
        )
        let outcome = try #require(
            try await repository.sessionOutcome(
                ProvenanceSessionOutcomeRequest(sessionID: sessionID)
            ).outcome
        )
        #expect(outcome.repositoryBoundaries.map(\.worktreeID) == [
            first.worktree.id,
            second.worktree.id,
        ])
        #expect(outcome.repositoryBoundaries.map(\.branch) == ["feature/one", "feature/two"])
        #expect(outcome.repositoryBoundaries.map(\.head) == ["abc111", "def222"])
        #expect(outcome.completeness.fields.first { $0.field == "repository_boundaries" }?.status == "partial")
        #expect(outcome.completeness.fields.first { $0.field == "repository_boundaries" }?.reason == "multiple_repository_boundaries")
    }

    @Test
    func sessionOutcomeDoesNotPromoteUnsupportedProse() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)
        let fixture = TurnOutcomeFixture(suffix: "session-unsupported")
        let summary = fixture.reasoningSummary(text: "We should maybe decide whether to refactor this later.")

        try await Self.seed(
            fixture.baseEvents(turnStatus: "completed") + [
                fixture.event(
                    id: "event-session-unsupported-summary",
                    eventType: .codingAgentReasoningSummaryCompleted,
                    timestamp: fixture.time(4),
                    payload: ProvenanceEventPayload(codingAgentReasoningSummary: summary)
                ),
            ],
            into: repository
        )
        let outcome = try #require(
            try await repository.sessionOutcome(
                ProvenanceSessionOutcomeRequest(sessionID: fixture.session.id)
            ).outcome
        )
        #expect(outcome.decisions.isEmpty)
        #expect(outcome.blockers.isEmpty)
        #expect(outcome.resumePoints.isEmpty)
        #expect(outcome.actionsCompleted.isEmpty)
    }

    private static func seed(_ events: [ProvenanceEvent], into repository: ProvenanceSQLiteRepository) async throws {
        for event in events {
            try await append(event, into: repository)
        }
    }

    private static func append(_ event: ProvenanceEvent, into repository: ProvenanceSQLiteRepository) async throws {
        try await repository.appendEvent(event)
    }

    private static func temporaryDatabaseURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("provenance-engine-session-outcome-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("provenance.sqlite")
    }

    private static func removeTemporaryDatabaseDirectory(for url: URL) {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }
}
