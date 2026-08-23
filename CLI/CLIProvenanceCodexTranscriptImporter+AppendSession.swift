import Foundation
import ProvenanceEngineContracts

extension CLIProvenanceCodexTranscriptImporter {
    func appendThread(
        metadata: TranscriptMetadata,
        line: TranscriptLine,
        fileReport: inout FileReport
    ) async throws {
        let observedAt = line.timestamp ?? metadata.timestamp
        let gitContext = await gitContext(for: metadata.cwd, observedAt: observedAt)
        let session = ProvenanceSessionRecord(
            id: metadata.sessionID,
            agentKind: "codex",
            worktreeID: gitContext?.worktreeID,
            cwd: metadata.cwd,
            status: "active",
            startedAt: metadata.timestamp,
            updatedAt: observedAt
        )
        let thread = ProvenanceCodingAgentThreadRecord(
            id: threadRecordID(providerThreadID: metadata.providerThreadID),
            sessionID: metadata.sessionID,
            provider: "codex",
            providerThreadID: metadata.providerThreadID,
            worktreeID: gitContext?.worktreeID,
            source: .observed,
            confidence: .high,
            firstObservedAt: observedAt,
            updatedAt: observedAt
        )
        let identities = [
            externalIdentity(
                sessionID: metadata.sessionID,
                kind: "provider_session",
                externalID: metadata.providerThreadID,
                observedAt: observedAt
            ),
            externalIdentity(
                sessionID: metadata.sessionID,
                kind: "thread",
                externalID: metadata.providerThreadID,
                observedAt: observedAt
            )
        ]
        let event = provenanceEvent(
            id: eventID(sessionID: metadata.sessionID, line: line, kind: "thread"),
            eventType: .codingAgentThreadObserved,
            timestamp: observedAt,
            sessionID: metadata.sessionID,
            gitContext: gitContext,
            confidence: .high,
            payload: ProvenanceEventPayload(
                repository: gitContext?.repository,
                worktree: gitContext?.worktree,
                session: session,
                externalIdentities: identities,
                codingAgentThread: thread
            )
        )
        try await append(event, stat: \.threads, fileReport: &fileReport)
    }

    func ensureTurnObserved(
        metadata: TranscriptMetadata,
        line: TranscriptLine,
        context: inout TranscriptContext,
        providerTurnID: String,
        fileReport: inout FileReport
    ) async throws {
        guard !context.observedProviderTurnIDs.contains(providerTurnID) else { return }
        try await appendTurn(
            metadata: metadata,
            line: line,
            providerTurnID: providerTurnID,
            status: "observed",
            model: context.latestModel,
            startedAt: nil,
            completedAt: nil,
            fileReport: &fileReport
        )
        context.observedProviderTurnIDs.insert(providerTurnID)
    }

    func appendTurn(
        metadata: TranscriptMetadata,
        line: TranscriptLine,
        providerTurnID: String,
        status: String,
        model: String?,
        startedAt: Date?,
        completedAt: Date?,
        fileReport: inout FileReport
    ) async throws {
        let observedAt = completedAt ?? startedAt ?? line.timestamp ?? metadata.timestamp
        let gitContext = await gitContext(for: metadata.cwd, observedAt: observedAt)
        let identity = externalIdentity(
            sessionID: metadata.sessionID,
            kind: "turn",
            externalID: providerTurnID,
            observedAt: observedAt
        )
        let turn = ProvenanceCodingAgentTurnRecord(
            id: turnRecordID(providerTurnID: providerTurnID),
            sessionID: metadata.sessionID,
            threadID: threadRecordID(providerThreadID: metadata.providerThreadID),
            provider: "codex",
            providerTurnID: providerTurnID,
            status: status,
            model: Self.trimmedNonEmpty(model),
            effort: nil,
            startedAt: startedAt,
            completedAt: completedAt,
            updatedAt: observedAt,
            source: .observed,
            confidence: .high
        )
        let event = provenanceEvent(
            id: eventID(sessionID: metadata.sessionID, line: line, kind: "turn-\(providerTurnID)-\(status)"),
            eventType: .codingAgentTurnObserved,
            timestamp: observedAt,
            sessionID: metadata.sessionID,
            gitContext: gitContext,
            confidence: .high,
            payload: ProvenanceEventPayload(
                repository: gitContext?.repository,
                worktree: gitContext?.worktree,
                externalIdentities: [identity],
                codingAgentTurn: turn
            )
        )
        try await append(event, stat: \.turns, fileReport: &fileReport)
    }

