import Foundation
import ProvenanceEngineContracts
@testable import ProvenanceEngineSQLite
import Testing

@Suite
struct FirstSemanticSessionInferenceTests {
    @Test
    func repositoryClientPublishesQueriesAndSupersedesCurrentActivity() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)
        let base = FixtureBase()
        let startedTurn = base.turn(status: "started")
        let prompt = base.prompt("Move workspace selection onto the shared TabManager path.", turnID: startedTurn.id)
        let reasoning = base.reasoning(
            "Reading workspace-selection callers before changing them",
            turnID: startedTurn.id,
            offset: 4
        )

        try await base.appendSessionThreadAndTurn(startedTurn, into: repository)
        try await base.append(prompt, into: repository)
        try await base.append(reasoning, into: repository)

        let firstPass = try await repository.publishCodingAgentSessionSemanticInferences(
            ProvenanceCodingAgentSessionSemanticInferenceRequest(
                sessionID: base.session.id,
                createdAt: base.timestamp.addingTimeInterval(20)
            )
        )
        let initialActivity = try Self.activityPayload(from: firstPass.records, scopeID: startedTurn.id)
        #expect(firstPass.publishedInferenceIDs.count == 5)
        #expect(initialActivity.activityKind == .investigation)
        #expect(initialActivity.summary == "Reading workspace-selection callers before changing them")

        let fileAttribution = base.fileAttribution(
            "Changing App Menu workspace selection to use TabManager",
            turnID: startedTurn.id,
            offset: 8
        )
        try await base.append(fileAttribution, into: repository)

        let secondPass = try await repository.publishCodingAgentSessionSemanticInferences(
            ProvenanceCodingAgentSessionSemanticInferenceRequest(
                sessionID: base.session.id,
                createdAt: base.timestamp.addingTimeInterval(30)
            )
        )
        let updatedActivityRecord = try Self.record(
            .currentActivity,
            scope: .turn,
            scopeID: startedTurn.id,
            from: secondPass.records
        )
        let updatedActivity = try Self.activityPayload(from: updatedActivityRecord)
        let activityHistory = try await repository.semanticInferences(
            ProvenanceSemanticInferenceQueryRequest(
                scope: .turn,
                scopeID: startedTurn.id,
                kind: ProvenanceCodingAgentSemanticInferenceKind.currentActivity.rawValue,
                includeInactive: true
            )
        )

        #expect(secondPass.unchangedInferenceIDs.count == 3)
        #expect(secondPass.publishedInferenceIDs.count == 2)
        #expect(updatedActivity.activityKind == .implementation)
        #expect(updatedActivity.summary == "Changing App Menu workspace selection to use TabManager")
        #expect(updatedActivity.components == ["Sources/AppMenu.swift"])
        #expect(activityHistory.records.map(\.status) == [.active, .superseded])
        #expect(activityHistory.records.first?.id == updatedActivityRecord.id)
        #expect(activityHistory.records.last?.supersededBy == updatedActivityRecord.id)
    }

    @Test
    func implementationThenValidationPrefersLatestValidationCommand() throws {
        let base = FixtureBase()
        let turn = base.turn(status: "completed", completedOffset: 9)
        let snapshot = base.snapshot(turns: [base.turnSnapshot(
            turn: turn,
            prompt: base.prompt("Implement first semantic session inference records.", turnID: turn.id),
            plan: base.plan("Add the semantic inference producer", turnID: turn.id, offset: 5),
            commands: [base.command("swift test", turnID: turn.id, offset: 8)],
            fileAttributions: [base.fileAttribution("Adding semantic inference producer contracts", turnID: turn.id, offset: 7)]
        )])

        let records = ProvenanceCodingAgentSessionSemanticInferenceProducer.records(
            for: snapshot,
            createdAt: base.timestamp.addingTimeInterval(20)
        )
        let activity = try Self.activityPayload(from: records, scopeID: turn.id)
        let phase = try Self.phasePayload(from: records, sessionID: base.session.id)

        #expect(activity.activityKind == .validation)
        #expect(activity.summary == "Validating with swift test")
        #expect(phase.phase == .validation)
    }

    @Test
    func failedCommandYieldsDebuggingPhase() throws {
        let base = FixtureBase()
        let turn = base.turn(status: "failed", completedOffset: 9)
        let snapshot = base.snapshot(turns: [base.turnSnapshot(
            turn: turn,
            prompt: base.prompt("Validate the semantic inference implementation.", turnID: turn.id),
            commands: [base.command("swift test", status: "failed", exitCode: 1, turnID: turn.id, offset: 8)]
        )])

        let records = ProvenanceCodingAgentSessionSemanticInferenceProducer.records(
            for: snapshot,
            createdAt: base.timestamp.addingTimeInterval(20)
        )
        let activity = try Self.activityPayload(from: records, scopeID: turn.id)
        let phase = try Self.phasePayload(from: records, sessionID: base.session.id)

        #expect(activity.activityKind == .debugging)
        #expect(activity.summary == "Investigating failed command: swift test")
        #expect(phase.phase == .debugging)
    }

    @Test
    func changedDirectionUsesLatestTurnIntentWhileThreadIntentStaysBroad() throws {
        let base = FixtureBase()
        let firstTurn = base.turn(id: "turn-1", providerTurnID: "provider-turn-1", status: "completed", completedOffset: 5)
        let secondTurn = base.turn(id: "turn-2", providerTurnID: "provider-turn-2", status: "started", startOffset: 8)
        let firstSnapshot = base.turnSnapshot(
            turn: firstTurn,
            prompt: base.prompt("Build semantic inference support for coding-agent sessions.", turnID: firstTurn.id, offset: 3),
            plan: base.plan("Implement the semantic record framework", turnID: firstTurn.id, offset: 4)
        )
        let secondSnapshot = base.turnSnapshot(
            turn: secondTurn,
            prompt: base.prompt("Switch to validating semantic inference APIs.", turnID: secondTurn.id, offset: 9),
            plan: base.plan("Validate semantic query and publish APIs", turnID: secondTurn.id, offset: 10)
        )
        let snapshot = base.snapshot(turns: [firstSnapshot, secondSnapshot])

        let records = ProvenanceCodingAgentSessionSemanticInferenceProducer.records(
            for: snapshot,
            createdAt: base.timestamp.addingTimeInterval(20)
        )
        let threadIntent = try Self.intentPayload(
            from: records,
            kind: .threadIntent,
            scope: .thread,
            scopeID: base.thread.id
        )
        let turnIntent = try Self.intentPayload(
            from: records,
            kind: .turnIntent,
            scope: .turn,
            scopeID: secondTurn.id
        )

        #expect(threadIntent.summary == "Build semantic inference support for coding-agent sessions")
        #expect(turnIntent.summary == "Switch to validating semantic inference APIs")
    }

    @Test
    func activePlanCanRepresentImplementationBeforeFilesChange() throws {
        let base = FixtureBase()
        let turn = base.turn(status: "started")
        let snapshot = base.snapshot(turns: [base.turnSnapshot(
            turn: turn,
            prompt: base.prompt("Inspect workspace selection and then update the App Menu caller.", turnID: turn.id),
            plan: base.plan("Change App Menu workspace selection to use TabManager", turnID: turn.id, offset: 6)
        )])

        let records = ProvenanceCodingAgentSessionSemanticInferenceProducer.records(
            for: snapshot,
            createdAt: base.timestamp.addingTimeInterval(20)
        )
        let activity = try Self.activityPayload(from: records, scopeID: turn.id)
        let phase = try Self.phasePayload(from: records, sessionID: base.session.id)

        #expect(activity.activityKind == .implementation)
        #expect(activity.summary == "Change App Menu workspace selection to use TabManager")
        #expect(activity.target == "TabManager")
        #expect(phase.phase == .implementation)
    }

    @Test
    func currentPlanStepsProduceSessionMilestones() throws {
        let base = FixtureBase()
        let turn = base.turn(status: "started")
        let plan = base.plan(
            steps: [
                (text: "Inspect existing semantic fields", status: "completed"),
                (text: "Add milestone payload contracts", status: "in_progress"),
                (text: "Project milestones into SessionWorkModel", status: "pending"),
            ],
            turnID: turn.id,
            offset: 6
        )
        let snapshot = base.snapshot(turns: [base.turnSnapshot(
            turn: turn,
            prompt: base.prompt("Implement milestone inference for coding-agent sessions.", turnID: turn.id),
            plan: plan
        )])

        let records = ProvenanceCodingAgentSessionSemanticInferenceProducer.records(
            for: snapshot,
            createdAt: base.timestamp.addingTimeInterval(20)
        )
        let milestoneRecord = try Self.record(.milestones, scope: .session, scopeID: base.session.id, from: records)
        let payload = try Self.milestonePayload(from: milestoneRecord)
        let activeMilestone = try #require(payload.milestones.first { $0.status == .active })
        let hasPlanEvidence = milestoneRecord.supportingEvidenceRefs.contains {
            $0.kind == "coding_agent_plan_update" && $0.id == plan.id
        }

        #expect(payload.basis == "current_plan")
        #expect(payload.milestones.map(\.title) == [
            "Inspect existing semantic fields",
            "Add milestone payload contracts",
            "Project milestones into SessionWorkModel",
        ])
        #expect(payload.milestones.map(\.status) == [.completed, .active, .planned])
        #expect(payload.milestones.count == 3)
        #expect(payload.currentMilestoneID == activeMilestone.id)
        #expect(milestoneRecord.confidence == .medium)
        #expect(milestoneRecord.specificity == .scoped)
        #expect(hasPlanEvidence)
    }

    @Test
    func ambiguousTurnEvidencePublishesUnknownBroadClaims() throws {
        let base = FixtureBase()
        let turn = base.turn(status: "started")
        let snapshot = base.snapshot(turns: [base.turnSnapshot(turn: turn)])

        let records = ProvenanceCodingAgentSessionSemanticInferenceProducer.records(
            for: snapshot,
            createdAt: base.timestamp.addingTimeInterval(20)
        )
        let turnIntentRecord = try Self.record(.turnIntent, scope: .turn, scopeID: turn.id, from: records)
        let milestoneRecord = try Self.record(.milestones, scope: .session, scopeID: base.session.id, from: records)
        let activityRecord = try Self.record(.currentActivity, scope: .turn, scopeID: turn.id, from: records)
        let phaseRecord = try Self.record(.sessionPhase, scope: .session, scopeID: base.session.id, from: records)
        let turnIntent = try #require(ProvenanceCodingAgentIntentPayload(semanticPayloadValue: turnIntentRecord.payload))
        let milestonePayload = try Self.milestonePayload(from: milestoneRecord)
        let activity = try Self.activityPayload(from: activityRecord)
        let phase = try Self.phasePayload(from: phaseRecord)

        #expect(turnIntent.summary == "Unknown turn intent")
        #expect(turnIntentRecord.confidence == .unknown)
        #expect(turnIntentRecord.specificity == .broad)
        #expect(milestonePayload.milestones.isEmpty)
        #expect(milestonePayload.unknownReason != nil)
        #expect(milestoneRecord.confidence == .unknown)
        #expect(milestoneRecord.specificity == .broad)
        #expect(activity.activityKind == .unknown)
        #expect(activityRecord.confidence == .unknown)
        #expect(activityRecord.specificity == .broad)
        #expect(phase.phase == .unknown)
        #expect(phaseRecord.confidence == .unknown)
    }

    @Test
    func irrelevantCommandsDoNotDominatePlanMeaning() throws {
        let base = FixtureBase()
        let turn = base.turn(status: "started")
        let snapshot = base.snapshot(turns: [base.turnSnapshot(
            turn: turn,
            prompt: base.prompt("Update App Menu workspace selection.", turnID: turn.id),
            plan: base.plan("Change App Menu workspace selection to use TabManager", turnID: turn.id, offset: 5),
            commands: [base.command("pwd", turnID: turn.id, offset: 9)]
        )])

        let records = ProvenanceCodingAgentSessionSemanticInferenceProducer.records(
            for: snapshot,
            createdAt: base.timestamp.addingTimeInterval(20)
        )
        let activity = try Self.activityPayload(from: records, scopeID: turn.id)

        #expect(activity.activityKind == .implementation)
        #expect(activity.summary == "Change App Menu workspace selection to use TabManager")
        #expect(activity.basis == "current_plan")
    }

    @Test
    func producerRecordOrderAndIDsAreDeterministic() throws {
        let base = FixtureBase()
        let turn = base.turn(status: "started")
        let snapshot = base.snapshot(turns: [base.turnSnapshot(
            turn: turn,
            prompt: base.prompt("Implement deterministic semantic records.", turnID: turn.id),
            plan: base.plan("Implement deterministic semantic record IDs", turnID: turn.id, offset: 5)
        )])
        let createdAt = base.timestamp.addingTimeInterval(20)

        let first = ProvenanceCodingAgentSessionSemanticInferenceProducer.records(for: snapshot, createdAt: createdAt)
        let second = ProvenanceCodingAgentSessionSemanticInferenceProducer.records(for: snapshot, createdAt: createdAt)

        #expect(first.map(\.kind) == [
            ProvenanceCodingAgentSemanticInferenceKind.threadIntent.rawValue,
            ProvenanceCodingAgentSemanticInferenceKind.turnIntent.rawValue,
            ProvenanceCodingAgentSemanticInferenceKind.milestones.rawValue,
            ProvenanceCodingAgentSemanticInferenceKind.sessionPhase.rawValue,
            ProvenanceCodingAgentSemanticInferenceKind.currentActivity.rawValue,
        ])
        #expect(first.map(\.id) == second.map(\.id))
        #expect(first == second)
    }

    private static func record(
        _ kind: ProvenanceCodingAgentSemanticInferenceKind,
        scope: ProvenanceSemanticInferenceScope,
        scopeID: String,
        from records: [ProvenanceSemanticInferenceRecord]
    ) throws -> ProvenanceSemanticInferenceRecord {
        try #require(records.first {
            $0.kind == kind.rawValue && $0.scope == scope && $0.scopeID == scopeID
        })
    }

    private static func intentPayload(
        from records: [ProvenanceSemanticInferenceRecord],
        kind: ProvenanceCodingAgentSemanticInferenceKind,
        scope: ProvenanceSemanticInferenceScope,
        scopeID: String
    ) throws -> ProvenanceCodingAgentIntentPayload {
        let record = try record(kind, scope: scope, scopeID: scopeID, from: records)
        return try #require(ProvenanceCodingAgentIntentPayload(semanticPayloadValue: record.payload))
    }

    private static func activityPayload(
        from records: [ProvenanceSemanticInferenceRecord],
        scopeID: String
    ) throws -> ProvenanceCodingAgentCurrentActivityPayload {
        let record = try record(.currentActivity, scope: .turn, scopeID: scopeID, from: records)
        return try activityPayload(from: record)
    }

    private static func activityPayload(
        from record: ProvenanceSemanticInferenceRecord
    ) throws -> ProvenanceCodingAgentCurrentActivityPayload {
        try #require(ProvenanceCodingAgentCurrentActivityPayload(semanticPayloadValue: record.payload))
    }

    private static func milestonePayload(
        from record: ProvenanceSemanticInferenceRecord
    ) throws -> ProvenanceCodingAgentMilestonePayload {
        try #require(ProvenanceCodingAgentMilestonePayload(semanticPayloadValue: record.payload))
    }

    private static func phasePayload(
        from records: [ProvenanceSemanticInferenceRecord],
        sessionID: String
    ) throws -> ProvenanceCodingAgentSessionPhasePayload {
        let record = try record(.sessionPhase, scope: .session, scopeID: sessionID, from: records)
        return try phasePayload(from: record)
    }

    private static func phasePayload(
        from record: ProvenanceSemanticInferenceRecord
    ) throws -> ProvenanceCodingAgentSessionPhasePayload {
        try #require(ProvenanceCodingAgentSessionPhasePayload(semanticPayloadValue: record.payload))
    }

    private static func temporaryDatabaseURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("provenance-engine-first-semantic-session-inference-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("provenance.sqlite")
    }

    private static func removeTemporaryDatabaseDirectory(for url: URL) {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }
}

