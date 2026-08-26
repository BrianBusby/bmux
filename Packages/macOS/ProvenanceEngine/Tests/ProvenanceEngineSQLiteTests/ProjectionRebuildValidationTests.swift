import Foundation
import ProvenanceEngineContracts
@testable import ProvenanceEngineSQLite
import Testing

@Suite
struct ProjectionRebuildValidationTests {
    @Test
    func repairRebuildsDeletedProjectionsToIdenticalQueryResults() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)
        let fixture = ProjectionRebuildFixture()

        try await Self.seed(fixture, into: repository)

        let beforeWorktrees = try await repository.worktrees(ProvenanceWorktreeListRequest(repositoryID: nil))
        let beforeCurrentContext = try await repository.currentContext(
            ProvenanceCurrentContextRequest(repositoryPath: fixture.repository.path)
        )
        let beforeFileExplanation = try await repository.fileExplanation(
            ProvenanceFileExplanationRequest(worktreeID: fixture.worktree.id, path: fixture.fileChange.path)
        )
        let beforeSessionTree = try await repository.sessionTree(
            ProvenanceSessionTreeRequest(rootSessionID: fixture.session.id)
        )

        try Self.deleteProjectionRows(databaseURL: url)
        #expect(try await repository.currentContext(
            ProvenanceCurrentContextRequest(repositoryPath: fixture.repository.path)
        ).found == false)

        let repair = try await repository.repairProjectionDrift(
            validationLimit: 20,
            mismatchLimit: 20,
            rebuildBatchSize: 2
        )

        #expect(repair.repaired)
        #expect(repair.replayedEventCount == 6)
        #expect(repair.postRepairValidation?.mismatches.isEmpty == true)
        #expect(try await repository.worktrees(ProvenanceWorktreeListRequest(repositoryID: nil)) == beforeWorktrees)
        #expect(try await repository.currentContext(
            ProvenanceCurrentContextRequest(repositoryPath: fixture.repository.path)
        ) == beforeCurrentContext)
        #expect(try await repository.fileExplanation(
            ProvenanceFileExplanationRequest(worktreeID: fixture.worktree.id, path: fixture.fileChange.path)
        ) == beforeFileExplanation)
        #expect(try await repository.sessionTree(
            ProvenanceSessionTreeRequest(rootSessionID: fixture.session.id)
        ) == beforeSessionTree)
    }

    @Test
    func rebuildPreservesStructuredCodingAgentEvidence() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)
        let fixture = CodingAgentEvidenceFixture()

        try await Self.seedCodingAgentEvidence(fixture, into: repository)

        let beforeThread = try #require(try await repository.codingAgentThread(id: fixture.thread.id))
        let beforeTurn = try #require(try await repository.codingAgentTurn(id: fixture.firstTurnStarted.id))
        let beforePrompt = try #require(try await repository.codingAgentPrompt(id: fixture.prompt.id))
        let beforePlan = try #require(try await repository.codingAgentPlanUpdate(id: fixture.firstPlanUpdate.id))
        let beforeCommand = try #require(try await repository.codingAgentCommand(id: fixture.command.id))
        let beforeSummary = try #require(
            try await repository.codingAgentReasoningSummary(id: fixture.reasoningSummary.id)
        )
        let beforeAssistantMessage = try #require(
            try await repository.codingAgentAssistantMessage(id: fixture.assistantMessage.id)
        )
        let beforeAttribution = try #require(
            try await repository.codingAgentFileChangeAttribution(id: fixture.fileChangeAttribution.id)
        )
        let beforeFactualProjection = try await repository.factualSessionProjection(
            ProvenanceFactualSessionProjectionRequest(sessionID: fixture.session.id)
        )
        let beforeSnapshot = try #require(beforeFactualProjection.snapshot)

        #expect(beforeThread.sessionID == fixture.session.id)
        #expect(beforeThread.providerThreadID == "codex-thread-42")
        #expect(beforeTurn.sessionID == fixture.session.id)
        #expect(beforeTurn.threadID == fixture.thread.id)
        #expect(beforeTurn.providerTurnID == "codex-turn-1")
        #expect(beforeTurn.status == "completed")
        #expect(beforeTurn.startedAt == fixture.firstTurnStarted.startedAt)
        #expect(beforeTurn.completedAt == fixture.firstTurnCompleted.completedAt)
        #expect(try await repository.codingAgentTurn(id: fixture.secondTurn.id)?.providerTurnID == "codex-turn-2")
        #expect(beforePrompt.turnID == fixture.firstTurnStarted.id)
        #expect(beforePrompt.text == "Establish the structured Codex evidence path.")
        #expect(beforePlan.steps.map(\.text) == [
            "Audit current telemetry path",
            "Add durable PE evidence",
        ])
        #expect(beforePlan.steps.map(\.status) == ["completed", "in_progress"])
        #expect(beforeCommand.cwd == fixture.repository.path)
        #expect(beforeCommand.status == "succeeded")
        #expect(beforeCommand.exitCode == 0)
        #expect(beforeCommand.outputSummary == nil)
        #expect(beforeSummary.text == "Identified the provider-neutral telemetry adapter and PE append boundary.")
        #expect(beforeAssistantMessage.text.contains("Final output"))
        #expect(beforeAttribution.turnID == fixture.firstTurnStarted.id)
        #expect(beforeAttribution.changeSetID == fixture.changeSet.id)
        #expect(beforeAttribution.fileChangeIDs == [fixture.fileChange.id])
        #expect(beforeAttribution.paths == [fixture.fileChange.path])
        #expect(beforeFactualProjection.found)
        #expect(beforeFactualProjection.schemaVersion == 2)
        #expect(beforeSnapshot.revision == fixture.events.count)
        #expect(beforeSnapshot.session == fixture.session)
        #expect(beforeSnapshot.providerThreadIdentities == [
            ProvenanceFactualSessionProjectionProviderThreadIdentity(thread: fixture.thread),
            ProvenanceFactualSessionProjectionProviderThreadIdentity(thread: fixture.secondThread),
        ])
        #expect(beforeSnapshot.providerThreads == [fixture.thread, fixture.secondThread])
        #expect(beforeSnapshot.latestTurn?.turn == fixture.thirdTurn)
        #expect(beforeSnapshot.priorTurns == [
            ProvenanceFactualSessionProjectionTurnReference(turn: beforeTurn),
            ProvenanceFactualSessionProjectionTurnReference(turn: fixture.secondTurn),
        ])
        #expect(beforeSnapshot.turns.map(\.turn) == [beforeTurn, fixture.secondTurn, fixture.thirdTurn])
        #expect(beforeSnapshot.turns.first?.submittedPrompt == fixture.prompt)
        #expect(beforeSnapshot.turns.first?.currentPlan == fixture.finalPlanUpdate)
        #expect(beforeSnapshot.turns.first?.completedCommands == [fixture.command])
        #expect(beforeSnapshot.turns.first?.visibleReasoningSummaries == [fixture.reasoningSummary])
        #expect(beforeSnapshot.turns.first?.assistantMessages == [fixture.assistantMessage])
        #expect(beforeSnapshot.turns.first?.fileChangeAttributions == [fixture.fileChangeAttribution])
        #expect(beforeSnapshot.latestTurn?.submittedPrompt == nil)
        #expect(beforeSnapshot.latestTurn?.currentPlan == nil)
        #expect(beforeSnapshot.latestTurn?.completedCommands.isEmpty == true)
        #expect(beforeSnapshot.latestTurn?.visibleReasoningSummaries.isEmpty == true)
        #expect(beforeSnapshot.latestTurn?.assistantMessages.isEmpty == true)
        #expect(beforeSnapshot.latestTurn?.fileChangeAttributions.isEmpty == true)
        #expect(try await repository.factualSessionProjection(
            ProvenanceFactualSessionProjectionRequest(sessionID: fixture.session.id, turnLimit: 1)
        ).snapshot?.turns.map(\.turn.id) == [beforeTurn.id])
        #expect(try await repository.factualSessionProjection(
            ProvenanceFactualSessionProjectionRequest(sessionID: fixture.session.id, turnLimit: 1)
        ).snapshot?.latestTurn?.turn.id == fixture.thirdTurn.id)

        let turnDetail = try await repository.factualSessionTurnDetail(
            ProvenanceFactualSessionTurnDetailRequest(turnID: fixture.firstTurnStarted.id)
        )
        #expect(turnDetail.found)
        #expect(turnDetail.reason == nil)
        #expect(turnDetail.turnID == fixture.firstTurnStarted.id)
        #expect(turnDetail.sessionID == fixture.session.id)
        #expect(turnDetail.revision == fixture.events.count)
        #expect(turnDetail.turnDetail == beforeSnapshot.turns.first)

        #expect(try await repository.factualSessionTurnDetail(
            ProvenanceFactualSessionTurnDetailRequest(turnID: "turn-missing")
        ) == ProvenanceFactualSessionTurnDetailResponse(
            found: false,
            reason: "no_turn",
            turnID: "turn-missing",
            turnDetail: nil
        ))

        let fileExplanation = try await repository.fileExplanation(
            ProvenanceFileExplanationRequest(worktreeID: fixture.worktree.id, path: fixture.fileChange.path)
        )
        #expect(fileExplanation.found)
        #expect(fileExplanation.explanation?.fileChange == fixture.fileChange)
        #expect(fileExplanation.explanation?.changeSet == fixture.changeSet)

        var duplicateFailed = false
        do {
            try await Self.append(event: fixture.threadEvent, into: repository)
        } catch {
            duplicateFailed = true
        }
        #expect(duplicateFailed)
        #expect(try await repository.storageSummary().codingAgentThreadCount == 2)

        try await Self.append(event: fixture.replayedThreadEvent, into: repository)
        #expect(try await repository.storageSummary().codingAgentThreadCount == 2)
        let afterReplayFactualProjection = try await repository.factualSessionProjection(
            ProvenanceFactualSessionProjectionRequest(sessionID: fixture.session.id)
        )
        #expect(afterReplayFactualProjection.snapshot?.revision == fixture.events.count + 1)

        try Self.deleteCodingAgentProjectionRows(databaseURL: url)
        #expect(try await repository.codingAgentThread(id: fixture.thread.id) == nil)

        #expect(try await repository.rebuildProjectionsFromEventLedger(batchSize: 2) == fixture.events.count + 1)
        #expect(try await repository.codingAgentThread(id: fixture.thread.id) == beforeThread)
        #expect(try await repository.codingAgentTurn(id: fixture.firstTurnStarted.id) == beforeTurn)
        #expect(try await repository.codingAgentPrompt(id: fixture.prompt.id) == beforePrompt)
        #expect(try await repository.codingAgentPlanUpdate(id: fixture.firstPlanUpdate.id) == beforePlan)
        #expect(try await repository.codingAgentCommand(id: fixture.command.id) == beforeCommand)
        #expect(try await repository.codingAgentReasoningSummary(id: fixture.reasoningSummary.id) == beforeSummary)
        #expect(try await repository.codingAgentAssistantMessage(id: fixture.assistantMessage.id) == beforeAssistantMessage)
        #expect(
            try await repository.codingAgentFileChangeAttribution(id: fixture.fileChangeAttribution.id)
                == beforeAttribution
        )
        #expect(
            try await repository.factualSessionProjection(ProvenanceFactualSessionProjectionRequest(sessionID: fixture.session.id))
                == afterReplayFactualProjection
        )
        #expect(try await repository.validateProjectionKeys(limit: 20).mismatches.isEmpty)
    }

    private static func seed(
        _ fixture: ProjectionRebuildFixture,
        into repository: ProvenanceSQLiteRepository
    ) async throws {
        try await append(
            eventID: "event-rebuild-worktree",
            eventType: .worktreeObserved,
            timestamp: fixture.timestamp,
            repositoryID: fixture.repository.id,
            worktreeID: fixture.worktree.id,
            payload: ProvenanceEventPayload(repository: fixture.repository, worktree: fixture.worktree),
            into: repository
        )
        try await append(
            eventID: "event-rebuild-session",
            eventType: .sessionObserved,
            timestamp: fixture.session.updatedAt,
            repositoryID: fixture.repository.id,
            worktreeID: fixture.worktree.id,
            sessionID: fixture.session.id,
            payload: ProvenanceEventPayload(session: fixture.session),
            into: repository
        )
        try await append(
            eventID: "event-rebuild-task",
            eventType: .workItemConfirmed,
            timestamp: fixture.contribution.updatedAt,
            repositoryID: fixture.repository.id,
            worktreeID: fixture.worktree.id,
            sessionID: fixture.session.id,
            contributionID: fixture.contribution.id,
            payload: ProvenanceEventPayload(workItem: fixture.workItem, contribution: fixture.contribution),
            into: repository
        )
        try await append(
            eventID: "event-rebuild-checkpoint",
            eventType: .progressCheckpoint,
            timestamp: fixture.checkpoint.createdAt,
            repositoryID: fixture.repository.id,
            worktreeID: fixture.worktree.id,
            sessionID: fixture.session.id,
            contributionID: fixture.contribution.id,
            payload: ProvenanceEventPayload(checkpoint: fixture.checkpoint),
            into: repository
        )
        try await append(
            eventID: "event-rebuild-file",
            eventType: "file_modified",
            timestamp: fixture.fileChange.updatedAt,
            repositoryID: fixture.repository.id,
            worktreeID: fixture.worktree.id,
            sessionID: fixture.session.id,
            contributionID: fixture.contribution.id,
            payload: ProvenanceEventPayload(changeSet: fixture.changeSet, fileChanges: [fixture.fileChange]),
            into: repository
        )
        try await append(
            eventID: "event-rebuild-validation",
            eventType: "validation_completed",
            timestamp: fixture.validationRun.endedAt ?? fixture.timestamp,
            repositoryID: fixture.repository.id,
            worktreeID: fixture.worktree.id,
            sessionID: fixture.session.id,
            contributionID: fixture.contribution.id,
            payload: ProvenanceEventPayload(validationRun: fixture.validationRun),
            into: repository
        )
    }

    private static func seedCodingAgentEvidence(
        _ fixture: CodingAgentEvidenceFixture,
        into repository: ProvenanceSQLiteRepository
    ) async throws {
        for event in fixture.events {
            try await append(event: event, into: repository)
        }
    }

    private static func append(
        event: ProvenanceEvent,
        into repository: ProvenanceSQLiteRepository
    ) async throws {
        try await repository.appendEvent(event)
    }

    private static func append(
        eventID: String,
        eventType: ProvenanceEventType,
        timestamp: Date,
        repositoryID: String,
        worktreeID: String,
        sessionID: String? = nil,
        contributionID: String? = nil,
        payload: ProvenanceEventPayload,
        into repository: ProvenanceSQLiteRepository
    ) async throws {
        try await repository.appendEvent(
            ProvenanceEvent(
                id: eventID,
                eventType: eventType,
                timestamp: timestamp,
                repositoryID: repositoryID,
                worktreeID: worktreeID,
                sessionID: sessionID,
                contributionID: contributionID,
                source: .observed,
                evidenceOrigin: "projection-rebuild-validation",
                evidenceScope: ProvenanceEvidenceScope(level: .personal, id: "local-test"),
                confidence: .high,
                payload: payload
            )
        )
    }

    private static func deleteProjectionRows(databaseURL: URL) throws {
        let database = try ProvenanceSQLiteDatabase(url: databaseURL)
        try database.execute(
            """
            DELETE FROM provenance_repositories;
            DELETE FROM provenance_worktrees;
            DELETE FROM provenance_sessions;
            DELETE FROM provenance_session_relationships;
            DELETE FROM provenance_session_external_identities;
            DELETE FROM provenance_work_items;
            DELETE FROM provenance_work_contributions;
            DELETE FROM provenance_checkpoints;
            DELETE FROM provenance_change_sets;
            DELETE FROM provenance_file_changes;
            DELETE FROM provenance_validation_runs;
            """
        )
    }

    private static func deleteCodingAgentProjectionRows(databaseURL: URL) throws {
        let database = try ProvenanceSQLiteDatabase(url: databaseURL)
        try database.execute(
            """
            DELETE FROM provenance_coding_agent_file_change_attributions;
            DELETE FROM provenance_coding_agent_assistant_messages;
            DELETE FROM provenance_coding_agent_reasoning_summaries;
            DELETE FROM provenance_coding_agent_commands;
            DELETE FROM provenance_coding_agent_plan_updates;
            DELETE FROM provenance_coding_agent_prompts;
            DELETE FROM provenance_coding_agent_turns;
            DELETE FROM provenance_coding_agent_threads;
            DELETE FROM provenance_file_changes;
            DELETE FROM provenance_change_sets;
            DELETE FROM provenance_sessions;
            DELETE FROM provenance_worktrees;
            DELETE FROM provenance_repositories;
            DELETE FROM provenance_session_external_identities;
            """
        )
    }

    private static func temporaryDatabaseURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("provenance-engine-projection-rebuild-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("provenance.sqlite")
    }

    private static func removeTemporaryDatabaseDirectory(for url: URL) {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }
}

