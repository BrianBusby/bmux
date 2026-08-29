import Foundation
import ProvenanceEngineContracts
@testable import ProvenanceEngineSQLite
import Testing

@Suite
struct TurnOutcomeProjectionTests {
    @Test
    func normalTurnProjectsEvidenceBackedOutcome() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)
        let fixture = TurnOutcomeFixture()

        try await Self.seed(fixture.normalEvents, into: repository)

        let response = try await repository.turnOutcome(ProvenanceTurnOutcomeRequest(turnID: fixture.turnCompleted.id))
        let outcome = try #require(response.outcome)
        let revisionID = outcome.projection.revisionID

        #expect(response.found)
        #expect(response.reason == nil)
        #expect(outcome.schemaVersion == 1)
        #expect(outcome.turnID == fixture.turnCompleted.id)
        #expect(outcome.sessionID == fixture.session.id)
        #expect(outcome.provider == "codex")
        #expect(outcome.providerTurnID == "provider-turn-main")
        #expect(outcome.projection.projectionRuleID == "deterministic_turn_outcome")
        #expect(outcome.projection.projectionRuleVersion == "1")
        #expect(outcome.projection.sourceEvidenceWatermark == fixture.normalEvents.count)
        #expect(outcome.objective?.text == fixture.prompt.text)
        #expect(outcome.objective?.evidence.isEmpty == false)
        #expect(outcome.planItems.map(\.status) == ["completed", "in_progress"])
        #expect(outcome.actionsCompleted.map(\.text).contains("Inspect current transcript projection"))
        #expect(outcome.actionsCompleted.map(\.text).contains(fixture.reasoningSummary.text))
        #expect(outcome.commandsCompleted.map(\.classification.kind) == ["test", "git_inspection"])
        #expect(outcome.validationsAttempted.map(\.validationKind) == ["test"])
        #expect(outcome.validationsAttempted.first?.resultStatus == "passed")
        #expect(outcome.artifactsChanged.map(\.path) == [fixture.fileChange.path])
        #expect(outcome.artifactsChanged.first?.status == "modified")
        #expect(outcome.decisions.isEmpty)
        #expect(outcome.blockers.isEmpty)
        #expect(outcome.unresolvedItems.map(\.text) == ["Document the turn outcome contract"])
        #expect(outcome.resumePoint?.text == "Document the turn outcome contract")
        #expect(outcome.lifecycleState == "completed")
        #expect(outcome.completionState == "completed")
        #expect(outcome.repositoryBoundary?.repositoryID == fixture.repository.id)
        #expect(outcome.repositoryBoundary?.worktreeID == fixture.worktree.id)
        #expect(outcome.repositoryBoundary?.branch == "feature/turn-outcome")
        #expect(outcome.repositoryBoundary?.head == "abc123")
        #expect(outcome.completeness.status == "partial")
        #expect(outcome.completeness.fields.first { $0.field == "decisions" }?.status == "not_observed")
        #expect(outcome.commandsCompleted.allSatisfy { !$0.evidence.isEmpty })
        #expect(outcome.validationsAttempted.allSatisfy { !$0.evidence.isEmpty })
        #expect(outcome.artifactsChanged.allSatisfy { !$0.evidence.isEmpty })
        #expect(try await repository.storageSummary().schemaVersion == 23)
        #expect(try await repository.storageSummary().codingAgentTurnOutcomeCount == 1)
        #expect(try await repository.storageSummary().codingAgentTurnOutcomeRevisionCount >= 4)

        let specific = try await repository.turnOutcome(
            ProvenanceTurnOutcomeRequest(turnID: fixture.turnCompleted.id, revisionID: revisionID)
        )
        #expect(specific.found)
        #expect(specific.outcome?.projection.revisionID == revisionID)
    }

    @Test
    func failedValidationAndExplicitBlockerAreProjectedWithoutInferringOverallValidity() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)
        let fixture = TurnOutcomeFixture(suffix: "blocked")
        let plan = fixture.plan(steps: [
            ProvenanceCodingAgentPlanStepRecord(
                id: "blocked-step",
                order: 0,
                text: "Waiting on migration decision",
                status: "blocked"
            ),
        ])
        let failedCommand = fixture.command(
            id: "command-blocked-test",
            command: "swift test --filter MigrationTests",
            status: "failed",
            exitCode: 1
        )
        try await Self.seed(
            fixture.baseEvents(turnStatus: "failed") + [
                fixture.event(
                    id: "event-blocked-plan",
                    eventType: .codingAgentPlanUpdated,
                    timestamp: fixture.time(4),
                    payload: ProvenanceEventPayload(codingAgentPlanUpdate: plan)
                ),
                fixture.event(
                    id: "event-blocked-command",
                    eventType: .codingAgentCommandCompleted,
                    timestamp: fixture.time(5),
                    payload: ProvenanceEventPayload(codingAgentCommand: failedCommand)
                ),
            ],
            into: repository
        )

        let outcome = try #require(
            try await repository.turnOutcome(ProvenanceTurnOutcomeRequest(turnID: fixture.turnCompleted.id)).outcome
        )
        #expect(outcome.completionState == "failed")
        #expect(outcome.validationsAttempted.map(\.resultStatus) == ["failed"])
        #expect(outcome.blockers.map(\.text) == ["Waiting on migration decision"])
        #expect(outcome.resumePoint == nil)
        #expect(outcome.completeness.fields.first { $0.field == "resume_point" }?.status == "not_observed")
    }

    @Test
    func interruptedAndMissingOptionalEvidenceRemainExplicitlyPartial() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)
        let fixture = TurnOutcomeFixture(suffix: "interrupted")
        try await Self.seed(fixture.baseEvents(turnStatus: "interrupted"), into: repository)

        let outcome = try #require(
            try await repository.turnOutcome(ProvenanceTurnOutcomeRequest(turnID: fixture.turnCompleted.id)).outcome
        )
        #expect(outcome.completionState == "interrupted")
        #expect(outcome.objective == nil)
        #expect(outcome.planItems.isEmpty)
        #expect(outcome.commandsCompleted.isEmpty)
        #expect(outcome.validationsAttempted.isEmpty)
        #expect(outcome.artifactsChanged.isEmpty)
        #expect(outcome.completeness.status == "partial")
        #expect(outcome.completeness.fields.first { $0.field == "objective" }?.reason == "no_submitted_prompt")
        #expect(outcome.completeness.fields.first { $0.field == "validations_attempted" }?.status == "not_observed")
    }

    @Test
    func duplicateAndOverlappingEvidenceDoNotCreateAdditionalFactualRevisions() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)
        let fixture = TurnOutcomeFixture(suffix: "duplicate")
        let command = fixture.command(id: "command-overlap", command: "swift test", status: "succeeded", exitCode: 0)
        try await Self.seed(fixture.baseEvents(turnStatus: "completed"), into: repository)
        try await Self.append(
            fixture.event(
                id: "event-overlap-transcript",
                eventType: .codingAgentCommandCompleted,
                timestamp: fixture.time(4),
                payload: ProvenanceEventPayload(codingAgentCommand: command),
                origin: .codexSession
            ),
            into: repository
        )
        let firstOutcome = try #require(
            try await repository.turnOutcome(ProvenanceTurnOutcomeRequest(turnID: fixture.turnCompleted.id)).outcome
        )
        let revisionID = firstOutcome.projection.revisionID
        let revisionCount = try await repository.storageSummary().codingAgentTurnOutcomeRevisionCount

        try await Self.append(
            fixture.event(
                id: "event-overlap-hook",
                eventType: .codingAgentCommandCompleted,
                timestamp: fixture.time(5),
                payload: ProvenanceEventPayload(codingAgentCommand: command),
                origin: "codex-hook"
            ),
            into: repository
        )

        let secondOutcome = try #require(
            try await repository.turnOutcome(ProvenanceTurnOutcomeRequest(turnID: fixture.turnCompleted.id)).outcome
        )
        #expect(secondOutcome.projection.revisionID == revisionID)
        #expect(try await repository.storageSummary().codingAgentTurnOutcomeRevisionCount == revisionCount)
        #expect(secondOutcome.commandsCompleted.count == 1)
        #expect(secondOutcome.commandsCompleted.first?.evidence.count == 2)
        #expect(secondOutcome.commandsCompleted.first?.evidence.allSatisfy { $0.sourceState == "duplicated" } == true)
    }

    @Test
    func lateOutOfOrderEvidenceAndCorrectedEvidenceCreatePredictableRevisions() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)
        let fixture = TurnOutcomeFixture(suffix: "late")
        let failedCommand = fixture.command(id: "command-corrected", command: "swift test", status: "failed", exitCode: 1)
        let passedCommand = fixture.command(id: "command-corrected", command: "swift test", status: "succeeded", exitCode: 0)
        try await Self.seed(fixture.baseEvents(turnStatus: "completed"), into: repository)
        try await Self.append(
            fixture.event(
                id: "event-late-command-failed",
                eventType: .codingAgentCommandCompleted,
                timestamp: fixture.time(5),
                payload: ProvenanceEventPayload(codingAgentCommand: failedCommand)
            ),
            into: repository
        )
        let failedOutcome = try #require(
            try await repository.turnOutcome(ProvenanceTurnOutcomeRequest(turnID: fixture.turnCompleted.id)).outcome
        )
        #expect(failedOutcome.objective == nil)
        #expect(failedOutcome.validationsAttempted.map(\.resultStatus) == ["failed"])

        try await Self.append(
            fixture.event(
                id: "event-late-prompt",
                eventType: .codingAgentPromptSubmitted,
                timestamp: fixture.time(1),
                payload: ProvenanceEventPayload(codingAgentPrompt: fixture.prompt)
            ),
            into: repository
        )
        let promptOutcome = try #require(
            try await repository.turnOutcome(ProvenanceTurnOutcomeRequest(turnID: fixture.turnCompleted.id)).outcome
        )
        #expect(promptOutcome.objective?.text == fixture.prompt.text)
        #expect(promptOutcome.projection.revisionID != failedOutcome.projection.revisionID)

        try await Self.append(
            fixture.event(
                id: "event-late-command-corrected",
                eventType: .codingAgentCommandCompleted,
                timestamp: fixture.time(6),
                payload: ProvenanceEventPayload(codingAgentCommand: passedCommand),
                source: .reconciled
            ),
            into: repository
        )
        let correctedOutcome = try #require(
            try await repository.turnOutcome(ProvenanceTurnOutcomeRequest(turnID: fixture.turnCompleted.id)).outcome
        )
        #expect(correctedOutcome.validationsAttempted.map(\.resultStatus) == ["passed"])
        #expect(correctedOutcome.projection.revisionID != promptOutcome.projection.revisionID)
        #expect(try await repository.storageSummary().codingAgentTurnOutcomeRevisionCount == 5)
    }

    @Test
    func rebuildProducesTheSameLatestOutcome() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)
        let fixture = TurnOutcomeFixture(suffix: "rebuild")
        try await Self.seed(fixture.normalEvents, into: repository)
        let before = try #require(
            try await repository.turnOutcome(ProvenanceTurnOutcomeRequest(turnID: fixture.turnCompleted.id)).outcome
        )

        #expect(try await repository.rebuildProjectionsFromEventLedger(batchSize: 2) == fixture.normalEvents.count)
        let after = try #require(
            try await repository.turnOutcome(ProvenanceTurnOutcomeRequest(turnID: fixture.turnCompleted.id)).outcome
        )

        #expect(after == before)
    }

    @Test
    func worktreeAndBranchFactsDoNotLeakAcrossTurns() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)
        let first = TurnOutcomeFixture(suffix: "one")
        let second = TurnOutcomeFixture(
            suffix: "two",
            branch: "feature/other-worktree",
            head: "def456",
            pathSuffix: "other"
        )
        try await Self.seed(first.normalEvents + second.normalEvents, into: repository)

        let firstOutcome = try #require(
            try await repository.turnOutcome(ProvenanceTurnOutcomeRequest(turnID: first.turnCompleted.id)).outcome
        )
        let secondOutcome = try #require(
            try await repository.turnOutcome(ProvenanceTurnOutcomeRequest(turnID: second.turnCompleted.id)).outcome
        )

        #expect(firstOutcome.repositoryBoundary?.worktreeID == first.worktree.id)
        #expect(firstOutcome.repositoryBoundary?.branch == "feature/turn-outcome")
        #expect(firstOutcome.repositoryBoundary?.head == "abc123")
        #expect(firstOutcome.artifactsChanged.map(\.path) == [first.fileChange.path])
        #expect(secondOutcome.repositoryBoundary?.worktreeID == second.worktree.id)
        #expect(secondOutcome.repositoryBoundary?.branch == "feature/other-worktree")
        #expect(secondOutcome.repositoryBoundary?.head == "def456")
        #expect(secondOutcome.artifactsChanged.map(\.path) == [second.fileChange.path])
    }

    @Test
    func unsupportedProseDoesNotInventDecisionBlockerOrResumePoint() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)
        let fixture = TurnOutcomeFixture(suffix: "unsupported")
        let summary = fixture.reasoningSummary(text: "We should maybe decide whether to refactor this later.")
        try await Self.seed(
            fixture.baseEvents(turnStatus: "completed") + [
                fixture.event(
                    id: "event-unsupported-summary",
                    eventType: .codingAgentReasoningSummaryCompleted,
                    timestamp: fixture.time(4),
                    payload: ProvenanceEventPayload(codingAgentReasoningSummary: summary)
                ),
            ],
            into: repository
        )

        let outcome = try #require(
            try await repository.turnOutcome(ProvenanceTurnOutcomeRequest(turnID: fixture.turnCompleted.id)).outcome
        )
        #expect(outcome.decisions.isEmpty)
        #expect(outcome.blockers.isEmpty)
        #expect(outcome.resumePoint == nil)
        #expect(outcome.actionsCompleted.isEmpty)
        #expect(outcome.completeness.fields.first { $0.field == "decisions" }?.reason == "no_explicit_decision_evidence")
    }

    @Test
    func unknownTurnAndMissingRevisionReturnStableReasons() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)
        let fixture = TurnOutcomeFixture(suffix: "missing-revision")
        try await Self.seed(fixture.baseEvents(turnStatus: "completed"), into: repository)

        #expect(try await repository.turnOutcome(
            ProvenanceTurnOutcomeRequest(turnID: "turn-missing")
        ) == ProvenanceTurnOutcomeResponse(
            found: false,
            reason: "no_turn",
            turnID: "turn-missing",
            outcome: nil
        ))
        let missingRevision = try await repository.turnOutcome(
            ProvenanceTurnOutcomeRequest(turnID: fixture.turnCompleted.id, revisionID: "revision-missing")
        )
        #expect(missingRevision.found == false)
        #expect(missingRevision.reason == "no_revision")
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
            .appendingPathComponent("provenance-engine-turn-outcome-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("provenance.sqlite")
    }

    private static func removeTemporaryDatabaseDirectory(for url: URL) {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }
}

