import BmuxAgentChat
import Foundation

extension AgentChatTranscriptService: TerminalChatReading {
    func terminalChatSnapshot(workspaceID: UUID, surfaceID: UUID) async -> [String: Any] {
        _ = await observeAgentProcessesForListing(surfaceIDs: [surfaceID], waitUpTo: .seconds(1))
        let records = sessionRecords(workspaceID: workspaceID.uuidString).filter {
            $0.surfaceID.flatMap(UUID.init(uuidString:)) == surfaceID
        }
        let live = records.filter { $0.state != .ended }
        let candidates = live.isEmpty ? records : live
        // Never choose an agent by cwd, PID alone, or recency when the binding is ambiguous.
        guard candidates.count == 1, let record = candidates.first else {
            return ["status": "unavailable", "reason": candidates.isEmpty ? "unassociated" : "ambiguous"]
        }
        guard let page = await history(sessionID: record.sessionID, beforeSeq: nil, limit: 500, refresh: true),
              let current = sessionRecord(sessionID: record.sessionID),
              current.surfaceID.flatMap(UUID.init(uuidString:)) == surfaceID,
              current.workspaceID.flatMap(UUID.init(uuidString:)) == workspaceID,
              let payload = wirePayload(page) else {
            return ["status": "unavailable", "reason": "historyUnavailable"]
        }
        return [
            "status": current.state == .ended ? "ended" : "observed",
            "sessionId": record.sessionID,
            "workspaceId": workspaceID.uuidString,
            "surfaceId": surfaceID.uuidString,
            "history": payload,
            // Transcript observation is not a provider control connection.
            "connection": "ordinaryCLITranscript",
            "controlReason": "noAttachedControlTransport"
        ]
    }
    func terminalChatRawOutput(workspaceID: UUID, surfaceID: UUID, sessionID: String, messageID: String) async throws -> String? {
        guard let record = sessionRecord(sessionID: sessionID),
              record.workspaceID.flatMap(UUID.init(uuidString:)) == workspaceID,
              record.surfaceID.flatMap(UUID.init(uuidString:)) == surfaceID,
              let page = await history(sessionID: sessionID, beforeSeq: nil, limit: 500, refresh: true),
              let current = sessionRecord(sessionID: sessionID),
              current.workspaceID.flatMap(UUID.init(uuidString:)) == workspaceID,
              current.surfaceID.flatMap(UUID.init(uuidString:)) == surfaceID,
              let message = page.messages.first(where: { $0.id == messageID }),
              case .terminal(let capture) = message.kind,
              let reference = capture.outputMetadata?.rawOutputRef else { return nil }
        return try await rawOutputStore.read(rawOutputRef: reference)?.rawOutput
    }
}