    func appendPrompt(
        metadata: TranscriptMetadata,
        line: TranscriptLine,
        text: String,
        providerTurnID: String?,
        fileReport: inout FileReport
    ) async throws {
        guard let text = Self.trimmedNonEmpty(text).map({ Self.bounded($0, limit: Self.textLimit) }) else { return }
        let observedAt = line.timestamp ?? metadata.timestamp
        let gitContext = await gitContext(for: metadata.cwd, observedAt: observedAt)
        let promptID = providerTurnID.map {
            stableIDFactory.id(
                prefix: "coding-agent-prompt",
                value: "codex\n\(metadata.sessionID)\n\($0)\n\(text)"
            )
        } ?? recordID(
            prefix: "coding-agent-prompt",
            sessionID: metadata.sessionID,
            line: line,
            discriminator: text
        )
        let prompt = ProvenanceCodingAgentPromptRecord(
            id: promptID,
            sessionID: metadata.sessionID,
            threadID: threadRecordID(providerThreadID: metadata.providerThreadID),
            turnID: providerTurnID.map(turnRecordID(providerTurnID:)),
            provider: "codex",
            text: text,
            submittedAt: observedAt,
            source: .observed,
            confidence: .high
        )
        let event = provenanceEvent(
            id: eventID(sessionID: metadata.sessionID, line: line, kind: "prompt"),
            eventType: .codingAgentPromptSubmitted,
            timestamp: observedAt,
            sessionID: metadata.sessionID,
            gitContext: gitContext,
            confidence: .high,
            payload: ProvenanceEventPayload(
                repository: gitContext?.repository,
                worktree: gitContext?.worktree,
                codingAgentPrompt: prompt
            )
        )
        try await append(event, stat: \.prompts, fileReport: &fileReport)
    }

    func appendPlan(
        metadata: TranscriptMetadata,
        line: TranscriptLine,
        plan: PlanUpdate,
        providerTurnID: String?,
        fileReport: inout FileReport
    ) async throws {
        let observedAt = line.timestamp ?? metadata.timestamp
        let steps = plan.steps.enumerated().map { index, step in
            ProvenanceCodingAgentPlanStepRecord(
                id: recordID(
                    prefix: "coding-agent-plan-step",
                    sessionID: metadata.sessionID,
                    line: line,
                    discriminator: "\(index)\n\(step.text)\n\(step.status)"
                ),
                order: index,
                text: Self.bounded(step.text, limit: Self.summaryLimit),
                status: Self.bounded(step.status, limit: 160)
            )
        }
        let update = ProvenanceCodingAgentPlanUpdateRecord(
            id: recordID(prefix: "coding-agent-plan", sessionID: metadata.sessionID, line: line),
            sessionID: metadata.sessionID,
            threadID: threadRecordID(providerThreadID: metadata.providerThreadID),
            turnID: providerTurnID.map(turnRecordID(providerTurnID:)),
            provider: "codex",
            explanation: plan.explanation.map { Self.bounded($0, limit: Self.summaryLimit) },
            steps: steps,
            observedAt: observedAt,
            source: .observed,
            confidence: .high
        )
        let gitContext = await gitContext(for: metadata.cwd, observedAt: observedAt)
        let event = provenanceEvent(
            id: eventID(sessionID: metadata.sessionID, line: line, kind: "plan"),
            eventType: .codingAgentPlanUpdated,
            timestamp: observedAt,
            sessionID: metadata.sessionID,
            gitContext: gitContext,
            confidence: .high,
            payload: ProvenanceEventPayload(
                repository: gitContext?.repository,
                worktree: gitContext?.worktree,
                codingAgentPlanUpdate: update
            )
        )
        try await append(event, stat: \.plans, fileReport: &fileReport)
    }
}