struct TurnOutcomeFixture {
    let suffix: String
    let branch: String
    let head: String
    let pathSuffix: String
    let sessionID: String
    let usesSessionWorktree: Bool
    let sessionStatus: String
    let baseTime = Date(timeIntervalSince1970: 1_800_000_000)

    init(
        suffix: String = "main",
        branch: String = "feature/turn-outcome",
        head: String = "abc123",
        pathSuffix: String = "main",
        sessionID: String? = nil,
        usesSessionWorktree: Bool = true,
        sessionStatus: String = "completed"
    ) {
        self.suffix = suffix
        self.branch = branch
        self.head = head
        self.pathSuffix = pathSuffix
        self.sessionID = sessionID ?? "session-\(suffix)"
        self.usesSessionWorktree = usesSessionWorktree
        self.sessionStatus = sessionStatus
    }

    var repository: ProvenanceRepositoryRecord {
        ProvenanceRepositoryRecord(
            id: "repository-\(suffix)",
            path: "/tmp/provenance-engine-\(pathSuffix)",
            commonDirectory: "/tmp/provenance-engine-\(pathSuffix)/.git",
            remoteSlug: "manaflow-ai/provenance-engine",
            createdAt: time(0),
            updatedAt: time(0)
        )
    }

    var worktree: ProvenanceWorktreeRecord {
        ProvenanceWorktreeRecord(
            id: "worktree-\(suffix)",
            repositoryID: repository.id,
            path: repository.path,
            branch: branch,
            baseCommit: "base-\(suffix)",
            currentHEAD: head,
            isDirty: true,
            status: "active",
            lastReconciledAt: time(2),
            updatedAt: time(2)
        )
    }

