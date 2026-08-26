import BmuxAgentChat
import Foundation
import ProvenanceEngineContracts

extension WorkProvenanceCodingAgentEvidenceRecorder {
    func recordThread(
        summary: AgentChatSessionSummary,
        envelope: ExecutionTelemetryEventEnvelope,
        providerThreadID: String
    ) async throws {
        let observedAt = timestamp(milliseconds: envelope.capturedAtMs)
        let threadID = threadRecordID(providerThreadID: providerThreadID)
        providerThreadIDBySessionID[summary.id] = providerThreadID
        let gitContext = await gitContext(for: summary.cwd, observedAt: observedAt)
        let session = sessionRecord(summary: summary, worktreeID: gitContext?.worktreeID, updatedAt: observedAt)
        let thread = ProvenanceCodingAgentThreadRecord(
            id: threadID,
            sessionID: summary.id,
            provider: "codex",
            providerThreadID: providerThreadID,
            worktreeID: gitContext?.worktreeID,
            source: .observed,
            confidence: .high,
            firstObservedAt: observedAt,
            updatedAt: observedAt
        )
        let identity = externalIdentity(
            id: identityRecordID(sessionID: summary.id, kind: "thread", externalID: providerThreadID),
            sessionID: summary.id,
            kind: "thread",
            externalID: providerThreadID,
            observedAt: observedAt
        )
        try await append(
            eventType: .codingAgentThreadObserved,
            envelope: envelope,
            timestamp: observedAt,
            sessionID: summary.id,
            repositoryID: gitContext?.repositoryID,
            worktreeID: gitContext?.worktreeID,
            confidence: .high,
            payload: ProvenanceEventPayload(
                repository: gitContext?.repository,
                worktree: gitContext?.worktree,
                session: session,
                externalIdentities: [identity],
                codingAgentThread: thread
            )
        )
    }

    func recordPromptOrDefer(
        summary: AgentChatSessionSummary,
        envelope: ExecutionTelemetryEventEnvelope,
        text: String
    ) async throws {
        guard let promptText = trimmedNonEmpty(text).map({ bounded($0, limit: Self.textLimit) }) else { return }
        let providerTurnID = effectiveProviderTurnID(summary: summary, envelope: envelope)
        guard let providerTurnID else {
            pendingPromptBySessionID[summary.id] = PendingPrompt(envelope: envelope, text: promptText)
            return
        }
        try await recordPrompt(summary: summary, envelope: envelope, text: promptText, providerTurnID: providerTurnID)
    }

    func recordPrompt(
        summary: AgentChatSessionSummary,
        envelope: ExecutionTelemetryEventEnvelope,
        text: String,
        providerTurnID: String
    ) async throws {
        let observedAt = timestamp(milliseconds: envelope.capturedAtMs)
        let providerThreadID = effectiveProviderThreadID(summary: summary, envelope: envelope)
        let turnID = turnRecordID(providerTurnID: providerTurnID)
        let threadID = providerThreadID.map(threadRecordID(providerThreadID:))
        let gitContext = await gitContext(for: summary.cwd, observedAt: observedAt)
        let prompt = ProvenanceCodingAgentPromptRecord(
            id: "coding-agent-prompt-\(envelope.eventID)",
            sessionID: summary.id,
            threadID: threadID,
            turnID: turnID,
            provider: "codex",
            text: text,
            submittedAt: observedAt,
            source: .observed,
            confidence: .high
        )
        try await append(
            eventType: .codingAgentPromptSubmitted,
            envelope: envelope,
            timestamp: observedAt,
            sessionID: summary.id,
            repositoryID: gitContext?.repositoryID,
            worktreeID: gitContext?.worktreeID,
            confidence: .high,
            payload: ProvenanceEventPayload(
                repository: gitContext?.repository,
                worktree: gitContext?.worktree,
                codingAgentPrompt: prompt
            )
        )
    }

