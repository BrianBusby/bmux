import BmuxAgentChat
import Foundation

/// Presentation-independent composition of transcript reading and explicitly
/// launched shared hosts. A transcript match alone never grants control.
@MainActor
final class TerminalChatRuntime: TerminalChatConnecting {
    private let reader: any TerminalChatReading
    private let hosts: any ConnectedCodexHosting
    private let bind: (String, UUID, UUID, String) -> Void
    private struct Draft: Sendable {
        let revision: UUID
        let text: String
    }
    private var drafts: [UUID: Draft] = [:]
    private var submittedDraftRevisions: [UUID: UUID] = [:]
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
#if DEBUG
        snapshot = acceptanceHistoryOverride(snapshot, workspaceID: workspaceID, surfaceID: surfaceID)
#endif
        guard let entry = connections[surfaceID], entry.workspaceID == workspaceID,
              let threadID = entry.host.threadID, let actionOwner = entry.host.control else { return snapshot }
        let host = entry.host
        // A different selected transcript is never allowed to inherit this control connection.
        let selected = snapshot["sessionId"] as? String
        guard selected == nil || selected == threadID else { return snapshot }
        var control: [String: Any] = ["threadId": threadID, "status": "unavailable", "reason": "connectionUnavailable"]
        do {
            guard terminalLiveness[surfaceID]?() == true else { throw CodexControlError.disconnected }
#if DEBUG
            if UserDefaults.standard.bool(forKey: "bmux.acceptance.disconnectTransport.\(surfaceID.uuidString)") {
                UserDefaults.standard.set(false, forKey: "bmux.acceptance.disconnectTransport.\(surfaceID.uuidString)")
                await host.connection.disconnect()
            }
#endif
            let loaded = try await host.connection.request(method: "thread/loaded/list", params: Data("{}".utf8))
            // Ownership was established when the host adopted its original thread; other loaded threads do not replace it.
            guard let loadedResponse = try JSONSerialization.jsonObject(with: loaded) as? [String: Any],
                  let loadedThreadIDs = loadedResponse["data"] as? [String],
                  loadedThreadIDs.contains(threadID), loadedResponse["nextCursor"] is NSNull else {
                return ["status": "unavailable", "reason": "connectionUnavailable"]
            }
            let parameters = try JSONSerialization.data(withJSONObject: ["threadId": threadID, "includeTurns": false])
            let data = try await host.connection.request(method: "thread/read", params: parameters)
            guard let response = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let thread = response["thread"] as? [String: Any], thread["id"] as? String == threadID else {
                throw CodexControlError.wrongThread
            }
            // A timeout or malformed reply does not necessarily disconnect the socket.
            // Reconcile from provider evidence on healthy refreshes too; never resend.
            let uncertainIDs = Set(await actionOwner.actionSnapshot().filter { $0.delivery == .uncertain }.map(\.id))
            try await actionOwner.reconcile()
            let reconciled = await actionOwner.actionSnapshot()
            for action in reconciled where uncertainIDs.contains(action.id) && action.delivery == .accepted {
                retireDraft(for: action.id, surfaceID: surfaceID)
            }
            let providerState = thread["status"] as? [String: Any]
            let history = snapshot["history"] as? [String: Any]
            let turn = history?["observed_turn"] as? [String: Any]
            let active = providerState?["type"] as? String == "active" && turn?["state"] as? String == "working" ? turn?["id"] as? String : nil
            control = ["threadId": threadID, "status": "connected", "queueFollowUp": true,
                       "steerTurn": active != nil, "interruptTurn": false, "reason": "interruptTurnGuardUnsupported"]
            if let active { control["activeTurnId"] = active }
            if snapshot["history"] != nil,
               snapshot["status"] as? String != "partial",
               snapshot["status"] as? String != "stale" {
                snapshot["status"] = "observed"
            }
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
        if let draft = drafts[surfaceID] {
            control["draft"] = ["revision": draft.revision.uuidString, "text": draft.text]
        }
        control["actions"] = (try? JSONSerialization.jsonObject(with: JSONEncoder().encode(await actionOwner.actionSnapshot()))) ?? []
        snapshot["control"] = control
        snapshot["sessionId"] = threadID
        snapshot["workspaceId"] = workspaceID.uuidString
        snapshot["surfaceId"] = surfaceID.uuidString
        return snapshot
    }

#if DEBUG
    /// Test-only history fault injection, scoped by workspace, surface, and
    /// optionally the selected provider session. It is absent from Release.
    private func acceptanceHistoryOverride(
        _ snapshot: [String: Any],
        workspaceID: UUID,
        surfaceID: UUID
    ) -> [String: Any] {
        let defaults = UserDefaults.standard
        guard defaults.string(forKey: "bmux.acceptance.history.surface") == surfaceID.uuidString,
              defaults.string(forKey: "bmux.acceptance.history.workspace") == workspaceID.uuidString,
              let mode = defaults.string(forKey: "bmux.acceptance.history.mode") else { return snapshot }
        let sessionID = snapshot["sessionId"] as? String
        if let expected = defaults.string(forKey: "bmux.acceptance.history.session"), expected != sessionID { return snapshot }
        switch mode {
        case "unavailable":
            return ["status": "unavailable", "reason": "historyUnavailable",
                    "sessionId": sessionID as Any, "workspaceId": workspaceID.uuidString,
                    "surfaceId": surfaceID.uuidString]
        case "partial", "stale":
            var result = snapshot
            result["status"] = mode
            result["historyFreshness"] = mode
            if var history = result["history"] as? [String: Any],
               var messages = history["messages"] as? [[String: Any]], messages.count > 1 {
                messages.removeLast()
                history["messages"] = messages
                result["history"] = history
            }
            return result
        default:
            return snapshot
        }
    }
#endif