    var session: ProvenanceSessionRecord {
        ProvenanceSessionRecord(
            id: sessionID,
            agentKind: "codex",
            workspaceID: "workspace-\(suffix)",
            surfaceID: "surface-\(suffix)",
            worktreeID: usesSessionWorktree ? worktree.id : nil,
            cwd: usesSessionWorktree ? worktree.path : nil,
            status: sessionStatus,
            startedAt: time(1),
            updatedAt: time(9)
        )
    }

    var thread: ProvenanceCodingAgentThreadRecord {
        ProvenanceCodingAgentThreadRecord(
            id: "thread-\(suffix)",
            sessionID: session.id,
            provider: "codex",
            providerThreadID: "provider-thread-\(suffix)",
            worktreeID: worktree.id,
            source: .observed,
            confidence: .high,
            firstObservedAt: time(1),
            updatedAt: time(1)
        )
    }

    var turnStarted: ProvenanceCodingAgentTurnRecord {
        ProvenanceCodingAgentTurnRecord(
            id: "turn-\(suffix)",
            sessionID: session.id,
            threadID: thread.id,
            provider: "codex",
            providerTurnID: "provider-turn-\(suffix)",
            status: "started",
            model: "gpt-5-codex",
            effort: "high",
            startedAt: time(2),
            updatedAt: time(2),
            source: .observed,
            confidence: .high
        )
    }