    func recordTurnStarted(
        summary: AgentChatSessionSummary,
        envelope: ExecutionTelemetryEventEnvelope,
        event: ExecutionTelemetryTurnStartedEvent
    ) async throws {
        guard let providerTurnID = firstNonEmpty(event.turnID, envelope.providerTurnID, envelope.providerEvent?.turnID) else {
            return
        }
        currentProviderTurnIDBySessionID[summary.id] = providerTurnID
        let observedAt = timestamp(milliseconds: envelope.capturedAtMs)
        let providerThreadID = effectiveProviderThreadID(summary: summary, envelope: envelope)
        if let providerThreadID {
            providerThreadIDBySessionID[summary.id] = providerThreadID
        }
        let turn = codingAgentTurn(
            summary: summary,
            providerThreadID: providerThreadID,
            providerTurnID: providerTurnID,
            status: "started",
            model: trimmedNonEmpty(event.model),
            effort: trimmedNonEmpty(event.effort),
            startedAt: observedAt,
            completedAt: nil,
            updatedAt: observedAt
        )
        let gitContext = await gitContext(for: summary.cwd, observedAt: observedAt)
        let identity = externalIdentity(
            id: identityRecordID(sessionID: summary.id, kind: "turn", externalID: providerTurnID),
            sessionID: summary.id,
            kind: "turn",
            externalID: providerTurnID,
            observedAt: observedAt
        )
        try await append(
            eventType: .codingAgentTurnObserved,
            envelope: envelope,
            timestamp: observedAt,
            sessionID: summary.id,
            repositoryID: gitContext?.repositoryID,
            worktreeID: gitContext?.worktreeID,
            confidence: .high,
            payload: ProvenanceEventPayload(
                repository: gitContext?.repository,
                worktree: gitContext?.worktree,
                externalIdentities: [identity],
                codingAgentTurn: turn
            )
        )
        if let pendingPrompt = pendingPromptBySessionID.removeValue(forKey: summary.id) {
            try await recordPrompt(
                summary: summary,
                envelope: pendingPrompt.envelope,
                text: pendingPrompt.text,
                providerTurnID: providerTurnID
            )
        }
    }

    func recordTurnFinished(
        summary: AgentChatSessionSummary,
        envelope: ExecutionTelemetryEventEnvelope,
        event: ExecutionTelemetryTurnCompletedEvent,
        status: String
    ) async throws {
        guard let providerTurnID = firstNonEmpty(event.turnID, envelope.providerTurnID, envelope.providerEvent?.turnID)
            ?? currentProviderTurnIDBySessionID[summary.id] else {
            return
        }
        try await recordTurnFinished(
            summary: summary,
            envelope: envelope,
            providerTurnID: providerTurnID,
            status: status
        )
    }

    func recordTurnFinished(
        summary: AgentChatSessionSummary,
        envelope: ExecutionTelemetryEventEnvelope,
        event: ExecutionTelemetryTurnFailedEvent,
        status: String
    ) async throws {
        guard let providerTurnID = firstNonEmpty(event.turnID, envelope.providerTurnID, envelope.providerEvent?.turnID)
            ?? currentProviderTurnIDBySessionID[summary.id] else {
            return
        }
        try await recordTurnFinished(
            summary: summary,
            envelope: envelope,
            providerTurnID: providerTurnID,
            status: status
        )
    }

    func recordTurnFinished(
        summary: AgentChatSessionSummary,
        envelope: ExecutionTelemetryEventEnvelope,
        providerTurnID: String,
        status: String
    ) async throws {
        let observedAt = timestamp(milliseconds: envelope.capturedAtMs)
        let providerThreadID = effectiveProviderThreadID(summary: summary, envelope: envelope)
        let turn = codingAgentTurn(
            summary: summary,
            providerThreadID: providerThreadID,
            providerTurnID: providerTurnID,
            status: status,
            model: nil,
            effort: nil,
            startedAt: nil,
            completedAt: observedAt,
            updatedAt: observedAt
        )
        let gitContext = await gitContext(for: summary.cwd, observedAt: observedAt)
        try await append(
            eventType: .codingAgentTurnObserved,
            envelope: envelope,
            timestamp: observedAt,
            sessionID: summary.id,
            repositoryID: gitContext?.repositoryID,
            worktreeID: gitContext?.worktreeID,
            confidence: .high,
            payload: ProvenanceEventPayload(
                repository: gitContext?.repository,
                worktree: gitContext?.worktree,
                codingAgentTurn: turn
            )
        )
    }

