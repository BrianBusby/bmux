import Foundation
import ProvenanceEngineContracts
import ProvenanceEngineSDK
import Testing

@Suite
struct ProvenanceEngineSessionWorkModelClientFactoryTests {
    @Test
    func sqliteClientReadsSessionWorkModelThroughPublicContract() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let client = try ProvenanceEngineClientFactory().sqliteClient(databaseURL: url)
        let timestamp = Date(timeIntervalSince1970: 1_800_000_000)
        let session = ProvenanceSessionRecord(
            id: "session-work-model-sdk",
            agentKind: "codex",
            worktreeID: "worktree-work-model-sdk",
            status: "active",
            startedAt: timestamp,
            updatedAt: timestamp
        )
        let thread = ProvenanceCodingAgentThreadRecord(
            id: "thread-work-model-sdk",
            sessionID: session.id,
            provider: "codex",
            providerThreadID: "provider-thread-work-model-sdk",
            worktreeID: session.worktreeID,
            source: .observed,
            confidence: .high,
            firstObservedAt: timestamp.addingTimeInterval(1),
            updatedAt: timestamp.addingTimeInterval(1)
        )
        let turn = ProvenanceCodingAgentTurnRecord(
            id: "turn-work-model-sdk",
            sessionID: session.id,
            threadID: thread.id,
            provider: "codex",
            providerTurnID: "provider-turn-work-model-sdk",
            status: "started",
            model: "gpt-5-codex",
            effort: "medium",
            startedAt: timestamp.addingTimeInterval(2),
            completedAt: nil,
            updatedAt: timestamp.addingTimeInterval(2),
            source: .observed,
            confidence: .high
        )
        let prompt = ProvenanceCodingAgentPromptRecord(
            id: "prompt-work-model-sdk",
            sessionID: session.id,
            threadID: thread.id,
            turnID: turn.id,
            provider: "codex",
            text: "Expose SessionWorkModel through the public SDK.",
            submittedAt: timestamp.addingTimeInterval(3),
            source: .observed,
            confidence: .high
        )
        let plan = ProvenanceCodingAgentPlanUpdateRecord(
            id: "plan-work-model-sdk",
            sessionID: session.id,
            threadID: thread.id,
            turnID: turn.id,
            provider: "codex",
            steps: [
                ProvenanceCodingAgentPlanStepRecord(
                    id: "plan-step-work-model-sdk",
                    order: 0,
                    text: "Expose milestone semantics through the public SDK.",
                    status: "in_progress"
                ),
            ],
            observedAt: timestamp.addingTimeInterval(4),
            source: .observed,
            confidence: .high
        )

        let events = [
            ProvenanceEvent(
                id: "event-\(session.id)",
                eventType: .sessionObserved,
                timestamp: session.updatedAt,
                sessionID: session.id,
                source: .observed,
                confidence: .high,
                payload: ProvenanceEventPayload(session: session)
            ),
            ProvenanceEvent(
                id: "event-\(thread.id)",
                eventType: .codingAgentThreadObserved,
                timestamp: thread.updatedAt,
                sessionID: session.id,
                source: .observed,
                confidence: .high,
                payload: ProvenanceEventPayload(codingAgentThread: thread)
            ),
            ProvenanceEvent(
                id: "event-\(turn.id)",
                eventType: .codingAgentTurnObserved,
                timestamp: turn.updatedAt,
                sessionID: session.id,
                source: .observed,
                confidence: .high,
                payload: ProvenanceEventPayload(codingAgentTurn: turn)
            ),
            ProvenanceEvent(
                id: "event-\(prompt.id)",
                eventType: .codingAgentPromptSubmitted,
                timestamp: prompt.submittedAt,
                sessionID: session.id,
                source: .observed,
                confidence: .high,
                payload: ProvenanceEventPayload(codingAgentPrompt: prompt)
            ),
            ProvenanceEvent(
                id: "event-\(plan.id)",
                eventType: .codingAgentPlanUpdated,
                timestamp: plan.observedAt,
                sessionID: session.id,
                source: .observed,
                confidence: .high,
                payload: ProvenanceEventPayload(codingAgentPlanUpdate: plan)
            ),
        ]
        for event in events {
            _ = try await client.appendEvent(ProvenanceAppendEventRequest(event: event))
        }