    var turnCompleted: ProvenanceCodingAgentTurnRecord {
        ProvenanceCodingAgentTurnRecord(
            id: "turn-\(suffix)",
            sessionID: session.id,
            threadID: thread.id,
            provider: "codex",
            providerTurnID: "provider-turn-\(suffix)",
            status: "completed",
            model: "gpt-5-codex",
            effort: "high",
            startedAt: time(2),
            completedAt: time(8),
            updatedAt: time(8),
            source: .observed,
            confidence: .high
        )
    }

    var prompt: ProvenanceCodingAgentPromptRecord {
        ProvenanceCodingAgentPromptRecord(
            id: "prompt-\(suffix)",
            sessionID: session.id,
            threadID: thread.id,
            turnID: turnCompleted.id,
            provider: "codex",
            text: "Add deterministic turn outcome projection.",
            submittedAt: time(3),
            source: .declared,
            confidence: .high
        )
    }

    var normalPlan: ProvenanceCodingAgentPlanUpdateRecord {
        plan(steps: [
            ProvenanceCodingAgentPlanStepRecord(
                id: "plan-step-a",
                order: 0,
                text: "Inspect current transcript projection",
                status: "completed"
            ),
            ProvenanceCodingAgentPlanStepRecord(
                id: "plan-step-b",
                order: 1,
                text: "Document the turn outcome contract",
                status: "in_progress"
            ),
        ])
    }

