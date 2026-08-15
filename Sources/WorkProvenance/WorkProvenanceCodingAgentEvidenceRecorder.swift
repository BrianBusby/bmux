import BmuxAgentChat
import Foundation
import ProvenanceEngineContracts

/// Records completed, structured coding-agent evidence from execution telemetry.
actor WorkProvenanceCodingAgentEvidenceRecorder {
    private static let textLimit = 12_000
    private static let summaryLimit = 4_000

    private let client: any ProvenanceEngineContracts.ProvenanceEngineClient
    private let gitInspector: any WorkProvenanceGitInspecting
    private let stableIDFactory: WorkProvenanceStableIDFactory

    private var providerThreadIDBySessionID: [String: String] = [:]
    private var currentProviderTurnIDBySessionID: [String: String] = [:]
    private var pendingPromptBySessionID: [String: PendingPrompt] = [:]
    private var pendingToolByKey: [String: PendingTool] = [:]

    /// Last persistence error, retained for diagnostics.
    private(set) var lastErrorDescription: String?

    /// Creates a recorder backed by the public Provenance Engine write API.
    init(
        client: any ProvenanceEngineContracts.ProvenanceEngineClient,
        gitInspector: any WorkProvenanceGitInspecting = WorkProvenanceGitInspector(),
        stableIDFactory: WorkProvenanceStableIDFactory = WorkProvenanceStableIDFactory()
    ) {
        self.client = client
        self.gitInspector = gitInspector
        self.stableIDFactory = stableIDFactory
    }

    /// Records one canonical sidecar telemetry envelope when it contains durable evidence.
    func record(
        summary: AgentChatSessionSummary,
        envelope: ExecutionTelemetryEventEnvelope
    ) async throws {
        guard normalizedProvider(summary.provider) == "codex",
              normalizedProvider(envelope.provider) == "codex",
              envelope.sessionID == summary.id else {
            return
        }

        switch envelope.event {
        case .sessionStarted:
            return
        case .providerSessionLinked(let event):
            try await recordThread(summary: summary, envelope: envelope, providerThreadID: event.providerSessionID)
        case .promptSubmitted(let event):
            try await recordPromptOrDefer(summary: summary, envelope: envelope, text: event.text)
        case .turnStarted(let event):
            try await recordTurnStarted(summary: summary, envelope: envelope, event: event)
        case .turnCompleted(let event):
            try await recordTurnFinished(summary: summary, envelope: envelope, event: event, status: "completed")
        case .turnFailed(let event):
            try await recordTurnFinished(summary: summary, envelope: envelope, event: event, status: "failed")
        case .planUpdated(let event):
            try await recordPlanUpdate(summary: summary, envelope: envelope, event: event)
        case .messageCompleted(let event):
            try await recordReasoningSummary(summary: summary, envelope: envelope, event: event)
        case .toolStarted(let event):
            recordPendingTool(summary: summary, envelope: envelope, event: event)
        case .toolCompleted(let event):
            try await recordCompletedTool(summary: summary, envelope: envelope, event: event)
        case .filesChanged(let event):
            try await recordFilesChanged(summary: summary, envelope: envelope, event: event)
        case .unsupported:
            return
        }
    }

    private func recordThread(
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

    private func recordPromptOrDefer(
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

    private func recordPrompt(
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
        let promptText = text
        let promptID = "coding-agent-prompt-\(envelope.eventID)"
        let prompt = ProvenanceCodingAgentPromptRecord(
            id: promptID,
            sessionID: summary.id,
            threadID: threadID,
            turnID: turnID,
            provider: "codex",
            text: promptText,
            submittedAt: observedAt,
            source: .observed,
            confidence: .high
        )
        let payload = ProvenanceEventPayload(
            repository: gitContext?.repository,
            worktree: gitContext?.worktree,
            codingAgentPrompt: prompt
        )
        try await append(
            eventType: .codingAgentPromptSubmitted,
            envelope: envelope,
            timestamp: observedAt,
            sessionID: summary.id,
            repositoryID: gitContext?.repositoryID,
            worktreeID: gitContext?.worktreeID,
            confidence: .high,
            payload: payload
        )
    }

    private func recordTurnStarted(
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
        let payload = ProvenanceEventPayload(
            repository: gitContext?.repository,
            worktree: gitContext?.worktree,
            externalIdentities: [identity],
            codingAgentTurn: turn
        )
        try await append(
            eventType: .codingAgentTurnObserved,
            envelope: envelope,
            timestamp: observedAt,
            sessionID: summary.id,
            repositoryID: gitContext?.repositoryID,
            worktreeID: gitContext?.worktreeID,
            confidence: .high,
            payload: payload
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

    private func recordTurnFinished(
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

    private func recordTurnFinished(
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

    private func recordTurnFinished(
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
        let payload = ProvenanceEventPayload(
            repository: gitContext?.repository,
            worktree: gitContext?.worktree,
            codingAgentTurn: turn
        )
        try await append(
            eventType: .codingAgentTurnObserved,
            envelope: envelope,
            timestamp: observedAt,
            sessionID: summary.id,
            repositoryID: gitContext?.repositoryID,
            worktreeID: gitContext?.worktreeID,
            confidence: .high,
            payload: payload
        )
    }

    private func recordPlanUpdate(
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
        let payload = ProvenanceEventPayload(
            repository: gitContext?.repository,
            worktree: gitContext?.worktree,
            codingAgentPlanUpdate: update
        )
        try await append(
            eventType: .codingAgentPlanUpdated,
            envelope: envelope,
            timestamp: observedAt,
            sessionID: summary.id,
            repositoryID: gitContext?.repositoryID,
            worktreeID: gitContext?.worktreeID,
            confidence: .high,
            payload: payload
        )
    }

    private func recordReasoningSummary(
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
        let payload = ProvenanceEventPayload(
            repository: gitContext?.repository,
            worktree: gitContext?.worktree,
            codingAgentReasoningSummary: summaryRecord
        )
        try await append(
            eventType: .codingAgentReasoningSummaryCompleted,
            envelope: envelope,
            timestamp: observedAt,
            sessionID: summary.id,
            repositoryID: gitContext?.repositoryID,
            worktreeID: gitContext?.worktreeID,
            confidence: .high,
            payload: payload
        )
    }

    private func recordPendingTool(
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

    private func recordCompletedTool(
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
        let payload = ProvenanceEventPayload(
            repository: gitContext?.repository,
            worktree: gitContext?.worktree,
            codingAgentCommand: commandRecord
        )
        try await append(
            eventType: .codingAgentCommandCompleted,
            envelope: envelope,
            timestamp: observedAt,
            sessionID: summary.id,
            repositoryID: gitContext?.repositoryID,
            worktreeID: gitContext?.worktreeID,
            confidence: .high,
            payload: payload
        )
    }

    private func recordFilesChanged(
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
        let payload = ProvenanceEventPayload(
            repository: gitContext?.repository,
            worktree: gitContext?.worktree,
            changeSet: changeSet,
            fileChanges: fileChangeRecords,
            codingAgentFileChangeAttribution: attribution
        )
        try await append(
            eventType: .codingAgentFileChangeAttributed,
            envelope: envelope,
            timestamp: observedAt,
            sessionID: summary.id,
            repositoryID: gitContext?.repositoryID,
            worktreeID: gitContext?.worktreeID,
            confidence: .medium,
            payload: payload
        )
    }

    private func codingAgentTurn(
        summary: AgentChatSessionSummary,
        providerThreadID: String?,
        providerTurnID: String,
        status: String,
        model: String?,
        effort: String?,
        startedAt: Date?,
        completedAt: Date?,
        updatedAt: Date
    ) -> ProvenanceCodingAgentTurnRecord {
        ProvenanceCodingAgentTurnRecord(
            id: turnRecordID(providerTurnID: providerTurnID),
            sessionID: summary.id,
            threadID: providerThreadID.map(threadRecordID(providerThreadID:)),
            provider: "codex",
            providerTurnID: providerTurnID,
            status: status,
            model: model,
            effort: effort,
            startedAt: startedAt,
            completedAt: completedAt,
            updatedAt: updatedAt,
            source: .observed,
            confidence: .high
        )
    }

    private func append(
        eventType: ProvenanceEventType,
        envelope: ExecutionTelemetryEventEnvelope,
        timestamp: Date,
        sessionID: String,
        repositoryID: String?,
        worktreeID: String?,
        confidence: ProvenanceConfidence,
        payload: ProvenanceEventPayload
    ) async throws {
        let event = ProvenanceEngineContracts.ProvenanceEvent(
            id: "event-\(envelope.eventID)",
            eventType: eventType,
            timestamp: timestamp,
            repositoryID: repositoryID,
            worktreeID: worktreeID,
            sessionID: sessionID,
            source: .observed,
            evidenceOrigin: .codexSession,
            evidenceScope: ProvenanceEvidenceScope(level: .personal, id: "bmux-local"),
            confidence: confidence,
            payload: payload
        )
        do {
            _ = try await client.appendEvent(ProvenanceEngineContracts.ProvenanceAppendEventRequest(event: event))
            lastErrorDescription = nil
        } catch {
            if Self.isDuplicateAppendError(error) {
                lastErrorDescription = nil
                return
            }
            let description = String(describing: error)
            lastErrorDescription = description
            throw error
        }
    }

    private func gitContext(for directory: String?, observedAt: Date) async -> GitContext? {
        guard let directory = trimmedNonEmpty(directory),
              let snapshot = await gitInspector.snapshot(for: directory) else {
            return nil
        }
        let repositoryID = stableIDFactory.repositoryID(repositoryRoot: snapshot.repositoryRoot)
        let worktreeID = stableIDFactory.worktreeID(repositoryRoot: snapshot.repositoryRoot)
        return GitContext(
            repositoryID: repositoryID,
            worktreeID: worktreeID,
            repository: ProvenanceRepositoryRecord(
                id: repositoryID,
                path: snapshot.repositoryRoot,
                commonDirectory: snapshot.commonDirectory,
                remoteSlug: snapshot.remoteSlug,
                createdAt: observedAt,
                updatedAt: observedAt
            ),
            worktree: ProvenanceWorktreeRecord(
                id: worktreeID,
                repositoryID: repositoryID,
                path: snapshot.repositoryRoot,
                branch: snapshot.branch,
                currentHEAD: snapshot.headCommit,
                isDirty: snapshot.isDirty,
                status: "active",
                lastReconciledAt: observedAt,
                updatedAt: observedAt
            )
        )
    }

    private func sessionRecord(
        summary: AgentChatSessionSummary,
        worktreeID: String?,
        updatedAt: Date
    ) -> ProvenanceSessionRecord {
        ProvenanceSessionRecord(
            id: summary.id,
            agentKind: "codex",
            worktreeID: worktreeID,
            cwd: trimmedNonEmpty(summary.cwd),
            status: "active",
            startedAt: Date(timeIntervalSince1970: summary.createdAt / 1_000),
            updatedAt: updatedAt
        )
    }

    private func externalIdentity(
        id: String,
        sessionID: String,
        kind: String,
        externalID: String,
        observedAt: Date
    ) -> ProvenanceExternalIdentityRecord {
        ProvenanceExternalIdentityRecord(
            id: id,
            sessionID: sessionID,
            system: "codex",
            kind: kind,
            externalID: externalID,
            source: .observed,
            confidence: .high,
            createdAt: observedAt,
            updatedAt: observedAt
        )
    }

    private func effectiveProviderThreadID(
        summary: AgentChatSessionSummary,
        envelope: ExecutionTelemetryEventEnvelope
    ) -> String? {
        firstNonEmpty(envelope.providerSessionID, providerThreadIDBySessionID[summary.id])
    }

    private func effectiveProviderTurnID(
        summary: AgentChatSessionSummary,
        envelope: ExecutionTelemetryEventEnvelope
    ) -> String? {
        firstNonEmpty(envelope.providerTurnID, envelope.providerEvent?.turnID, currentProviderTurnIDBySessionID[summary.id])
    }

    private func threadRecordID(providerThreadID: String) -> String {
        stableIDFactory.id(prefix: "coding-agent-thread", value: "codex\n\(providerThreadID)")
    }

    private func turnRecordID(providerTurnID: String) -> String {
        stableIDFactory.id(prefix: "coding-agent-turn", value: "codex\n\(providerTurnID)")
    }

    private func identityRecordID(sessionID: String, kind: String, externalID: String) -> String {
        stableIDFactory.id(prefix: "identity", value: "\(sessionID)\ncodex\n\(kind)\n\(externalID)")
    }

    private func toolKey(sessionID: String, operationID: String) -> String {
        "\(sessionID)\u{1f}\(operationID)"
    }

    private func timestamp(milliseconds: Int) -> Date {
        Date(timeIntervalSince1970: Double(milliseconds) / 1_000)
    }

    private func normalizedProvider(_ provider: String) -> String {
        provider.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func trimmedNonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    private func firstNonEmpty(_ values: String?...) -> String? {
        for value in values {
            if let trimmed = trimmedNonEmpty(value) {
                return trimmed
            }
        }
        return nil
    }

    private func bounded(_ value: String, limit: Int) -> String {
        guard value.count > limit else { return value }
        return String(value.prefix(limit))
    }

    private static func isDuplicateAppendError(_ error: Error) -> Bool {
        let description = String(describing: error).lowercased()
        return description.contains("provenance_events")
            && (description.contains("unique") || description.contains("constraint") || description.contains("duplicate"))
    }
}

private struct PendingPrompt: Sendable {
    let envelope: ExecutionTelemetryEventEnvelope
    let text: String
}

private struct PendingTool: Sendable {
    let operationID: String
    let toolKind: String
    let name: String
    let inputSummary: String?
    let cwd: String?
    let startedAt: Date?
}

private struct GitContext: Sendable {
    let repositoryID: String
    let worktreeID: String
    let repository: ProvenanceRepositoryRecord
    let worktree: ProvenanceWorktreeRecord
}