private struct FixtureBase {
    let timestamp = Date(timeIntervalSince1970: 1_830_000_000)
    let session: ProvenanceSessionRecord
    let thread: ProvenanceCodingAgentThreadRecord

    init() {
        let timestamp = Date(timeIntervalSince1970: 1_830_000_000)
        self.session = ProvenanceSessionRecord(
            id: "session-semantic-fixture",
            agentKind: "codex",
            workspaceID: "workspace-semantic-fixture",
            surfaceID: "surface-semantic-fixture",
            worktreeID: "worktree-semantic-fixture",
            cwd: "/repos/semantic-fixture",
            status: "active",
            startedAt: timestamp,
            updatedAt: timestamp
        )
        self.thread = ProvenanceCodingAgentThreadRecord(
            id: "thread-semantic-fixture",
            sessionID: session.id,
            provider: "codex",
            providerThreadID: "provider-thread-semantic-fixture",
            worktreeID: "worktree-semantic-fixture",
            source: .observed,
            confidence: .high,
            firstObservedAt: timestamp.addingTimeInterval(1),
            updatedAt: timestamp.addingTimeInterval(1)
        )
    }

    func turn(
        id: String = "turn-semantic-fixture",
        providerTurnID: String = "provider-turn-semantic-fixture",
        status: String,
        startOffset: TimeInterval = 2,
        completedOffset: TimeInterval? = nil
    ) -> ProvenanceCodingAgentTurnRecord {
        ProvenanceCodingAgentTurnRecord(
            id: id,
            sessionID: session.id,
            threadID: thread.id,
            provider: "codex",
            providerTurnID: providerTurnID,
            status: status,
            model: "gpt-5-codex",
            effort: "medium",
            startedAt: timestamp.addingTimeInterval(startOffset),
            completedAt: completedOffset.map { timestamp.addingTimeInterval($0) },
            updatedAt: timestamp.addingTimeInterval(completedOffset ?? startOffset),
            source: .observed,
            confidence: .high
        )
    }