    func updateConnectedDraft(workspaceID: UUID, surfaceID: UUID, sessionID: String, revision: UUID, text: String) throws {
        guard let entry = connections[surfaceID], entry.workspaceID == workspaceID,
              entry.host.threadID == sessionID, text.utf8.count <= 64 * 1024 else { throw CodexControlError.wrongThread }
        drafts[surfaceID] = Draft(revision: revision, text: text)
    }

    func performConnectedAction(workspaceID: UUID, surfaceID: UUID, sessionID: String, requestID: UUID, draftRevision: UUID, text: String, expectedTurnID: String?) async throws -> [String: Any] {
        guard let entry = connections[surfaceID], entry.workspaceID == workspaceID,
              entry.host.threadID == sessionID, let owner = entry.host.control else { throw CodexControlError.wrongThread }
        let snapshot = await terminalChatSnapshot(workspaceID: workspaceID, surfaceID: surfaceID)
        guard let control = snapshot["control"] as? [String: Any], control["status"] as? String == "connected" else {
            throw CodexControlError.disconnected
        }
        guard drafts[surfaceID]?.revision == draftRevision, drafts[surfaceID]?.text == text else { throw CodexControlError.wrongThread }
        submittedDraftRevisions[requestID] = draftRevision
        let action = CodexControlAction(id: requestID, threadID: sessionID, operation: expectedTurnID == nil ? .queue : .steer,
                                        expectedTurnID: expectedTurnID, text: text)
        let result = try await owner.submit(action)
        if result.delivery == .accepted { retireDraft(for: requestID, surfaceID: surfaceID) }
        return try JSONSerialization.jsonObject(with: JSONEncoder().encode(result)) as? [String: Any] ?? [:]
    }

    private func retireDraft(for requestID: UUID, surfaceID: UUID) {
        guard let revision = submittedDraftRevisions.removeValue(forKey: requestID), drafts[surfaceID]?.revision == revision else { return }
        drafts.removeValue(forKey: surfaceID)
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