    func recordPlanUpdate(
        summary: AgentChatSessionSummary,
        envelope: ExecutionTelemetryEventEnvelope,
        event: ExecutionTelemetryPlanUpdatedEvent
    ) async throws {
        guard !event.steps.isEmpty else { return }
        let observedAt = timestamp(milliseconds: envelope.capturedAtMs)
        let providerThreadID = effectiveProviderThreadID(summary: summary, envelope: envelope)
        let providerTurnID = effectiveProviderTurnID(summary: summary, envelope: envelope)
        let steps = event.steps.enumerated().map { index, step in
            ProvenanceCodingAgentPlanStepRecord(
                id: "coding-agent-plan-step-\(envelope.eventID)-\(index)",
                order: index,
                text: bounded(step.text, limit: Self.summaryLimit),
                status: bounded(step.status, limit: 160)
            )
        }
        let update = ProvenanceCodingAgentPlanUpdateRecord(
            id: "coding-agent-plan-\(envelope.eventID)",
            sessionID: summary.id,
            threadID: providerThreadID.map(threadRecordID(providerThreadID:)),
            turnID: providerTurnID.map(turnRecordID(providerTurnID:)),
            provider: "codex",
            explanation: trimmedNonEmpty(event.explanation).map { bounded($0, limit: Self.summaryLimit) },
            steps: steps,
            observedAt: observedAt,
            source: .observed,
            confidence: .high
        )
        let gitContext = await gitContext(for: summary.cwd, observedAt: observedAt)
        try await append(
            eventType: .codingAgentPlanUpdated,
            envelope: envelope,
            timestamp: observedAt,
            sessionID: summary.id,
            repositoryID: gitContext?.repositoryID,
            worktreeID: gitContext?.worktreeID,
            confidence: .high,
            payload: ProvenanceEventPayload(
                repository: gitContext?.repository,
                worktree: gitContext?.worktree,
                codingAgentPlanUpdate: update
            )
        )
    }

    func recordReasoningSummary(
        summary: AgentChatSessionSummary,
        envelope: ExecutionTelemetryEventEnvelope,
        event: ExecutionTelemetryMessageCompletedEvent
    ) async throws {
        guard event.stream == "reasoning",
              let text = trimmedNonEmpty(event.text).map({ bounded($0, limit: Self.summaryLimit) }) else {
            return
        }
        let observedAt = timestamp(milliseconds: envelope.capturedAtMs)
        let providerThreadID = effectiveProviderThreadID(summary: summary, envelope: envelope)
        let providerTurnID = effectiveProviderTurnID(summary: summary, envelope: envelope)
        let summaryRecord = ProvenanceCodingAgentReasoningSummaryRecord(
            id: "coding-agent-reasoning-summary-\(envelope.eventID)",
            sessionID: summary.id,
            threadID: providerThreadID.map(threadRecordID(providerThreadID:)),
            turnID: providerTurnID.map(turnRecordID(providerTurnID:)),
            provider: "codex",
            itemID: trimmedNonEmpty(event.itemID),
            text: text,
            completedAt: observedAt,
            source: .observed,
            confidence: .high
        )
        let gitContext = await gitContext(for: summary.cwd, observedAt: observedAt)
        try await append(
            eventType: .codingAgentReasoningSummaryCompleted,
            envelope: envelope,
            timestamp: observedAt,
            sessionID: summary.id,
            repositoryID: gitContext?.repositoryID,
            worktreeID: gitContext?.worktreeID,
            confidence: .high,
            payload: ProvenanceEventPayload(
                repository: gitContext?.repository,
                worktree: gitContext?.worktree,
                codingAgentReasoningSummary: summaryRecord
            )
        )
    }

    func recordCompletedMessage(
        summary: AgentChatSessionSummary,
        envelope: ExecutionTelemetryEventEnvelope,
        event: ExecutionTelemetryMessageCompletedEvent
    ) async throws {
        switch normalizedMessageStream(event.stream) {
        case "reasoning":
            try await recordReasoningSummary(summary: summary, envelope: envelope, event: event)
        case "assistant":
            try await recordAssistantMessage(summary: summary, envelope: envelope, event: event)
        default:
            return
        }
    }