    func prompt(_ text: String, turnID: String, offset: TimeInterval = 3) -> ProvenanceCodingAgentPromptRecord {
        ProvenanceCodingAgentPromptRecord(
            id: "prompt-\(turnID)-\(Int(offset))",
            sessionID: session.id,
            threadID: thread.id,
            turnID: turnID,
            provider: "codex",
            text: text,
            submittedAt: timestamp.addingTimeInterval(offset),
            source: .observed,
            confidence: .high
        )
    }

    func plan(_ text: String, turnID: String, offset: TimeInterval = 5) -> ProvenanceCodingAgentPlanUpdateRecord {
        plan(steps: [(text: text, status: "in_progress")], turnID: turnID, offset: offset)
    }

    func plan(
        steps: [(text: String, status: String)],
        turnID: String,
        offset: TimeInterval = 5
    ) -> ProvenanceCodingAgentPlanUpdateRecord {
        ProvenanceCodingAgentPlanUpdateRecord(
            id: "plan-\(turnID)-\(Int(offset))",
            sessionID: session.id,
            threadID: thread.id,
            turnID: turnID,
            provider: "codex",
            explanation: nil,
            steps: steps.enumerated().map { index, step in
                ProvenanceCodingAgentPlanStepRecord(
                    id: "plan-step-\(turnID)-\(Int(offset))-\(index)",
                    order: index,
                    text: step.text,
                    status: step.status
                )
            },
            observedAt: timestamp.addingTimeInterval(offset),
            source: .observed,
            confidence: .high
        )
    }