private struct ProjectionRebuildFixture {
    let timestamp = Date(timeIntervalSince1970: 1_800_000_000)
    let repository: ProvenanceRepositoryRecord
    let worktree: ProvenanceWorktreeRecord
    let session: ProvenanceSessionRecord
    let workItem: ProvenanceWorkItemRecord
    let contribution: ProvenanceContributionRecord
    let checkpoint: ProvenanceCheckpointRecord
    let changeSet: ProvenanceChangeSetRecord
    let fileChange: ProvenanceFileChangeRecord
    let validationRun: ProvenanceValidationRunRecord

    init() {
        let timestamp = Date(timeIntervalSince1970: 1_800_000_000)
        let repository = ProvenanceRepositoryRecord(
            id: "repository-rebuild",
            path: "/repos/projection-rebuild",
            remoteSlug: "owner/projection-rebuild",
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let worktree = ProvenanceWorktreeRecord(
            id: "worktree-rebuild",
            repositoryID: repository.id,
            path: repository.path,
            branch: "main",
            currentHEAD: "head-rebuild",
            isDirty: true,
            status: "active",
            lastReconciledAt: timestamp,
            updatedAt: timestamp
        )
        let session = ProvenanceSessionRecord(
            id: "session-rebuild",
            agentKind: "generic-agent",
            worktreeID: worktree.id,
            cwd: repository.path,
            status: "active",
            startedAt: timestamp.addingTimeInterval(1),
            updatedAt: timestamp.addingTimeInterval(1)
        )
        let workItem = ProvenanceWorkItemRecord(
            id: "work-item-rebuild",
            title: "Rebuild projection validation",
            status: "active",
            createdAt: timestamp.addingTimeInterval(2),
            updatedAt: timestamp.addingTimeInterval(2)
        )
        let contribution = ProvenanceContributionRecord(
            id: "contribution-rebuild",
            sessionID: session.id,
            worktreeID: worktree.id,
            workItemID: workItem.id,
            declaredIntent: "Prove disposable projections",
            expectedScope: ["Sources/Rebuild.swift"],
            status: "active",
            startedAt: timestamp.addingTimeInterval(2),
            assignmentConfidence: .high,
            updatedAt: timestamp.addingTimeInterval(2)
        )
        let checkpoint = ProvenanceCheckpointRecord(
            id: "checkpoint-rebuild",
            contributionID: contribution.id,
            sequence: 1,
            gitHEAD: "head-rebuild",
            diffFingerprint: "diff-rebuild",
            summary: "Projection rebuild checkpoint",
            status: "completed",
            validationState: "passed",
            semanticConfidence: .medium,
            freshness: "fresh",
            createdAt: timestamp.addingTimeInterval(3)
        )
        let changeSet = ProvenanceChangeSetRecord(
            id: "change-set-rebuild",
            checkpointID: checkpoint.id,
            contributionID: contribution.id,
            worktreeID: worktree.id,
            summary: "Projection rebuild file change",
            diffFingerprint: "diff-rebuild",
            createdAt: timestamp.addingTimeInterval(4)
        )
        let fileChange = ProvenanceFileChangeRecord(
            id: "file-change-rebuild",
            changeSetID: changeSet.id,
            repositoryID: repository.id,
            worktreeID: worktree.id,
            path: "Sources/Rebuild.swift",
            status: "modified",
            attributionSource: .observed,
            attributionConfidence: .high,
            updatedAt: timestamp.addingTimeInterval(4)
        )
        let validationRun = ProvenanceValidationRunRecord(
            id: "validation-rebuild",
            checkpointID: checkpoint.id,
            contributionID: contribution.id,
            command: "swift test --filter ProjectionRebuildValidationTests",
            status: "passed",
            summary: "Projection rebuild validation passed",
            startedAt: timestamp.addingTimeInterval(5),
            endedAt: timestamp.addingTimeInterval(6)
        )

        self.repository = repository
        self.worktree = worktree
        self.session = session
        self.workItem = workItem
        self.contribution = contribution
        self.checkpoint = checkpoint
        self.changeSet = changeSet
        self.fileChange = fileChange
        self.validationRun = validationRun
    }
}

private struct CodingAgentEvidenceFixture {
    let timestamp = Date(timeIntervalSince1970: 1_820_000_000)
    let repository: ProvenanceRepositoryRecord
    let worktree: ProvenanceWorktreeRecord
    let session: ProvenanceSessionRecord
    let thread: ProvenanceCodingAgentThreadRecord
    let secondThread: ProvenanceCodingAgentThreadRecord
    let firstTurnStarted: ProvenanceCodingAgentTurnRecord
    let firstTurnCompleted: ProvenanceCodingAgentTurnRecord
    let secondTurn: ProvenanceCodingAgentTurnRecord
    let thirdTurn: ProvenanceCodingAgentTurnRecord
    let prompt: ProvenanceCodingAgentPromptRecord
    let firstPlanUpdate: ProvenanceCodingAgentPlanUpdateRecord
    let finalPlanUpdate: ProvenanceCodingAgentPlanUpdateRecord
    let reasoningSummary: ProvenanceCodingAgentReasoningSummaryRecord
    let assistantMessage: ProvenanceCodingAgentAssistantMessageRecord
    let command: ProvenanceCodingAgentCommandRecord
    let changeSet: ProvenanceChangeSetRecord
    let fileChange: ProvenanceFileChangeRecord
    let fileChangeAttribution: ProvenanceCodingAgentFileChangeAttributionRecord
    let threadEvent: ProvenanceEvent
    let replayedThreadEvent: ProvenanceEvent
    let events: [ProvenanceEvent]

