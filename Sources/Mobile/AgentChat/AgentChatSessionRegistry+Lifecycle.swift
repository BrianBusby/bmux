import BMUXAgentLaunch
import BmuxAgentChat
import Foundation

/// A coding-agent session discovered by observing the process table, with no
/// dependency on hooks firing. Identity (and, for codex, the transcript path)
/// comes from the agent's own argv, environment, or open transcript file, so a
/// session launched through any indirection (a subrouter, a wrapper) is still
/// found.
nonisolated struct ObservedAgentSession: Sendable {
    let sessionID: String
    let agentKind: ChatAgentKind
    let surfaceID: String
    let workspaceID: String?
    let pid: Int
    let workingDirectory: String?
    let transcriptPath: String?
    let sampledAt: Date

    init(
        sessionID: String,
        agentKind: ChatAgentKind,
        surfaceID: String,
        workspaceID: String?,
        pid: Int,
        workingDirectory: String?,
        transcriptPath: String?,
        sampledAt: Date = Date()
    ) {
        self.sessionID = sessionID
        self.agentKind = agentKind
        self.surfaceID = surfaceID
        self.workspaceID = workspaceID
        self.pid = pid
        self.workingDirectory = workingDirectory
        self.transcriptPath = transcriptPath
        self.sampledAt = sampledAt
    }
}

struct AgentSubsessionLifecycleChange: Sendable, Equatable {
    enum Phase: Sendable, Equatable {
        case started
        case stopped
    }

    let phase: Phase
    let parentSessionID: String
    let agentKind: ChatAgentKind
    let workspaceID: String?
    let surfaceID: String?
    let workingDirectory: String?
    let subsessionID: String?
    let displayName: String?
}

extension AgentChatSessionRegistry {
    func stampLifecycleTransition(
        previous: AgentChatSessionRecord?,
        current: inout AgentChatSessionRecord,
        at transitionAt: Date
    ) {
        let wasEnded = previous.map { Self.stateIsEnded($0.state) } ?? false
        let isEnded = Self.stateIsEnded(current.state)
        if isEnded {
            if wasEnded {
                current.endedAt = current.endedAt ?? previous?.endedAt ?? transitionAt
            } else {
                current.endedAt = transitionAt
            }
        } else {
            current.endedAt = nil
        }
    }

    /// Strips an agent-name prefix from prefixed workstream ids
    /// (`claude-<uuid>`); raw hook ids pass through.
    static func normalizedSessionID(_ id: String, source: String) -> String {
        let prefix = "\(source)-"
        if id.hasPrefix(prefix) {
            return String(id.dropFirst(prefix.count))
        }
        return id
    }

    nonisolated static func nextState(
        previous: ChatAgentState,
        event: WorkstreamEvent
    ) -> ChatAgentState {
        if stateIsEnded(previous), event.hookEventName != .sessionStart {
            return .ended
        }
        switch event.hookEventName {
        case .sessionStart:
            return .idle
        case .userPromptSubmit, .preToolUse, .postToolUse, .todoWrite:
            if case .working = previous { return previous }
            return .working(since: event.receivedAt)
        case .preCompact, .postCompact:
            // Compaction is lifecycle telemetry. It can occur while a session
            // is idle, so it must not create a synthetic working state.
            return previous
        case .permissionRequest, .askUserQuestion, .exitPlanMode, .notification:
            if case .needsInput = previous { return previous }
            return .needsInput(since: event.receivedAt)
        case .stop:
            return .idle
        case .subagentStart, .subagentStop:
            // Task subagent lifecycle says nothing about the parent
            // session's activity; keep the current state.
            return previous
        case .sessionEnd:
            return .ended
        }
    }

    nonisolated static func subsessionLifecycleChange(
        for event: WorkstreamEvent,
        record: AgentChatSessionRecord
    ) -> AgentSubsessionLifecycleChange? {
        let phase: AgentSubsessionLifecycleChange.Phase
        switch event.hookEventName {
        case .subagentStart:
            phase = .started
        case .subagentStop:
            phase = .stopped
        default:
            return nil
        }
        let metadata = AgentSubsessionEventMetadata(event: event)
        return AgentSubsessionLifecycleChange(
            phase: phase,
            parentSessionID: record.sessionID,
            agentKind: record.agentKind,
            workspaceID: record.workspaceID ?? event.workspaceId,
            surfaceID: record.surfaceID ?? event.surfaceId,
            workingDirectory: record.workingDirectory ?? event.cwd,
            subsessionID: metadata.identifier ?? event.requestId,
            displayName: metadata.displayName
        )
    }

    nonisolated static func stateIsEnded(_ state: ChatAgentState) -> Bool {
        if case .ended = state {
            return true
        }
        return false
    }
}

private struct AgentSubsessionEventMetadata {
    let identifier: String?
    let displayName: String?

    init(event: WorkstreamEvent) {
        let extra = Self.object(from: event.extraFieldsJSON)
        identifier = Self.firstString(in: extra, keys: [
            "subagent_id",
            "subagentId",
            "subsession_id",
            "subsessionId",
            "agent_id",
            "agentId",
            "task_id",
            "taskId",
            "id",
        ])
        displayName = Self.firstString(in: extra, keys: [
            "subagent_name",
            "subagentName",
            "agent_name",
            "agentName",
            "name",
            "title",
            "role",
            "description",
            "task",
        ])
    }

    private static func object(from json: String?) -> [String: Any] {
        guard let json,
              let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return object
    }

    private static func firstString(in object: [String: Any], keys: [String]) -> String? {
        for key in keys {
            guard let raw = object[key] else { continue }
            if let value = raw as? String {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return trimmed }
            } else if let value = raw as? NSNumber {
                return value.stringValue
            }
        }
        return nil
    }
}