    func command(
        _ text: String,
        status: String = "succeeded",
        exitCode: Int? = 0,
        turnID: String,
        offset: TimeInterval
    ) -> ProvenanceCodingAgentCommandRecord {
        ProvenanceCodingAgentCommandRecord(
            id: "command-\(turnID)-\(Int(offset))",
            sessionID: session.id,
            threadID: thread.id,
            turnID: turnID,
            provider: "codex",
            operationID: "operation-\(turnID)-\(Int(offset))",
            command: text,
            cwd: "/repos/semantic-fixture",
            status: status,
            exitCode: exitCode,
            outputSummary: nil,
            startedAt: timestamp.addingTimeInterval(offset - 1),
            completedAt: timestamp.addingTimeInterval(offset),
            source: .observed,
            confidence: .high
        )
    }

    func reasoning(_ text: String, turnID: String, offset: TimeInterval) -> ProvenanceCodingAgentReasoningSummaryRecord {
        ProvenanceCodingAgentReasoningSummaryRecord(
            id: "reasoning-\(turnID)-\(Int(offset))",
            sessionID: session.id,
            threadID: thread.id,
            turnID: turnID,
            provider: "codex",
            itemID: "reasoning-item-\(turnID)-\(Int(offset))",
            text: text,
            completedAt: timestamp.addingTimeInterval(offset),
            source: .observed,
            confidence: .high
        )
    }

