import BmuxAgentChat
import Foundation

/// Presentation-independent composition of transcript reading and explicitly
/// launched shared hosts. A transcript match alone never grants control.
@MainActor
final class TerminalChatRuntime: TerminalChatConnecting {
    private let reader: any TerminalChatReading
    private let hosts: any ConnectedCodexHosting
    private let bind: (String, UUID, UUID, String) -> Void
    private var drafts: [UUID: String] = [:]
    private var terminalLiveness: [UUID: @MainActor () -> Bool] = [:]
    private var connections: [UUID: (workspaceID: UUID, directory: String, host: ConnectedCodexHost)] = [:]

    init(reader: any TerminalChatReading, hosts: any ConnectedCodexHosting,
         bind: @escaping (String, UUID, UUID, String) -> Void) {
        self.reader = reader
        self.hosts = hosts
        self.bind = bind
    }

    func prepareConnectedSession(workspaceID: UUID, surfaceID: UUID, workingDirectory: String) async throws -> String {
        guard connections[surfaceID] == nil else { throw CodexControlError.duplicateRequest }
        let host = try await hosts.launch(surfaceID: surfaceID, workingDirectory: workingDirectory)
        connections[surfaceID] = (workspaceID, workingDirectory, host)
        return host.terminalCommand
    }

    func attachConnectedTerminal(surfaceID: UUID, isAlive: @escaping @MainActor () -> Bool) {
        terminalLiveness[surfaceID] = isAlive
    }

    func closeConnectedSession(surfaceID: UUID) async {
        terminalLiveness.removeValue(forKey: surfaceID)
        drafts.removeValue(forKey: surfaceID)
        if let entry = connections.removeValue(forKey: surfaceID) { await entry.host.connection.disconnect() }
        await hosts.endOwnedHost(surfaceID: surfaceID)
    }

    func terminalChatSnapshot(workspaceID: UUID, surfaceID: UUID) async -> [String: Any] {
        if let entry = connections[surfaceID], entry.workspaceID == workspaceID, entry.host.threadID == nil, terminalLiveness[surfaceID]?() == true,
           let adopted = try? await hosts.adoptOriginalThread(entry.host), let thread = adopted.threadID {
            connections[surfaceID] = (workspaceID, entry.directory, adopted)
            bind(thread, workspaceID, surfaceID, entry.directory)
        }
        let boundThread = connections[surfaceID].flatMap { $0.workspaceID == workspaceID ? $0.host.threadID : nil }
        var snapshot: [String: Any]
        if let boundThread {
            snapshot = await reader.terminalChatSnapshot(workspaceID: workspaceID, surfaceID: surfaceID, sessionID: boundThread)
        } else {
            snapshot = await reader.terminalChatSnapshot(workspaceID: workspaceID, surfaceID: surfaceID)
        }
        guard let entry = connections[surfaceID], entry.workspaceID == workspaceID,
              let threadID = entry.host.threadID, let actionOwner = entry.host.control else { return snapshot }
        let host = entry.host
        // A different selected transcript is never allowed to inherit this control connection.
        let selected = snapshot["sessionId"] as? String
        guard selected == nil || selected == threadID else { return snapshot }
        var control: [String: Any] = ["threadId": threadID, "status": "unavailable", "reason": "connectionUnavailable"]
        do {
            guard terminalLiveness[surfaceID]?() == true else { throw CodexControlError.disconnected }
            let loaded = try await host.connection.request(method: "thread/loaded/list", params: Data("{}".utf8))
            guard let loadedResponse = try JSONSerialization.jsonObject(with: loaded) as? [String: Any],
                  loadedResponse["data"] as? [String] == [threadID], loadedResponse["nextCursor"] is NSNull else {
                // A changed or ambiguous TUI thread must not retain old live history or controls.
                return ["status": "unavailable", "reason": "ambiguous"]
            }
            let parameters = try JSONSerialization.data(withJSONObject: ["threadId": threadID, "includeTurns": false])
            let data = try await host.connection.request(method: "thread/read", params: parameters)
            guard let response = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let thread = response["thread"] as? [String: Any], thread["id"] as? String == threadID else {
                throw CodexControlError.wrongThread
            }
            let providerState = thread["status"] as? [String: Any]
            let history = snapshot["history"] as? [String: Any]
            let turn = history?["observed_turn"] as? [String: Any]
            let active = providerState?["type"] as? String == "active" && turn?["state"] as? String == "working" ? turn?["id"] as? String : nil
            control = ["threadId": threadID, "status": "connected", "queueFollowUp": true,
                       "steerTurn": active != nil, "interruptTurn": false, "reason": "interruptTurnGuardUnsupported"]
            if let active { control["activeTurnId"] = active }
            if snapshot["history"] != nil { snapshot["status"] = "observed" }
        } catch {
            if terminalLiveness[surfaceID]?() == true, let replacement = try? await hosts.reconnect(host) {
                connections[surfaceID] = (workspaceID, entry.directory, replacement)
            }
        }
        let available = control["status"] as? String == "connected"
        control["provider"] = "codex"
        control["providerVersion"] = "0.154.0"
        control["capabilities"] = Self.capabilities(connected: available, activeTurn: control["activeTurnId"] != nil,
                                                   historyAvailable: snapshot["history"] != nil)
        control["draft"] = drafts[surfaceID]
        control["actions"] = (try? JSONSerialization.jsonObject(with: JSONEncoder().encode(await actionOwner.actionSnapshot()))) ?? []
        snapshot["control"] = control
        snapshot["sessionId"] = threadID
        snapshot["workspaceId"] = workspaceID.uuidString
        snapshot["surfaceId"] = surfaceID.uuidString
        return snapshot
    }