    init() {
        let timestamp = Date(timeIntervalSince1970: 1_820_000_000)
        let repository = ProvenanceRepositoryRecord(
            id: "repository-codex-evidence",
            path: "/repos/richer-session-evidence",
            remoteSlug: "BrianBusby/richer-session-evidence",
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let worktree = ProvenanceWorktreeRecord(
            id: "worktree-codex-evidence",
            repositoryID: repository.id,
            path: repository.path,
            branch: "richer-session-evidence-foundation",
            currentHEAD: "head-codex-evidence",
            isDirty: true,
            status: "active",
            lastReconciledAt: timestamp,
            updatedAt: timestamp
        )
        let session = ProvenanceSessionRecord(
            id: "pe-session-codex-evidence",
            agentKind: "codex",
            workspaceID: "bmux-workspace-1",
            surfaceID: "bmux-surface-1",
            worktreeID: worktree.id,
            cwd: repository.path,
            status: "active",
            startedAt: timestamp.addingTimeInterval(1),
            updatedAt: timestamp.addingTimeInterval(1)
        )
        let thread = ProvenanceCodingAgentThreadRecord(
            id: "coding-agent-thread-codex-42",
            sessionID: session.id,
            provider: "codex",
            providerThreadID: "codex-thread-42",
            worktreeID: worktree.id,
            source: .observed,
            confidence: .high,
            firstObservedAt: timestamp.addingTimeInterval(2),
            updatedAt: timestamp.addingTimeInterval(2)
        )
        let secondThread = ProvenanceCodingAgentThreadRecord(
            id: "coding-agent-thread-codex-43",
            sessionID: session.id,
            provider: "codex",
            providerThreadID: "codex-thread-43",
            worktreeID: worktree.id,
            source: .observed,
            confidence: .high,
            firstObservedAt: timestamp.addingTimeInterval(10),
            updatedAt: timestamp.addingTimeInterval(10)
        )
        let firstTurnStarted = ProvenanceCodingAgentTurnRecord(
            id: "coding-agent-turn-codex-1",
            sessionID: session.id,
            threadID: thread.id,
            provider: "codex",
            providerTurnID: "codex-turn-1",
            status: "started",
            model: "gpt-5-codex",
            effort: "medium",
            startedAt: timestamp.addingTimeInterval(3),
            updatedAt: timestamp.addingTimeInterval(3),
            source: .observed,
            confidence: .high
        )
        let firstTurnCompleted = ProvenanceCodingAgentTurnRecord(
            id: firstTurnStarted.id,
            sessionID: session.id,
            threadID: thread.id,
            provider: "codex",
            providerTurnID: "codex-turn-1",
            status: "completed",
            completedAt: timestamp.addingTimeInterval(11),
            updatedAt: timestamp.addingTimeInterval(11),
            source: .observed,
            confidence: .high
        )
        let secondTurn = ProvenanceCodingAgentTurnRecord(
            id: "coding-agent-turn-codex-2",
            sessionID: session.id,
            threadID: secondThread.id,
            provider: "codex",
            providerTurnID: "codex-turn-2",
            status: "completed",
            startedAt: timestamp.addingTimeInterval(12),
            completedAt: timestamp.addingTimeInterval(13),
            updatedAt: timestamp.addingTimeInterval(13),
            source: .observed,
            confidence: .high
        )
        let thirdTurn = ProvenanceCodingAgentTurnRecord(
            id: "coding-agent-turn-codex-3",
            sessionID: session.id,
            threadID: secondThread.id,
            provider: "codex",
            providerTurnID: "codex-turn-3",
            status: "started",
            startedAt: timestamp.addingTimeInterval(14),
            updatedAt: timestamp.addingTimeInterval(14),
            source: .observed,
            confidence: .high
        )
        let prompt = ProvenanceCodingAgentPromptRecord(
            id: "coding-agent-prompt-codex-1",
            sessionID: session.id,
            threadID: thread.id,
            turnID: firstTurnStarted.id,
            provider: "codex",
            text: "Establish the structured Codex evidence path.",
            submittedAt: timestamp.addingTimeInterval(4),
            source: .observed,
            confidence: .high
        )
        let firstPlanUpdate = ProvenanceCodingAgentPlanUpdateRecord(
            id: "coding-agent-plan-codex-1-a",
            sessionID: session.id,
            threadID: thread.id,
            turnID: firstTurnStarted.id,
            provider: "codex",
            explanation: "First implementation slice below semantic inference.",
            steps: [
                ProvenanceCodingAgentPlanStepRecord(
                    id: "coding-agent-plan-codex-1-a-step-0",
                    order: 0,
                    text: "Audit current telemetry path",
                    status: "completed"
                ),
                ProvenanceCodingAgentPlanStepRecord(
                    id: "coding-agent-plan-codex-1-a-step-1",
                    order: 1,
                    text: "Add durable PE evidence",
                    status: "in_progress"
                ),
            ],
            observedAt: timestamp.addingTimeInterval(5),
            source: .observed,
            confidence: .high
        )
        let reasoningSummary = ProvenanceCodingAgentReasoningSummaryRecord(
            id: "coding-agent-reasoning-summary-codex-1",
            sessionID: session.id,
            threadID: thread.id,
            turnID: firstTurnStarted.id,
            provider: "codex",
            itemID: "reasoning-summary-item-1",
            text: "Identified the provider-neutral telemetry adapter and PE append boundary.",
            completedAt: timestamp.addingTimeInterval(6),
            source: .observed,
            confidence: .high
        )
        let assistantMessage = ProvenanceCodingAgentAssistantMessageRecord(
            id: "coding-agent-assistant-message-codex-1",
            sessionID: session.id,
            threadID: thread.id,
            turnID: firstTurnStarted.id,
            provider: "codex",
            itemID: "assistant-message-item-1",
            text: "Final output.",
            completedAt: timestamp.addingTimeInterval(10),
            source: .observed,
            confidence: .high
        )
        let toolRun = ProvenanceCodingAgentCommandRecord(
            id: "coding-agent-command-codex-1",
            sessionID: session.id,
            threadID: thread.id,
            turnID: firstTurnStarted.id,
            provider: "codex",
            operationID: "tool-call-1",
            toolText: "build",
            cwd: repository.path,
            status: "succeeded",
            exitCode: 0,
            completedAt: timestamp.addingTimeInterval(7),
            source: .observed,
            confidence: .high
        )
        let changeSet = ProvenanceChangeSetRecord(
            id: "change-set-codex-evidence",
            worktreeID: worktree.id,
            summary: "Add coding-agent evidence records",
            diffFingerprint: "diff-codex-evidence",
            createdAt: timestamp.addingTimeInterval(8)
        )
        let fileChange = ProvenanceFileChangeRecord(
            id: "file-change-codex-evidence",
            changeSetID: changeSet.id,
            repositoryID: repository.id,
            worktreeID: worktree.id,
            path: "Sources/ProvenanceEngineContracts/ProvenanceCodingAgentThreadRecord.swift",
            status: "added",
            attributionSource: .observed,
            attributionConfidence: .high,
            updatedAt: timestamp.addingTimeInterval(8)
        )
        let fileChangeAttribution = ProvenanceCodingAgentFileChangeAttributionRecord(
            id: "coding-agent-file-change-codex-1",
            sessionID: session.id,
            threadID: thread.id,
            turnID: firstTurnStarted.id,
            provider: "codex",
            operationID: "file-change-item-1",
            changeSetID: changeSet.id,
            fileChangeIDs: [fileChange.id],
            paths: [fileChange.path],
            summary: "One contract file added during the turn.",
            observedAt: timestamp.addingTimeInterval(8),
            source: .observed,
            confidence: .high
        )
        let finalPlanUpdate = ProvenanceCodingAgentPlanUpdateRecord(
            id: "coding-agent-plan-codex-1-b",
            sessionID: session.id,
            threadID: thread.id,
            turnID: firstTurnStarted.id,
            provider: "codex",
            steps: [
                ProvenanceCodingAgentPlanStepRecord(
                    id: "coding-agent-plan-codex-1-b-step-0",
                    order: 0,
                    text: "Audit current telemetry path",
                    status: "completed"
                ),
                ProvenanceCodingAgentPlanStepRecord(
                    id: "coding-agent-plan-codex-1-b-step-1",
                    order: 1,
                    text: "Add durable PE evidence",
                    status: "completed"
                ),
            ],
            observedAt: timestamp.addingTimeInterval(9),
            source: .observed,
            confidence: .high
        )
        let sessionIdentity = ProvenanceExternalIdentityRecord(
            id: "external-identity-codex-session",
            sessionID: session.id,
            system: "bmux",
            kind: "agent_session",
            externalID: "bmux-agent-session-1",
            source: .observed,
            confidence: .high,
            createdAt: timestamp.addingTimeInterval(1),
            updatedAt: timestamp.addingTimeInterval(1)
        )
        let threadIdentity = ProvenanceExternalIdentityRecord(
            id: "external-identity-codex-thread",
            sessionID: session.id,
            system: "codex",
            kind: "thread",
            externalID: thread.providerThreadID,
            source: .observed,
            confidence: .high,
            createdAt: thread.firstObservedAt,
            updatedAt: thread.updatedAt
        )

        let baseEvent = Self.eventBuilder(
            repositoryID: repository.id,
            worktreeID: worktree.id,
            sessionID: session.id
        )
        let threadEvent = baseEvent(
            "event-codex-thread",
            .codingAgentThreadObserved,
            thread.firstObservedAt,
            ProvenanceEventPayload(externalIdentities: [threadIdentity], codingAgentThread: thread)
        )
        let secondThreadEvent = baseEvent(
            "event-codex-thread-2",
            .codingAgentThreadObserved,
            secondThread.firstObservedAt,
            ProvenanceEventPayload(codingAgentThread: secondThread)
        )
        let replayedThreadEvent = baseEvent(
            "event-codex-thread-replay",
            .codingAgentThreadObserved,
            timestamp.addingTimeInterval(15),
            ProvenanceEventPayload(codingAgentThread: thread)
        )

        self.repository = repository
        self.worktree = worktree
        self.session = session
        self.thread = thread
        self.secondThread = secondThread
        self.firstTurnStarted = firstTurnStarted
        self.firstTurnCompleted = firstTurnCompleted
        self.secondTurn = secondTurn
        self.thirdTurn = thirdTurn
        self.prompt = prompt
        self.firstPlanUpdate = firstPlanUpdate
        self.finalPlanUpdate = finalPlanUpdate
        self.reasoningSummary = reasoningSummary
        self.assistantMessage = assistantMessage
        self.command = toolRun
        self.changeSet = changeSet
        self.fileChange = fileChange
        self.fileChangeAttribution = fileChangeAttribution
        self.threadEvent = threadEvent
        self.replayedThreadEvent = replayedThreadEvent
        self.events = [
            baseEvent("event-codex-worktree", .worktreeObserved, timestamp, ProvenanceEventPayload(repository: repository, worktree: worktree)),
            baseEvent("event-codex-session", .sessionObserved, session.updatedAt, ProvenanceEventPayload(session: session, externalIdentities: [sessionIdentity])),
            threadEvent,
            secondThreadEvent,
            baseEvent("event-codex-turn-1-started", .codingAgentTurnObserved, firstTurnStarted.updatedAt, ProvenanceEventPayload(codingAgentTurn: firstTurnStarted)),
            baseEvent("event-codex-prompt-1", .codingAgentPromptSubmitted, prompt.submittedAt, ProvenanceEventPayload(codingAgentPrompt: prompt)),
            baseEvent("event-codex-plan-1-a", .codingAgentPlanUpdated, firstPlanUpdate.observedAt, ProvenanceEventPayload(codingAgentPlanUpdate: firstPlanUpdate)),
            baseEvent("event-codex-reasoning-summary-1", .codingAgentReasoningSummaryCompleted, reasoningSummary.completedAt, ProvenanceEventPayload(codingAgentReasoningSummary: reasoningSummary)),
            baseEvent("event-codex-assistant-message-1", .codingAgentAssistantMessageCompleted, assistantMessage.completedAt, ProvenanceEventPayload(codingAgentAssistantMessage: assistantMessage)),
            baseEvent("event-codex-tool-run-1", .codingAgentCommandCompleted, toolRun.completedAt, ProvenanceEventPayload(codingAgentCommand: toolRun)),
            baseEvent(
                "event-codex-file-change-1",
                .codingAgentFileChangeAttributed,
                fileChangeAttribution.observedAt,
                ProvenanceEventPayload(
                    changeSet: changeSet,
                    fileChanges: [fileChange],
                    codingAgentFileChangeAttribution: fileChangeAttribution
                )
            ),
            baseEvent("event-codex-plan-1-b", .codingAgentPlanUpdated, finalPlanUpdate.observedAt, ProvenanceEventPayload(codingAgentPlanUpdate: finalPlanUpdate)),
            baseEvent("event-codex-turn-1-completed", .codingAgentTurnObserved, firstTurnCompleted.updatedAt, ProvenanceEventPayload(codingAgentTurn: firstTurnCompleted)),
            baseEvent("event-codex-turn-2-completed", .codingAgentTurnObserved, secondTurn.updatedAt, ProvenanceEventPayload(codingAgentTurn: secondTurn)),
            baseEvent("event-codex-turn-3-started", .codingAgentTurnObserved, thirdTurn.updatedAt, ProvenanceEventPayload(codingAgentTurn: thirdTurn)),
            baseEvent("event-codex-session-still-active", .sessionObserved, timestamp.addingTimeInterval(16), ProvenanceEventPayload(session: session)),
        ]
    }

    private static func eventBuilder(
        repositoryID: String,
        worktreeID: String,
        sessionID: String
    ) -> (String, ProvenanceEventType, Date, ProvenanceEventPayload) -> ProvenanceEvent {
        { id, eventType, timestamp, payload in
            ProvenanceEvent(
                id: id,
                eventType: eventType,
                timestamp: timestamp,
                repositoryID: repositoryID,
                worktreeID: worktreeID,
                sessionID: sessionID,
                source: .observed,
                evidenceOrigin: .codexSession,
                evidenceScope: ProvenanceEvidenceScope(level: .personal, id: "local-codex-session"),
                confidence: .high,
                payload: payload
            )
        }
    }
}
