import BMUXAgentLaunch
import BmuxAgentChat
import Foundation

/// Binds evidence ingestion to the registry's current terminal session without owning that session.
@MainActor
struct AgentChatPromptEvidenceBinding {
    let recordLifecycle: (AgentSessionLifecycleChange, Date) -> Void
    let recordHook: (AgentChatSessionRecord, WorkstreamEvent) -> Void
    let recordTranscript: (AgentChatSessionRecord, [ChatMessage]) -> Void

    init(registry: AgentChatSessionRegistry, runtime: WorkProvenanceRuntime) {
        recordLifecycle = { [weak runtime] change, timestamp in
            runtime?.recordSessionLifecycleChange(change, timestamp: timestamp)
        }
        recordHook = { [weak runtime] record, event in
            runtime?.recordHookUserPromptSubmit(record: record, event: event)
        }
        recordTranscript = { [weak registry, weak runtime] record, messages in
            runtime?.recordTranscriptUserPrompts(record: record, messages: messages, isCurrentSession: {
                guard let surfaceID = record.surfaceID, let surfaceUUID = UUID(uuidString: surfaceID), let registry,
                      let current = registry.liveSession(surfaceID: surfaceID),
                      registry.sessions(workspaceID: nil).filter({
                          $0.surfaceID.flatMap(UUID.init(uuidString:)) == surfaceUUID && $0.state != .ended
                      }).count == 1 else { return false }
                return current.sessionID == record.sessionID && current.agentKind == record.agentKind
                    && current.workspaceID == record.workspaceID && current.surfaceID == record.surfaceID
            })
        }
    }
}
