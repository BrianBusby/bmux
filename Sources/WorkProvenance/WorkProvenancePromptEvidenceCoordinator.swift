import BMUXAgentLaunch
import BmuxAgentChat
import Foundation
import Observation

/// Sequences canonical prompt persistence and resource acquisition for the current live session.
@MainActor
@Observable
final class WorkProvenancePromptEvidenceCoordinator {
    @ObservationIgnored private let recorder: WorkProvenanceCodingAgentEvidenceRecorder?
    @ObservationIgnored private let displayStore: WorkspaceDisplayCurrentStateStore?
    @ObservationIgnored private let resolveWorkspace: (String?, String?) -> WorkProvenancePromptWorkspaceActions?
    @ObservationIgnored private let refreshDisplay: (UUID) -> Void
    private var generation = UUID()
    // Request authorization only: these values never project into cards or the stored prompt.
    private var resourcesByPanel: [PanelKey: ResourceProgress] = [:]

    private struct PanelKey: Hashable {
        let workspaceID: UUID
        let surfaceID: UUID
    }

    private struct ResourceProgress {
        var submittedAt: TimeInterval
        let revision: UUID
        var accepted: WorkspaceSubmittedPromptMetadata?
    }

    init(
        recorder: WorkProvenanceCodingAgentEvidenceRecorder?,
        displayStore: WorkspaceDisplayCurrentStateStore?,
        resolveWorkspace: @escaping (String?, String?) -> WorkProvenancePromptWorkspaceActions?,
        refreshDisplay: @escaping (UUID) -> Void
    ) {
        self.recorder = recorder
        self.displayStore = displayStore
        self.resolveWorkspace = resolveWorkspace
        self.refreshDisplay = refreshDisplay
    }

    func stop() {
        generation = UUID()
        resourcesByPanel.removeAll()
    }

    func prune() {
        resourcesByPanel = resourcesByPanel.filter { key, _ in
            resolveWorkspace(key.workspaceID.uuidString, key.surfaceID.uuidString)?.isCurrent() == true
        }
    }

    func recordHook(
        record: AgentChatSessionRecord, event: WorkstreamEvent,
        stableWorkspaceID: UUID, fallbackPromptText: String?
    ) async {
        guard let recorder else { return }
        let startedGeneration = generation
        do {
            try await recorder.recordHookUserPromptSubmit(
                record: record, event: event, stableWorkspaceID: stableWorkspaceID,
                fallbackPromptText: fallbackPromptText
            )
            guard generation == startedGeneration, !Task.isCancelled else { return }
            refreshDisplay(stableWorkspaceID)
        } catch {
            StartupBreadcrumbLog.append("workProvenance.hookPrompt.recordFailed", fields: [
                "session": record.sessionID, "error": String(describing: error)
            ])
        }
    }

    func recordTranscript(
        record: AgentChatSessionRecord, messages: [ChatMessage], stableWorkspaceID: UUID?,
        isCurrentSession: @escaping @MainActor () -> Bool
    ) async {
        guard let recorder else { return }
        let startedGeneration = generation
        let actions = resolveWorkspace(record.workspaceID, record.surfaceID)
        var attempt: (key: PanelKey, revision: UUID)?
        var baselineReadSucceeded = false
        if let actions, actions.stableWorkspaceID == stableWorkspaceID, record.agentKind == .codex,
           actions.isCurrent(), isCurrentSession(),
           let submittedAt = messages.compactMap({ message -> TimeInterval? in
               guard message.role == .user, case .prose(let prose) = message.kind,
                     !prose.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
               return message.timestamp.timeIntervalSince1970
           }).max() {
            let key = PanelKey(workspaceID: actions.stableWorkspaceID, surfaceID: actions.surfaceID)
            if submittedAt >= (resourcesByPanel[key]?.submittedAt ?? -.infinity) {
                let revision = UUID()
                resourcesByPanel[key] = ResourceProgress(
                    submittedAt: submittedAt, revision: revision, accepted: resourcesByPanel[key]?.accepted
                )
                attempt = (key, revision)
                do {
                    let prior = try await displayStore?.freshSnapshot(stableWorkspaceID: actions.stableWorkspaceID)
                    baselineReadSucceeded = displayStore != nil
                    if resourcesByPanel[key]?.revision == revision,
                       let priorTime = prior?.lastSubmittedPromptSubmittedAt?.timeIntervalSince1970 {
                        resourcesByPanel[key]?.submittedAt = max(submittedAt, priorTime)
                    }
                } catch {
                    logReadFailure(record: record, workspaceID: actions.stableWorkspaceID, error: error)
                }
            }
        }
        guard generation == startedGeneration, !Task.isCancelled else { return }
        do {
            // Every prompt still reaches the ledger, including old, ambiguous and superseded batches.
            try await recorder.recordTranscriptUserPrompts(
                record: record, messages: messages, stableWorkspaceID: stableWorkspaceID
            )
        } catch {
            StartupBreadcrumbLog.append("workProvenance.transcriptPrompt.recordFailed", fields: [
                "session": record.sessionID, "error": String(describing: error)
            ])
            return
        }
        guard generation == startedGeneration, !Task.isCancelled else { return }
        if let stableWorkspaceID { refreshDisplay(stableWorkspaceID) }
        guard let actions, let attempt, baselineReadSucceeded,
              resourcesByPanel[attempt.key]?.revision == attempt.revision,
              actions.isCurrent(), isCurrentSession(), let displayStore else { return }
        let display: WorkspaceDisplayCurrentStateSnapshot?
        do {
            display = try await displayStore.freshSnapshot(stableWorkspaceID: actions.stableWorkspaceID)
        } catch {
            logReadFailure(record: record, workspaceID: actions.stableWorkspaceID, error: error)
            return
        }
        guard generation == startedGeneration, !Task.isCancelled,
              resourcesByPanel[attempt.key]?.revision == attempt.revision,
              actions.isCurrent(), isCurrentSession(), let display,
              display.stableWorkspaceID == actions.stableWorkspaceID,
              display.lastSubmittedPromptSessionID == record.sessionID,
              let submittedAt = display.lastSubmittedPromptSubmittedAt,
              submittedAt.timeIntervalSince1970 >= (resourcesByPanel[attempt.key]?.submittedAt ?? .infinity),
              let prompt = WorkspaceSubmittedPromptMetadata(
                message: display.lastSubmittedPrompt, sessionID: record.sessionID, submittedAt: submittedAt
              ),
              messages.contains(where: { message in
                guard message.role == .user, case .prose(let prose) = message.kind else { return false }
                return WorkspaceSubmittedPromptMetadata(
                    message: String(prose.text.trimmingCharacters(in: .whitespacesAndNewlines)
                        .prefix(WorkProvenanceCodingAgentEvidenceRecorder.textLimit)),
                    sessionID: record.sessionID,
                    submittedAt: Date(timeIntervalSince1970: message.timestamp.timeIntervalSince1970)
                ) == prompt
              }) else { return }
        prune()
        guard resourcesByPanel[attempt.key]?.accepted != prompt,
              let text = display.lastSubmittedPrompt, actions.applyResources(text) else { return }
        resourcesByPanel[attempt.key]?.accepted = prompt
    }

    private func logReadFailure(record: AgentChatSessionRecord, workspaceID: UUID, error: Error) {
        guard !Task.isCancelled else { return }
        StartupBreadcrumbLog.append("workProvenance.promptResources.readFailed", fields: [
            "session": record.sessionID, "workspace": workspaceID.uuidString, "error": String(describing: error)
        ])
    }
}
