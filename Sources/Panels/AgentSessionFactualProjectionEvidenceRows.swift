import Foundation
import ProvenanceEngineContracts

/// A bounded page of one received plan, retaining the original step values.
struct AgentSessionPlanPage {
    private static let pageSize = 8
    let steps: ArraySlice<ProvenanceCodingAgentPlanStepRecord>
    let start: Int
    let end: Int
    let total: Int
    let previousPage: Int?
    let nextPage: Int?

    init(steps: [ProvenanceCodingAgentPlanStepRecord], requestedPage: Int) {
        let lastPage = steps.isEmpty ? 0 : (steps.count - 1) / Self.pageSize
        let page = min(max(requestedPage, 0), lastPage)
        let start = page * Self.pageSize
        let end = min(start + Self.pageSize, steps.count)
        self.steps = steps[start..<end]
        self.start = start
        self.end = end
        self.total = steps.count
        self.previousPage = page > 0 ? page - 1 : nil
        self.nextPage = page < lastPage ? page + 1 : nil
    }
}

struct AgentSessionFactualProjectionEvidenceRows {
    static func isPlanStepCompleted(_ status: String) -> Bool {
        switch status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "completed", "complete", "done":
            true
        default:
            false
        }
    }

    static func turnProperties(for turnSnapshot: ProvenanceFactualSessionProjectionTurnSnapshot) -> [TurnProperty] {
        var rows: [TurnProperty] = []
        if let prompt = turnSnapshot.submittedPrompt?.text {
            rows.append(.prompt(prompt))
        }
        rows.append(.providerTurnID(turnSnapshot.turn.providerTurnID))
        rows.append(.peTurnID(turnSnapshot.turn.id))
        rows.append(.peThreadID(turnSnapshot.turn.threadID))
        rows.append(.status(turnSnapshot.turn.status))
        rows.append(.model(turnSnapshot.turn.model))
        return rows
    }

    static func priorTurnItems(for snapshot: ProvenanceFactualSessionProjectionSnapshot) -> [PriorTurnItem] {
        var detailedTurnsByID: [String: ProvenanceFactualSessionProjectionTurnSnapshot] = [:]
        for turn in snapshot.turns {
            detailedTurnsByID[turn.turn.id] = turn
        }
        return snapshot.priorTurns.map { turn in
            if let detail = detailedTurnsByID[turn.turnID] {
                return .detail(detail)
            }
            return .reference(turn)
        }.sorted { turnDate(for: $0) > turnDate(for: $1) }
    }

    static func turnDate(for item: PriorTurnItem) -> Date {
        switch item {
        case .detail(let turnSnapshot):
            turnSnapshot.turn.completedAt ?? turnSnapshot.turn.updatedAt
        case .reference(let turn):
            turn.completedAt ?? turn.updatedAt
        }
    }

    static func latestRows<Value>(_ values: [Value], limit: Int) -> [Value] {
        guard limit > 0 else { return [] }
        guard values.count > limit else { return values }
        return Array(values.suffix(limit))
    }

    static func finalAssistantMessageText(for turnSnapshot: ProvenanceFactualSessionProjectionTurnSnapshot) -> String? {
        turnSnapshot.assistantMessages.reversed().compactMap { message in
            trimmedNonEmpty(message.text)
        }.first
    }

    private static func trimmedNonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}