    func fileAttribution(
        _ summary: String,
        turnID: String,
        offset: TimeInterval
    ) -> ProvenanceCodingAgentFileChangeAttributionRecord {
        ProvenanceCodingAgentFileChangeAttributionRecord(
            id: "file-attribution-\(turnID)-\(Int(offset))",
            sessionID: session.id,
            threadID: thread.id,
            turnID: turnID,
            provider: "codex",
            operationID: "file-operation-\(turnID)-\(Int(offset))",
            changeSetID: nil,
            fileChangeIDs: [],
            paths: ["Sources/AppMenu.swift"],
            summary: summary,
            observedAt: timestamp.addingTimeInterval(offset),
            source: .observed,
            confidence: .high
        )
    }

    func turnSnapshot(
        turn: ProvenanceCodingAgentTurnRecord,
        prompt: ProvenanceCodingAgentPromptRecord? = nil,
        plan: ProvenanceCodingAgentPlanUpdateRecord? = nil,
        commands: [ProvenanceCodingAgentCommandRecord] = [],
        reasoningSummaries: [ProvenanceCodingAgentReasoningSummaryRecord] = [],
        fileAttributions: [ProvenanceCodingAgentFileChangeAttributionRecord] = []
    ) -> ProvenanceFactualSessionProjectionTurnSnapshot {
        ProvenanceFactualSessionProjectionTurnSnapshot(
            turn: turn,
            submittedPrompt: prompt,
            currentPlan: plan,
            completedCommands: commands,
            visibleReasoningSummaries: reasoningSummaries,
            fileChangeAttributions: fileAttributions
        )
    }