    var testCommand: ProvenanceCodingAgentCommandRecord {
        command(
            id: "command-test-\(suffix)",
            command: "swift test --filter TurnOutcomeProjectionTests",
            status: "succeeded",
            exitCode: 0
        )
    }

    var gitCommand: ProvenanceCodingAgentCommandRecord {
        command(
            id: "command-git-\(suffix)",
            command: "git status --short",
            status: "succeeded",
            exitCode: 0
        )
    }

    var fileChange: ProvenanceFileChangeRecord {
        ProvenanceFileChangeRecord(
            id: "file-change-\(suffix)",
            changeSetID: "change-set-\(suffix)",
            repositoryID: repository.id,
            worktreeID: worktree.id,
            path: "Sources/ProvenanceEngineSQLite/TurnOutcome-\(suffix).swift",
            status: "modified",
            attributionSource: .observed,
            attributionConfidence: .high,
            updatedAt: time(6)
        )
    }

    var fileAttribution: ProvenanceCodingAgentFileChangeAttributionRecord {
        ProvenanceCodingAgentFileChangeAttributionRecord(
            id: "file-attribution-\(suffix)",
            sessionID: session.id,
            threadID: thread.id,
            turnID: turnCompleted.id,
            provider: "codex",
            operationID: "operation-edit-\(suffix)",
            changeSetID: fileChange.changeSetID,
            fileChangeIDs: [fileChange.id],
            paths: [fileChange.path],
            summary: "Updated the turn outcome projection.",
            observedAt: time(6),
            source: .observed,
            confidence: .high
        )
    }