        let publish = try await client.publishCodingAgentSessionSemanticInferences(
            ProvenanceCodingAgentSessionSemanticInferenceRequest(
                sessionID: session.id,
                createdAt: timestamp.addingTimeInterval(20)
            )
        )
        let repeatPublish = try await client.publishCodingAgentSessionSemanticInferences(
            ProvenanceCodingAgentSessionSemanticInferenceRequest(
                sessionID: session.id,
                createdAt: timestamp.addingTimeInterval(21)
            )
        )
        let health = try await client.health()
        let response = try await client.sessionWorkModel(
            ProvenanceSessionWorkModelRequest(sessionID: session.id)
        )
        let model = try #require(response.model)
        let milestoneRecord = try #require(model.milestones.record)
        let milestonePayload = try #require(ProvenanceCodingAgentMilestonePayload(
            semanticPayloadValue: milestoneRecord.payload
        ))

        #expect(health.capabilities.contains(.querySessionWorkModel))
        #expect(publish.publishedInferenceIDs.count == 7)
        #expect(repeatPublish.unchangedInferenceIDs.count == 7)
        #expect(response.found == true)
        #expect(model.identity.session == session)
        #expect(model.thread?.identity.threadID == thread.id)
        #expect(model.currentTurn?.turn == turn)
        #expect(model.currentTurn?.prompt == prompt)
        #expect(model.currentTurn?.intent.state == .known)
        #expect(model.currentTurn?.currentActivity.state == .known)
        #expect(model.milestones.state == .known)
        #expect(model.blockers.state == .known)
        #expect(model.approachChanges.state == .known)
        #expect(milestonePayload.basis == "current_plan")
        #expect(milestonePayload.milestones.map(\.title) == [
            "Expose milestone semantics through the public SDK",
        ])
        #expect(milestonePayload.milestones.first?.identityBasis == .providerPlanStepID)
        #expect(milestonePayload.milestones.first?.stateBasis == .providerPlanStepStatus)

        let reopenedClient = try ProvenanceEngineClientFactory().sqliteClient(databaseURL: url)
        let reopenedModel = try #require(try await reopenedClient.sessionWorkModel(
            ProvenanceSessionWorkModelRequest(sessionID: session.id)
        ).model)
        #expect(reopenedModel.milestones.record?.inferenceID == milestoneRecord.inferenceID)
        #expect(reopenedModel.blockers.record?.payload == model.blockers.record?.payload)
        #expect(reopenedModel.approachChanges.record?.payload == model.approachChanges.record?.payload)
    }

    @Test
    func sqliteClientReadsSessionOutcomeThroughPublicContractAndCodableSerialization() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let client = try ProvenanceEngineClientFactory().sqliteClient(databaseURL: url)
        let timestamp = Date(timeIntervalSince1970: 1_800_000_500)
        let session = ProvenanceSessionRecord(
            id: "session-outcome-sdk",
            agentKind: "codex",
            status: "completed",
            startedAt: timestamp,
            updatedAt: timestamp.addingTimeInterval(8)
        )
        let thread = ProvenanceCodingAgentThreadRecord(
            id: "thread-outcome-sdk",
            sessionID: session.id,
            provider: "codex",
            providerThreadID: "provider-thread-outcome-sdk",
            source: .observed,
            confidence: .high,
            firstObservedAt: timestamp.addingTimeInterval(1),
            updatedAt: timestamp.addingTimeInterval(1)
        )
        let turn = ProvenanceCodingAgentTurnRecord(
            id: "turn-outcome-sdk",
            sessionID: session.id,
            threadID: thread.id,
            provider: "codex",
            providerTurnID: "provider-turn-outcome-sdk",
            status: "completed",
            model: "gpt-5-codex",
            effort: "medium",
            startedAt: timestamp.addingTimeInterval(2),
            completedAt: timestamp.addingTimeInterval(7),
            updatedAt: timestamp.addingTimeInterval(7),
            source: .observed,
            confidence: .high
        )
        let prompt = ProvenanceCodingAgentPromptRecord(
            id: "prompt-outcome-sdk",
            sessionID: session.id,
            threadID: thread.id,
            turnID: turn.id,
            provider: "codex",
            text: "Expose SessionOutcome through the public SDK.",
            submittedAt: timestamp.addingTimeInterval(3),
            source: .declared,
            confidence: .high
        )
        let sdkCommandText = ["swift", "test", "--filter", "ProvenanceEngineSessionWorkModelClientFactoryTests"]
            .joined(separator: " ")
        let completedCommand = ProvenanceCodingAgentCommandRecord(
            id: "command-outcome-sdk",
            sessionID: session.id,
            threadID: thread.id,
            turnID: turn.id,
            provider: "codex",
            command: sdkCommandText,
            status: "succeeded",
            exitCode: 0,
            completedAt: timestamp.addingTimeInterval(6),
            source: .observed,
            confidence: .high
        )
        let events = [
            ProvenanceEvent(
                id: "event-\(session.id)",
                eventType: .sessionObserved,
                timestamp: session.updatedAt,
                sessionID: session.id,
                source: .observed,
                confidence: .high,
                payload: ProvenanceEventPayload(session: session)
            ),
            ProvenanceEvent(
                id: "event-\(thread.id)",
                eventType: .codingAgentThreadObserved,
                timestamp: thread.updatedAt,
                sessionID: session.id,
                source: .observed,
                confidence: .high,
                payload: ProvenanceEventPayload(codingAgentThread: thread)
            ),
            ProvenanceEvent(
                id: "event-\(turn.id)",
                eventType: .codingAgentTurnObserved,
                timestamp: turn.updatedAt,
                sessionID: session.id,
                source: .observed,
                confidence: .high,
                payload: ProvenanceEventPayload(codingAgentTurn: turn)
            ),
            ProvenanceEvent(
                id: "event-\(prompt.id)",
                eventType: .codingAgentPromptSubmitted,
                timestamp: prompt.submittedAt,
                sessionID: session.id,
                source: .declared,
                confidence: .high,
                payload: ProvenanceEventPayload(codingAgentPrompt: prompt)
            ),
            ProvenanceEvent(
                id: "event-\(completedCommand.id)",
                eventType: .codingAgentCommandCompleted,
                timestamp: completedCommand.completedAt,
                sessionID: session.id,
                source: .observed,
                confidence: .high,
                payload: ProvenanceEventPayload(codingAgentCommand: completedCommand)
            ),
        ]
        for event in events {
            _ = try await client.appendEvent(ProvenanceAppendEventRequest(event: event))
        }

        let health = try await client.health()
        let request = ProvenanceSessionOutcomeRequest(sessionID: session.id)
        let encodedRequest = try JSONEncoder().encode(request)
        let decodedRequest = try JSONDecoder().decode(ProvenanceSessionOutcomeRequest.self, from: encodedRequest)
        let response = try await client.sessionOutcome(decodedRequest)
        let outcome = try #require(response.outcome)
        let turnOutcome = try #require(
            try await client.turnOutcome(ProvenanceTurnOutcomeRequest(turnID: turn.id)).outcome
        )
        let encodedResponse = try JSONEncoder().encode(response)
        let decodedResponse = try JSONDecoder().decode(ProvenanceSessionOutcomeResponse.self, from: encodedResponse)
        let specific = try await client.sessionOutcome(
            ProvenanceSessionOutcomeRequest(sessionID: session.id, revisionID: outcome.projection.revisionID)
        )
        let missing = try await client.sessionOutcome(ProvenanceSessionOutcomeRequest(sessionID: "session-missing"))

        #expect(health.capabilities.contains(.querySessionOutcome))
        #expect(decodedRequest == request)
        #expect(response.found)
        #expect(response.reason == nil)
        #expect(outcome.session == session)
        #expect(outcome.providerThreadIdentities.map(\.providerThreadID) == [thread.providerThreadID])
        #expect(outcome.constituentTurns.map(\.turnID) == [turn.id])
        #expect(outcome.constituentTurns.first?.turnOutcomeRevisionID == turnOutcome.projection.revisionID)
        #expect(outcome.turnOutcomes == [turnOutcome])
        #expect(outcome.objectives.map(\.text) == [prompt.text])
        #expect(outcome.commandsCompleted.map(\.command.command) == [completedCommand.command])
        #expect(outcome.validationsAttempted.map(\.validation.resultStatus) == ["passed"])
        #expect(decodedResponse == response)
        #expect(specific.outcome == outcome)
        #expect(missing == ProvenanceSessionOutcomeResponse(
            found: false,
            reason: "no_session",
            sessionID: "session-missing",
            outcome: nil
        ))
    }

    private static func temporaryDatabaseURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("provenance-engine-session-work-model-sdk-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("provenance.sqlite")
    }

    private static func removeTemporaryDatabaseDirectory(for url: URL) {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }
}
