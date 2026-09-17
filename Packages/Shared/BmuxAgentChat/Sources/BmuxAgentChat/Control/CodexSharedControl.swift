import Foundation

/// Scoped mutation owner for a deliberately connected session. It does not own
/// provider lifetime. The original TUI remains responsible for approvals and
/// draining the provider queue. A consumed queue entry is not retried.
public actor CodexSharedControl {
    public let threadID: String
    private var connection: CodexRPCConnection
    private var actions: [UUID: CodexControlAction] = [:]
    private var seenRequestIDs: Set<UUID> = []
    private var order: [UUID] = []

    public init(threadID: String, connection: CodexRPCConnection) {
        self.threadID = threadID
        self.connection = connection
    }

    /// The host verifies its original process and thread before supplying this
    /// replacement connection. Pending writes become uncertain, never replayed.
    public func reconnect(using replacement: CodexRPCConnection) async {
        let previous = connection
        connection = replacement
        await previous.disconnect()
    }

    public func actionSnapshot() -> [CodexControlAction] { order.compactMap { actions[$0] } }

    public func submit(_ action: CodexControlAction) async throws -> CodexControlAction {
        guard action.threadID == threadID else { throw CodexControlError.wrongThread }
        guard !seenRequestIDs.contains(action.id) else { throw CodexControlError.duplicateRequest }
        guard !action.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              action.text.utf8.count <= 64 * 1024,
              !action.text.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("/") else {
            throw CodexControlError.invalidInput
        }
        guard action.operation != .steer || action.expectedTurnID?.isEmpty == false else {
            throw CodexControlError.invalidInput
        }
        // Retire prompt bodies, but keep request tombstones so a replay cannot
        // become a second submission. Uncertain actions are never evicted.
        guard seenRequestIDs.count < 16_384 else { throw CodexControlError.invalidInput }
        if order.count >= 128 {
            guard let oldest = order.first(where: { actions[$0]?.delivery == .accepted || actions[$0]?.delivery == .failed }) else {
                throw CodexControlError.invalidInput
            }
            order.removeAll { $0 == oldest }
            actions.removeValue(forKey: oldest)
        }
        seenRequestIDs.insert(action.id)
        actions[action.id] = action
        order.append(action.id)
        var params: [String: TranscriptJSONValue] = [
            "threadId": .string(threadID), "clientUserMessageId": .string(action.id.uuidString),
            "input": .array([.object(["type": .string("text"), "text": .string(action.text)])])
        ]
        if let expected = action.expectedTurnID { params["expectedTurnId"] = .string(expected) }
        do {
            let data = try await connection.request(
                method: action.operation == .queue ? "thread/queue/add" : "turn/steer",
                params: JSONEncoder().encode(TranscriptJSONValue.object(params))
            )
            let result = try JSONDecoder().decode(TranscriptJSONValue.self, from: data)
            let providerID = action.operation == .queue ? result["queuedSubmission"]?["id"]?.string : result["turnId"]?.string
            guard let providerID else { throw CodexControlError.invalidResponse }
            actions[action.id]?.delivery = .accepted
            actions[action.id]?.providerID = providerID
        } catch {
            // Even malformed acknowledgments may follow a successful mutation.
            let rejected = (error as? CodexControlError) == .rejected || (error as? CodexControlError) == .disconnected
            actions[action.id]?.delivery = rejected ? .failed : .uncertain
        }
        return actions[action.id]!
    }

    /// Read-only reconciliation: provider-authored client IDs can prove acceptance.
    /// Missing history or a missing queue entry cannot prove non-delivery.
    public func reconcile() async throws {
        guard actions.values.contains(where: { $0.delivery == .uncertain }) else { return }
        let params = try JSONEncoder().encode(TranscriptJSONValue.object(["threadId": .string(threadID), "includeTurns": .bool(true)]))
        let history = try JSONDecoder().decode(TranscriptJSONValue.self, from: await connection.request(method: "thread/read", params: params))
        guard history["thread"]?["id"]?.string == threadID else { throw CodexControlError.wrongThread }
        let queue = try JSONDecoder().decode(TranscriptJSONValue.self, from: await connection.request(method: "thread/queue/list", params: params))
        var evidence: [String: String] = [:]
        for entry in queue["data"]?.array ?? [] {
            if let client = entry["clientUserMessageId"]?.string, let id = entry["id"]?.string { evidence[client] = id }
        }
        for turn in history["thread"]?["turns"]?.array ?? [] {
            for item in turn["items"]?.array ?? [] where item["type"]?.string == "userMessage" {
                if let client = item["clientId"]?.string, let id = turn["id"]?.string { evidence[client] = id }
            }
        }
        for id in order where actions[id]?.delivery == .uncertain {
            if let providerID = evidence[id.uuidString] {
                actions[id]?.delivery = .accepted
                actions[id]?.providerID = providerID
            }
        }
    }
}
