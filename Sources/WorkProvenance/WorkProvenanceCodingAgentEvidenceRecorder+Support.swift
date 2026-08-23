import BMUXAgentLaunch
import BmuxAgentChat
import Foundation
import ProvenanceEngineContracts

extension WorkProvenanceCodingAgentEvidenceRecorder {
    func recordHookUserPromptSubmit(
        record: AgentChatSessionRecord,
        event: WorkstreamEvent,
        stableWorkspaceID: UUID,
        fallbackPromptText: String? = nil
    ) async throws {
        guard record.agentKind == .codex,
              event.hookEventName == .userPromptSubmit,
              let sessionID = trimmedNonEmpty(record.sessionID),
              let promptText = firstNonEmpty(
                event.submittedPromptMessage,
                fallbackPromptText
              ).map({ bounded($0, limit: Self.textLimit) })
        else {
            return
        }
        let observedAt = event.receivedAt
        let workingDirectory = firstNonEmpty(record.workingDirectory, event.cwd)
        let workspaceID = firstNonEmpty(record.workspaceID, event.workspaceId)
        let surfaceID = firstNonEmpty(record.surfaceID, event.surfaceId)
        let gitContext = await gitContext(for: workingDirectory, observedAt: observedAt)
        let nativeProviderTurnID = event.codexProviderTurnID
        let hookTurnSeed = [
            sessionID,
            nativeProviderTurnID ?? "",
            event.requestId ?? "",
            event.sessionId,
            String(observedAt.timeIntervalSince1970),
            promptText
        ].joined(separator: "\n")
        let providerTurnID = nativeProviderTurnID ?? stableIDFactory.id(prefix: "hook-codex-turn", value: hookTurnSeed)
        let turnID = turnRecordID(providerTurnID: providerTurnID)
        let session = ProvenanceSessionRecord(
            id: sessionID,
            agentKind: "codex",
            workspaceID: workspaceID,
            surfaceID: surfaceID,
            worktreeID: gitContext?.worktreeID,
            cwd: workingDirectory,
            status: "active",
            startedAt: observedAt,
            updatedAt: observedAt
        )
        let turn = ProvenanceCodingAgentTurnRecord(
            id: turnID,
            sessionID: sessionID,
            provider: "codex",
            providerTurnID: providerTurnID,
            status: "started",
            startedAt: observedAt,
            updatedAt: observedAt,
            source: .observed,
            confidence: .medium
        )
        let prompt = ProvenanceCodingAgentPromptRecord(
            id: stableIDFactory.id(
                prefix: "coding-agent-prompt",
                value: "codex\n\(sessionID)\n\(providerTurnID)\n\(promptText)"
            ),
            sessionID: sessionID,
            turnID: turnID,
            provider: "codex",
            text: promptText,
            submittedAt: observedAt,
            source: .observed,
            confidence: .medium
        )
        let display = ProvenanceWorkspaceDisplayRecord(
            id: stableIDFactory.workspaceDisplayID(stableWorkspaceID: stableWorkspaceID),
            workspaceID: stableWorkspaceID.uuidString,
            repositoryID: gitContext?.repositoryID,
            worktreeID: gitContext?.worktreeID,
            currentDirectory: workingDirectory,
            lastSubmittedPrompt: promptText,
            lastSubmittedPromptSubmittedAt: observedAt,
            lastSubmittedPromptSessionID: sessionID,
            observedAt: observedAt,
            updatedAt: observedAt
        )
        try await append(
            eventType: .codingAgentPromptSubmitted,
            envelopeID: stableIDFactory.id(prefix: "hook-codex-prompt", value: hookTurnSeed),
            timestamp: observedAt,
            sessionID: sessionID,
            repositoryID: gitContext?.repositoryID,
            worktreeID: gitContext?.worktreeID,
            confidence: .medium,
            payload: ProvenanceEventPayload(
                repository: gitContext?.repository,
                worktree: gitContext?.worktree,
                session: session,
                workspaceDisplay: display,
                codingAgentTurn: turn,
                codingAgentPrompt: prompt
            )
        )
    }