    var reasoningSummary: ProvenanceCodingAgentReasoningSummaryRecord {
        reasoningSummary(text: "Completed deterministic turn outcome projection tests.")
    }

    var normalEvents: [ProvenanceEvent] {
        baseEvents(turnStatus: "completed") + [
            event(
                id: "event-prompt-\(suffix)",
                eventType: .codingAgentPromptSubmitted,
                timestamp: time(3),
                payload: ProvenanceEventPayload(codingAgentPrompt: prompt)
            ),
            event(
                id: "event-plan-\(suffix)",
                eventType: .codingAgentPlanUpdated,
                timestamp: time(4),
                payload: ProvenanceEventPayload(codingAgentPlanUpdate: normalPlan)
            ),
            event(
                id: "event-command-test-\(suffix)",
                eventType: .codingAgentCommandCompleted,
                timestamp: time(5),
                payload: ProvenanceEventPayload(codingAgentCommand: testCommand)
            ),
            event(
                id: "event-command-git-\(suffix)",
                eventType: .codingAgentCommandCompleted,
                timestamp: time(5.5),
                payload: ProvenanceEventPayload(codingAgentCommand: gitCommand)
            ),
            event(
                id: "event-file-\(suffix)",
                eventType: "file_modified",
                timestamp: time(6),
                payload: ProvenanceEventPayload(fileChanges: [fileChange])
            ),
            event(
                id: "event-file-attribution-\(suffix)",
                eventType: .codingAgentFileChangeAttributed,
                timestamp: time(6.1),
                payload: ProvenanceEventPayload(codingAgentFileChangeAttribution: fileAttribution)
            ),
            event(
                id: "event-summary-\(suffix)",
                eventType: .codingAgentReasoningSummaryCompleted,
                timestamp: time(7),
                payload: ProvenanceEventPayload(codingAgentReasoningSummary: reasoningSummary)
            ),
        ]
    }