    func recordAssistantMessage(
        summary: AgentChatSessionSummary,
        envelope: ExecutionTelemetryEventEnvelope,
        event: ExecutionTelemetryMessageCompletedEvent
    ) async throws {
        guard normalizedMessageStream(event.stream) == "assistant",
              let text = trimmedNonEmpty(event.text).map({ bounded($0, limit: Self.textLimit) }) else {
            return
        }
        let observedAt = timestamp(milliseconds: envelope.capturedAtMs)
        let providerThreadID = effectiveProviderThreadID(summary: summary, envelope: envelope)
        let providerTurnID = effectiveProviderTurnID(summary: summary, envelope: envelope)
        let message = ProvenanceCodingAgentAssistantMessageRecord(
            id: "coding-agent-assistant-message-\(envelope.eventID)",
            sessionID: summary.id,
            threadID: providerThreadID.map(threadRecordID(providerThreadID:)),
            turnID: providerTurnID.map(turnRecordID(providerTurnID:)),
            provider: "codex",
            itemID: trimmedNonEmpty(event.itemID),
            text: text,
            completedAt: observedAt,
            source: .observed,
            confidence: .high
        )
        let gitContext = await gitContext(for: summary.cwd, observedAt: observedAt)
        try await append(
            eventType: .codingAgentAssistantMessageCompleted,
            envelope: envelope,
            timestamp: observedAt,
            sessionID: summary.id,
            repositoryID: gitContext?.repositoryID,
            worktreeID: gitContext?.worktreeID,
            confidence: .high,
            payload: ProvenanceEventPayload(
                repository: gitContext?.repository,
                worktree: gitContext?.worktree,
                codingAgentAssistantMessage: message
            )
        )
    }

    func recordPendingTool(
        summary: AgentChatSessionSummary,
        envelope: ExecutionTelemetryEventEnvelope,
        event: ExecutionTelemetryToolStartedEvent
    ) {
        guard let operationID = trimmedNonEmpty(event.operationID) else { return }
        pendingToolByKey[toolKey(sessionID: summary.id, operationID: operationID)] = PendingTool(
            operationID: operationID,
            toolKind: event.toolKind,
            name: event.name,
            inputSummary: trimmedNonEmpty(event.inputSummary),
            cwd: trimmedNonEmpty(event.cwd),
            startedAt: event.startedAtMs.map(timestamp(milliseconds:)) ?? timestamp(milliseconds: envelope.capturedAtMs)
        )
    }

    func recordCompletedTool(
        summary: AgentChatSessionSummary,
        envelope: ExecutionTelemetryEventEnvelope,
        event: ExecutionTelemetryToolCompletedEvent
    ) async throws {
        guard let operationID = trimmedNonEmpty(event.operationID) else { return }
        let key = toolKey(sessionID: summary.id, operationID: operationID)
        let pending = pendingToolByKey.removeValue(forKey: key)
        let toolKind = trimmedNonEmpty(event.toolKind) ?? pending?.toolKind
        guard toolKind == "command" else { return }
        let observedAt = event.completedAtMs.map(timestamp(milliseconds:)) ?? timestamp(milliseconds: envelope.capturedAtMs)
        let toolText = firstNonEmpty(pending?.inputSummary, event.name, pending?.name, operationID) ?? operationID
        let providerThreadID = effectiveProviderThreadID(summary: summary, envelope: envelope)
        let providerTurnID = effectiveProviderTurnID(summary: summary, envelope: envelope)
        let cwd = firstNonEmpty(pending?.cwd, summary.cwd)
        let commandRecord = ProvenanceCodingAgentCommandRecord(
            id: "coding-agent-command-\(envelope.eventID)",
            sessionID: summary.id,
            threadID: providerThreadID.map(threadRecordID(providerThreadID:)),
            turnID: providerTurnID.map(turnRecordID(providerTurnID:)),
            provider: "codex",
            operationID: operationID,
            toolText: bounded(toolText, limit: Self.textLimit),
            cwd: cwd,
            status: event.status,
            exitCode: event.exitCode,
            outputSummary: nil,
            startedAt: pending?.startedAt,
            completedAt: observedAt,
            source: .observed,
            confidence: .high
        )
        let gitContext = await gitContext(for: cwd ?? summary.cwd, observedAt: observedAt)
        try await append(
            eventType: .codingAgentCommandCompleted,
            envelope: envelope,
            timestamp: observedAt,
            sessionID: summary.id,
            repositoryID: gitContext?.repositoryID,
            worktreeID: gitContext?.worktreeID,
            confidence: .high,
            payload: ProvenanceEventPayload(
                repository: gitContext?.repository,
                worktree: gitContext?.worktree,
                codingAgentCommand: commandRecord
            )
        )
    }