    func recordTranscriptUserPrompts(
        record: AgentChatSessionRecord,
        messages: [ChatMessage],
        stableWorkspaceID: UUID? = nil
    ) async throws {
        guard record.agentKind == .codex,
              let sessionID = trimmedNonEmpty(record.sessionID) else {
            return
        }
        let workingDirectory = trimmedNonEmpty(record.workingDirectory)
        let gitContext = await gitContext(for: workingDirectory, observedAt: record.lastActivityAt)
        for message in messages {
            guard message.role == .user,
                  case .prose(let prose) = message.kind,
                  let promptText = trimmedNonEmpty(prose.text).map({ bounded($0, limit: Self.textLimit) }) else {
                continue
            }
            let submittedAt = message.timestamp
            let turnSeed = "transcript\n\(sessionID)\n\(submittedAt.timeIntervalSince1970)\n\(promptText)"
            let session = ProvenanceSessionRecord(
                id: sessionID,
                agentKind: "codex",
                workspaceID: record.workspaceID,
                surfaceID: record.surfaceID,
                worktreeID: gitContext?.worktreeID,
                cwd: workingDirectory,
                status: record.state == .ended ? "ended" : "active",
                startedAt: nil,
                updatedAt: record.lastActivityAt
            )
            let prompt = ProvenanceCodingAgentPromptRecord(
                id: stableIDFactory.id(prefix: "coding-agent-prompt", value: turnSeed),
                sessionID: sessionID,
                turnID: nil,
                provider: "codex",
                text: promptText,
                submittedAt: submittedAt,
                source: .observed,
                confidence: .medium
            )
            let display = stableWorkspaceID.map { workspaceDisplay in
                ProvenanceWorkspaceDisplayRecord(
                    id: stableIDFactory.workspaceDisplayID(stableWorkspaceID: workspaceDisplay),
                    workspaceID: workspaceDisplay.uuidString,
                    repositoryID: gitContext?.repositoryID,
                    worktreeID: gitContext?.worktreeID,
                    currentDirectory: workingDirectory,
                    lastSubmittedPrompt: promptText,
                    lastSubmittedPromptSubmittedAt: submittedAt,
                    lastSubmittedPromptSessionID: sessionID,
                    observedAt: submittedAt,
                    updatedAt: submittedAt
                )
            }
            try await append(
                eventType: .codingAgentPromptSubmitted,
                envelopeID: stableIDFactory.id(prefix: "transcript-codex-prompt", value: turnSeed),
                timestamp: submittedAt,
                sessionID: sessionID,
                repositoryID: gitContext?.repositoryID,
                worktreeID: gitContext?.worktreeID,
                confidence: .medium,
                payload: ProvenanceEventPayload(
                    repository: gitContext?.repository,
                    worktree: gitContext?.worktree,
                    session: session,
                    workspaceDisplay: display,
                    codingAgentPrompt: prompt
                )
            )
        }
    }

    func codingAgentTurn(
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

    func gitContext(for directory: String?, observedAt: Date) async -> GitContext? {
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

    func sessionRecord(
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

    func externalIdentity(
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

    func effectiveProviderThreadID(
        summary: AgentChatSessionSummary,
        envelope: ExecutionTelemetryEventEnvelope
    ) -> String? {
        firstNonEmpty(envelope.providerSessionID, providerThreadIDBySessionID[summary.id])
    }

    func effectiveProviderTurnID(
        summary: AgentChatSessionSummary,
        envelope: ExecutionTelemetryEventEnvelope
    ) -> String? {
        firstNonEmpty(envelope.providerTurnID, envelope.providerEvent?.turnID, currentProviderTurnIDBySessionID[summary.id])
    }

    func threadRecordID(providerThreadID: String) -> String {
        stableIDFactory.id(prefix: "coding-agent-thread", value: "codex\n\(providerThreadID)")
    }

    func turnRecordID(providerTurnID: String) -> String {
        stableIDFactory.id(prefix: "coding-agent-turn", value: "codex\n\(providerTurnID)")
    }

    func identityRecordID(sessionID: String, kind: String, externalID: String) -> String {
        stableIDFactory.id(prefix: "identity", value: "\(sessionID)\ncodex\n\(kind)\n\(externalID)")
    }

    func toolKey(sessionID: String, operationID: String) -> String {
        "\(sessionID)\u{1f}\(operationID)"
    }

    func timestamp(milliseconds: Int) -> Date {
        Date(timeIntervalSince1970: Double(milliseconds) / 1_000)
    }

    func normalizedProvider(_ provider: String) -> String {
        provider.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    func trimmedNonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    func firstNonEmpty(_ values: String?...) -> String? {
        for value in values {
            if let trimmed = trimmedNonEmpty(value) {
                return trimmed
            }
        }
        return nil
    }

    func bounded(_ value: String, limit: Int) -> String {
        guard value.count > limit else { return value }
        return String(value.prefix(limit))
    }

    static func isDuplicateAppendError(_ error: Error) -> Bool {
        let description = String(describing: error).lowercased()
        return description.contains("provenance_events")
            && (description.contains("unique") || description.contains("constraint") || description.contains("duplicate"))
    }
}

struct PendingPrompt: Sendable {
    let envelope: ExecutionTelemetryEventEnvelope
    let text: String
}

struct PendingTool: Sendable {
    let operationID: String
    let toolKind: String
    let name: String
    let inputSummary: String?
    let cwd: String?
    let startedAt: Date?
}

struct GitContext: Sendable {
    let repositoryID: String
    let worktreeID: String
    let repository: ProvenanceRepositoryRecord
    let worktree: ProvenanceWorktreeRecord
}
