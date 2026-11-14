import Foundation
import ProvenanceEngineContracts
import ProvenanceEngineSDK
import Testing

/// Experimental expected-red safety contract. Current v1 reads do not distinguish
/// historical semantic artifacts from supported present activity or phase.
@Suite
struct ActivityValidityProposedContractTests {
    @Test
    func completedCommandDoesNotBecomeCurrentActivityOrPhaseAcrossSecondClient() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let url = directory.appendingPathComponent("provenance.sqlite")
        defer { try? FileManager.default.removeItem(at: directory) }
        let client = try ProvenanceEngineClientFactory().sqliteClient(databaseURL: url)
        let time = Date(timeIntervalSince1970: 1_800_000_000)
        let repository = ProvenanceRepositoryRecord(id: "repo", path: "/synthetic/repo", remoteSlug: "sample/repo", createdAt: time, updatedAt: time)
        let worktree = ProvenanceWorktreeRecord(id: "worktree", repositoryID: repository.id, path: repository.path, branch: "main", currentHEAD: "synthetic-head", isDirty: false, status: "active", updatedAt: time)
        let subject = ProvenanceSessionRecord(id: "subject", agentKind: "codex", worktreeID: worktree.id, status: "active", startedAt: time, updatedAt: time)
        let target = ProvenanceSessionRecord(id: "target", agentKind: "codex", worktreeID: worktree.id, status: "active", startedAt: time, updatedAt: time)
        let thread = ProvenanceCodingAgentThreadRecord(id: "thread", sessionID: subject.id, provider: "codex", providerThreadID: "provider-thread", worktreeID: worktree.id, source: .observed, confidence: .high, firstObservedAt: time, updatedAt: time)
        let firstTurn = ProvenanceCodingAgentTurnRecord(id: "turn-1", sessionID: subject.id, threadID: thread.id, provider: "codex", providerTurnID: "provider-turn-1", status: "completed", startedAt: time, completedAt: time.addingTimeInterval(3), updatedAt: time.addingTimeInterval(3), source: .observed, confidence: .high)
        let command = ProvenanceCodingAgentCommandRecord(id: "command-1", sessionID: subject.id, threadID: thread.id, turnID: firstTurn.id, provider: "codex", command: "swift test", status: "succeeded", exitCode: 0, completedAt: time.addingTimeInterval(2), source: .observed, confidence: .high)
        let secondTurn = ProvenanceCodingAgentTurnRecord(id: "turn-2", sessionID: subject.id, threadID: thread.id, provider: "codex", providerTurnID: "provider-turn-2", status: "started", startedAt: time.addingTimeInterval(10), updatedAt: time.addingTimeInterval(10), source: .observed, confidence: .high)
        let controlTurn = ProvenanceCodingAgentTurnRecord(id: "control-turn", sessionID: target.id, provider: "codex", providerTurnID: "provider-control-turn", status: "started", startedAt: time, updatedAt: time, source: .observed, confidence: .high)
        let controlPrompt = ProvenanceCodingAgentPromptRecord(id: "control-prompt", sessionID: target.id, turnID: controlTurn.id, provider: "codex", text: "Inspect the independent workspace", submittedAt: time, source: .declared, confidence: .high)
        let events = [
            ProvenanceEvent(id: "worktree-event", eventType: .worktreeObserved, timestamp: time, repositoryID: repository.id, worktreeID: worktree.id, source: .observed, confidence: .high, payload: ProvenanceEventPayload(repository: repository, worktree: worktree)),
            ProvenanceEvent(id: "subject-event", eventType: .sessionObserved, timestamp: time, worktreeID: worktree.id, sessionID: subject.id, source: .observed, confidence: .high, payload: ProvenanceEventPayload(session: subject)),
            ProvenanceEvent(id: "target-event", eventType: .sessionObserved, timestamp: time, worktreeID: worktree.id, sessionID: target.id, source: .observed, confidence: .high, payload: ProvenanceEventPayload(session: target)),
            ProvenanceEvent(id: "control-turn-event", eventType: .codingAgentTurnObserved, timestamp: time, sessionID: target.id, source: .observed, confidence: .high, payload: ProvenanceEventPayload(codingAgentTurn: controlTurn)),
            ProvenanceEvent(id: "control-prompt-event", eventType: .codingAgentPromptSubmitted, timestamp: time, sessionID: target.id, source: .declared, confidence: .high, payload: ProvenanceEventPayload(codingAgentPrompt: controlPrompt)),
            ProvenanceEvent(id: "thread-event", eventType: .codingAgentThreadObserved, timestamp: time, sessionID: subject.id, source: .observed, confidence: .high, payload: ProvenanceEventPayload(codingAgentThread: thread)),
            ProvenanceEvent(id: "turn-1-event", eventType: .codingAgentTurnObserved, timestamp: firstTurn.updatedAt, sessionID: subject.id, source: .observed, confidence: .high, payload: ProvenanceEventPayload(codingAgentTurn: firstTurn)),
            ProvenanceEvent(id: "command-event", eventType: .codingAgentCommandCompleted, timestamp: command.completedAt, sessionID: subject.id, source: .observed, confidence: .high, payload: ProvenanceEventPayload(codingAgentCommand: command)),
        ]
        for event in events { _ = try await client.appendEvent(ProvenanceAppendEventRequest(event: event)) }
        let publish = try await client.publishCodingAgentSessionSemanticInferences(
            ProvenanceCodingAgentSessionSemanticInferenceRequest(sessionID: subject.id, createdAt: time.addingTimeInterval(5))
        )
        let activity = try #require(publish.records.first { $0.kind == ProvenanceCodingAgentSemanticInferenceKind.currentActivity.rawValue })
        let phase = try #require(publish.records.first { $0.kind == ProvenanceCodingAgentSemanticInferenceKind.sessionPhase.rawValue })
        #expect(activity.supportingEvidenceRefs.contains { $0.kind == "coding_agent_command" && $0.id == command.id })
        #expect(phase.scope == .session && phase.scopeID == subject.id)
        #expect(phase.supportingEvidenceRefs.contains { $0.kind == "coding_agent_turn" && $0.id == firstTurn.id })
        #expect(phase.supportingEvidenceRefs.contains { $0.kind == "coding_agent_command" && $0.id == command.id })
        _ = try await client.materializeSemanticMessages(ProvenanceSemanticMessageMaterializationRequest(semanticInferenceRecords: [activity, phase], createdAt: time.addingTimeInterval(6)))