    func recordFilesChanged(
        summary: AgentChatSessionSummary,
        envelope: ExecutionTelemetryEventEnvelope,
        event: ExecutionTelemetryFilesChangedEvent
    ) async throws {
        let files = event.files.compactMap { file -> ExecutionTelemetryChangedFile? in
            guard trimmedNonEmpty(file.path) != nil else { return nil }
            return file
        }
        guard !files.isEmpty else { return }
        let observedAt = timestamp(milliseconds: envelope.capturedAtMs)
        let providerThreadID = effectiveProviderThreadID(summary: summary, envelope: envelope)
        let providerTurnID = effectiveProviderTurnID(summary: summary, envelope: envelope)
        let gitContext = await gitContext(for: summary.cwd, observedAt: observedAt)
        let diffFingerprint = "coding-agent-files-\(envelope.eventID)"
        let changeSetID = gitContext.map {
            stableIDFactory.changeSetID(worktreeID: $0.worktreeID, fingerprint: diffFingerprint)
        }
        let fileChangeRecords: [ProvenanceFileChangeRecord]
        if let gitContext, let changeSetID {
            fileChangeRecords = files.map { file in
                ProvenanceFileChangeRecord(
                    id: stableIDFactory.fileChangeID(worktreeID: gitContext.worktreeID, path: file.path),
                    changeSetID: changeSetID,
                    repositoryID: gitContext.repositoryID,
                    worktreeID: gitContext.worktreeID,
                    path: file.path,
                    status: file.status,
                    attributionSource: .observed,
                    attributionConfidence: .medium,
                    updatedAt: observedAt
                )
            }
        } else {
            fileChangeRecords = []
        }
        let summaryText = files.compactMap { file in
            trimmedNonEmpty(file.summary)
        }.joined(separator: "\n")
        let attribution = ProvenanceCodingAgentFileChangeAttributionRecord(
            id: "coding-agent-file-change-\(envelope.eventID)",
            sessionID: summary.id,
            threadID: providerThreadID.map(threadRecordID(providerThreadID:)),
            turnID: providerTurnID.map(turnRecordID(providerTurnID:)),
            provider: "codex",
            operationID: envelope.providerEvent?.itemID,
            changeSetID: changeSetID,
            fileChangeIDs: fileChangeRecords.map(\.id),
            paths: files.map(\.path),
            summary: trimmedNonEmpty(summaryText).map { bounded($0, limit: Self.summaryLimit) },
            observedAt: observedAt,
            source: .observed,
            confidence: .medium
        )
        let changeSet = gitContext.flatMap { context -> ProvenanceChangeSetRecord? in
            guard let changeSetID else { return nil }
            return ProvenanceChangeSetRecord(
                id: changeSetID,
                worktreeID: context.worktreeID,
                summary: "Coding-agent file changes",
                diffFingerprint: diffFingerprint,
                createdAt: observedAt
            )
        }
        try await append(
            eventType: .codingAgentFileChangeAttributed,
            envelope: envelope,
            timestamp: observedAt,
            sessionID: summary.id,
            repositoryID: gitContext?.repositoryID,
            worktreeID: gitContext?.worktreeID,
            confidence: .medium,
            payload: ProvenanceEventPayload(
                repository: gitContext?.repository,
                worktree: gitContext?.worktree,
                changeSet: changeSet,
                fileChanges: fileChangeRecords,
                codingAgentFileChangeAttribution: attribution
            )
        )
    }
}
