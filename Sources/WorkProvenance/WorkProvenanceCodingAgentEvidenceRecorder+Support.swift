import BmuxAgentChat
import Foundation
import ProvenanceEngineContracts

extension WorkProvenanceCodingAgentEvidenceRecorder {
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