    func updateConnectedDraft(workspaceID: UUID, surfaceID: UUID, sessionID: String, text: String) throws {
        guard let entry = connections[surfaceID], entry.workspaceID == workspaceID,
              entry.host.threadID == sessionID, text.utf8.count <= 64 * 1024 else { throw CodexControlError.wrongThread }
        drafts[surfaceID] = text
    }

    func performConnectedAction(workspaceID: UUID, surfaceID: UUID, sessionID: String, requestID: UUID, text: String, expectedTurnID: String?) async throws -> [String: Any] {
        guard let entry = connections[surfaceID], entry.workspaceID == workspaceID,
              entry.host.threadID == sessionID, let owner = entry.host.control else { throw CodexControlError.wrongThread }
        let snapshot = await terminalChatSnapshot(workspaceID: workspaceID, surfaceID: surfaceID)
        guard let control = snapshot["control"] as? [String: Any], control["status"] as? String == "connected" else {
            throw CodexControlError.disconnected
        }
        let action = CodexControlAction(id: requestID, threadID: sessionID, operation: expectedTurnID == nil ? .queue : .steer,
                                        expectedTurnID: expectedTurnID, text: text)
        let result = try await owner.submit(action)
        if result.delivery == .accepted, drafts[surfaceID] == text { drafts[surfaceID] = "" }
        return try JSONSerialization.jsonObject(with: JSONEncoder().encode(result)) as? [String: Any] ?? [:]
    }

    private static func capabilities(connected: Bool, activeTurn: Bool, historyAvailable: Bool) -> [String: [String: Any]] {
        let unavailable: [String: Any] = ["available": false, "reason": connected ? "terminalOnly" : "connectionUnavailable"]
        return [
            "readConversation": ["available": historyAvailable, "reason": historyAvailable ? "available" : "historyUnavailable"],
            "submitPrompt": ["available": false, "reason": "idleSubmissionNotAtomic"],
            "queueFollowUp": connected ? ["available": true] : unavailable,
            "steerTurn": connected && activeTurn ? ["available": true] : ["available": false, "reason": "noVerifiedActiveTurn"],
            "interruptTurn": ["available": false, "reason": "providerInterruptGuardUnsupported"],
            "answerApproval": unavailable, "answerQuestion": unavailable, "changeSettings": unavailable
        ]
    }

    func terminalChatRawOutput(workspaceID: UUID, surfaceID: UUID, sessionID: String, messageID: String) async throws -> String? {
        try await reader.terminalChatRawOutput(workspaceID: workspaceID, surfaceID: surfaceID, sessionID: sessionID, messageID: messageID)
    }
}