    func baseEvents(turnStatus: String) -> [ProvenanceEvent] {
        let terminalTurn = ProvenanceCodingAgentTurnRecord(
            id: turnCompleted.id,
            sessionID: session.id,
            threadID: thread.id,
            provider: "codex",
            providerTurnID: turnCompleted.providerTurnID,
            status: turnStatus,
            model: turnCompleted.model,
            effort: turnCompleted.effort,
            startedAt: turnCompleted.startedAt,
            completedAt: turnStatus == "started" ? nil : time(8),
            updatedAt: time(8),
            source: .observed,
            confidence: .high
        )
        return [
            event(
                id: "event-repository-\(suffix)",
                eventType: .repositoryObserved,
                timestamp: time(0),
                payload: ProvenanceEventPayload(repository: repository)
            ),
            event(
                id: "event-worktree-\(suffix)",
                eventType: .worktreeObserved,
                timestamp: time(1),
                payload: ProvenanceEventPayload(worktree: worktree)
            ),
            event(
                id: "event-session-\(suffix)",
                eventType: .sessionObserved,
                timestamp: time(1.5),
                payload: ProvenanceEventPayload(session: session)
            ),
            event(
                id: "event-thread-\(suffix)",
                eventType: .codingAgentThreadObserved,
                timestamp: time(2),
                payload: ProvenanceEventPayload(codingAgentThread: thread)
            ),
            event(
                id: "event-turn-started-\(suffix)",
                eventType: .codingAgentTurnObserved,
                timestamp: time(2.1),
                payload: ProvenanceEventPayload(codingAgentTurn: turnStarted)
            ),
            event(
                id: "event-turn-terminal-\(suffix)",
                eventType: .codingAgentTurnObserved,
                timestamp: time(8),
                payload: ProvenanceEventPayload(codingAgentTurn: terminalTurn)
            ),
        ]
    }

    func plan(steps: [ProvenanceCodingAgentPlanStepRecord]) -> ProvenanceCodingAgentPlanUpdateRecord {
        ProvenanceCodingAgentPlanUpdateRecord(
            id: "plan-\(suffix)",
            sessionID: session.id,
            threadID: thread.id,
            turnID: turnCompleted.id,
            provider: "codex",
            explanation: nil,
            steps: steps,
            observedAt: time(4),
            source: .observed,
            confidence: .high
        )
    }

    func command(
        id: String,
        command: String,
        status: String,
        exitCode: Int?
    ) -> ProvenanceCodingAgentCommandRecord {
        ProvenanceCodingAgentCommandRecord(
            id: id,
            sessionID: session.id,
            threadID: thread.id,
            turnID: turnCompleted.id,
            provider: "codex",
            operationID: "operation-\(id)",
            command: command,
            cwd: worktree.path,
            status: status,
            exitCode: exitCode,
            outputSummary: nil,
            startedAt: time(5),
            completedAt: time(5.5),
            source: .observed,
            confidence: .high
        )
    }

    func reasoningSummary(text: String) -> ProvenanceCodingAgentReasoningSummaryRecord {
        ProvenanceCodingAgentReasoningSummaryRecord(
            id: "summary-\(suffix)",
            sessionID: session.id,
            threadID: thread.id,
            turnID: turnCompleted.id,
            provider: "codex",
            itemID: "item-summary-\(suffix)",
            text: text,
            completedAt: time(7),
            source: .declared,
            confidence: .high
        )
    }

    func event(
        id: String,
        eventType: ProvenanceEventType,
        timestamp: Date,
        payload: ProvenanceEventPayload,
        origin: ProvenanceEvidenceOrigin = .codexSession,
        source: ProvenanceSource = .observed
    ) -> ProvenanceEvent {
        ProvenanceEvent(
            id: id,
            eventType: eventType,
            timestamp: timestamp,
            repositoryID: repository.id,
            worktreeID: worktree.id,
            sessionID: session.id,
            source: source,
            evidenceOrigin: origin,
            evidenceScope: ProvenanceEvidenceScope(level: .project, id: repository.id),
            confidence: .high,
            payload: payload
        )
    }

    func time(_ offset: TimeInterval) -> Date {
        baseTime.addingTimeInterval(offset)
    }
}