    func snapshot(
        turns: [ProvenanceFactualSessionProjectionTurnSnapshot],
        revision: Int = 7
    ) -> ProvenanceFactualSessionProjectionSnapshot {
        ProvenanceFactualSessionProjectionSnapshot(
            revision: revision,
            session: session,
            providerThreadIdentities: [ProvenanceFactualSessionProjectionProviderThreadIdentity(thread: thread)],
            providerThreads: [thread],
            latestTurn: turns.last,
            priorTurns: turns.dropLast().map { ProvenanceFactualSessionProjectionTurnReference(turn: $0.turn) },
            turns: turns
        )
    }

    func appendSessionThreadAndTurn(
        _ turn: ProvenanceCodingAgentTurnRecord,
        into repository: ProvenanceSQLiteRepository
    ) async throws {
        try await append(
            eventID: "event-session",
            eventType: .sessionObserved,
            timestamp: session.updatedAt,
            payload: ProvenanceEventPayload(session: session),
            into: repository
        )
        try await append(
            eventID: "event-thread",
            eventType: .codingAgentThreadObserved,
            timestamp: thread.updatedAt,
            payload: ProvenanceEventPayload(codingAgentThread: thread),
            into: repository
        )
        try await append(turn, into: repository)
    }

    func append(_ turn: ProvenanceCodingAgentTurnRecord, into repository: ProvenanceSQLiteRepository) async throws {
        try await append(
            eventID: "event-\(turn.id)-\(Int(turn.updatedAt.timeIntervalSince1970))",
            eventType: .codingAgentTurnObserved,
            timestamp: turn.updatedAt,
            payload: ProvenanceEventPayload(codingAgentTurn: turn),
            into: repository
        )
    }

    func append(_ prompt: ProvenanceCodingAgentPromptRecord, into repository: ProvenanceSQLiteRepository) async throws {
        try await append(
            eventID: "event-\(prompt.id)",
            eventType: .codingAgentPromptSubmitted,
            timestamp: prompt.submittedAt,
            payload: ProvenanceEventPayload(codingAgentPrompt: prompt),
            into: repository
        )
    }

    func append(
        _ reasoning: ProvenanceCodingAgentReasoningSummaryRecord,
        into repository: ProvenanceSQLiteRepository
    ) async throws {
        try await append(
            eventID: "event-\(reasoning.id)",
            eventType: .codingAgentReasoningSummaryCompleted,
            timestamp: reasoning.completedAt,
            payload: ProvenanceEventPayload(codingAgentReasoningSummary: reasoning),
            into: repository
        )
    }

    func append(
        _ attribution: ProvenanceCodingAgentFileChangeAttributionRecord,
        into repository: ProvenanceSQLiteRepository
    ) async throws {
        try await append(
            eventID: "event-\(attribution.id)",
            eventType: .codingAgentFileChangeAttributed,
            timestamp: attribution.observedAt,
            payload: ProvenanceEventPayload(codingAgentFileChangeAttribution: attribution),
            into: repository
        )
    }

    private func append(
        eventID: String,
        eventType: ProvenanceEventType,
        timestamp: Date,
        payload: ProvenanceEventPayload,
        into repository: ProvenanceSQLiteRepository
    ) async throws {
        try await repository.appendEvent(
            ProvenanceEvent(
                id: eventID,
                eventType: eventType,
                timestamp: timestamp,
                sessionID: session.id,
                source: .observed,
                evidenceOrigin: .codexSession,
                evidenceScope: ProvenanceEvidenceScope(level: .personal, id: "semantic-fixture"),
                confidence: .high,
                payload: payload
            )
        )
    }
}