        let completedModel = try #require(try await client.sessionWorkModel(ProvenanceSessionWorkModelRequest(sessionID: subject.id)).model)
        // Proposed: a completed operation alone cannot establish present activity or phase.
        #expect(completedModel.currentTurn?.currentActivity.state == .unknown)
        #expect(completedModel.sessionPhase.state == .unknown)

        _ = try await client.appendEvent(ProvenanceAppendEventRequest(event: ProvenanceEvent(id: "turn-2-event", eventType: .codingAgentTurnObserved, timestamp: secondTurn.updatedAt, sessionID: subject.id, source: .observed, confidence: .high, payload: ProvenanceEventPayload(codingAgentTurn: secondTurn))))
        // A second client opens the same database while the original remains alive;
        // this does not simulate a process restart or close/reconnect.
        let secondClient = try ProvenanceEngineClientFactory().sqliteClient(databaseURL: url)
        let laterModel = try #require(try await secondClient.sessionWorkModel(ProvenanceSessionWorkModelRequest(sessionID: subject.id)).model)
        let oldDetail = try #require(try await secondClient.factualSessionTurnDetail(ProvenanceFactualSessionTurnDetailRequest(turnID: firstTurn.id)).turnDetail)
        #expect(oldDetail.completedCommands.map(\.id) == [command.id])
        let controlDetail = try #require(try await secondClient.factualSessionTurnDetail(ProvenanceFactualSessionTurnDetailRequest(turnID: controlTurn.id)).turnDetail)
        #expect(controlDetail.turn.sessionID == target.id)
        #expect(controlDetail.submittedPrompt?.id == controlPrompt.id)
        #expect(controlDetail.submittedPrompt?.text == controlPrompt.text)
        #expect(laterModel.currentTurn?.turn.id == secondTurn.id)
        #expect(laterModel.currentTurn?.currentActivity.state == .unknown)
        // Proposed: prior-turn phase cannot remain an unqualified current phase.
        #expect(laterModel.sessionPhase.state == .unknown)
        let related = try #require(try await secondClient.relatedSessions(ProvenanceRelatedSessionRequest(targetSessionID: target.id)).projection?.relatedSessions.first { $0.sessionID == subject.id })
        let relatedPhase = try #require(related.semanticFields.first { $0.kind == ProvenanceCodingAgentSemanticInferenceKind.sessionPhase.rawValue })
        #expect(relatedPhase.state == .unknown)
        let activeMessages = try await secondClient.semanticMessages(ProvenanceSemanticMessageQueryRequest(scope: .turn, scopeID: firstTurn.id, semanticInferenceKind: ProvenanceCodingAgentSemanticInferenceKind.currentActivity.rawValue))
        let historicalMessages = try await secondClient.semanticMessages(ProvenanceSemanticMessageQueryRequest(scope: .turn, scopeID: firstTurn.id, semanticInferenceKind: ProvenanceCodingAgentSemanticInferenceKind.currentActivity.rawValue, includeInactive: true))
        // This explicitly queries the old turn: active means artifact lifecycle,
        // not proof that the turn is current. Keep the historical reference.
        // Baseline characterization, not a requirement to retain active status:
        // a future safe implementation may reclassify the old artifact as historical.
        #expect(!activeMessages.records.isEmpty)
        #expect(activeMessages.records.allSatisfy { $0.scopeID == firstTurn.id })
        #expect(historicalMessages.records.contains { $0.semanticInferenceID == activity.id })
        let currentPhaseMessages = try await secondClient.semanticMessages(ProvenanceSemanticMessageQueryRequest(scope: .session, scopeID: subject.id, semanticInferenceKind: ProvenanceCodingAgentSemanticInferenceKind.sessionPhase.rawValue))
        let phaseHistory = try await secondClient.semanticMessages(ProvenanceSemanticMessageQueryRequest(scope: .session, scopeID: subject.id, semanticInferenceKind: ProvenanceCodingAgentSemanticInferenceKind.sessionPhase.rawValue, includeInactive: true))
        // Proposed policy: default session-phase reads omit this stale claim;
        // a future explicit validity field could express the same safety differently.
        #expect(currentPhaseMessages.records.isEmpty)
        #expect(phaseHistory.records.contains { $0.semanticInferenceID == phase.id })
    }
}
