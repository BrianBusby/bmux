import Foundation
import ProvenanceEngineContracts

/// A bounded page of one received plan, retaining the original step values.
struct AgentSessionPlanPage {
    private static let pageSize = 8
    let steps: ArraySlice<ProvenanceCodingAgentPlanStepRecord>
    let start: Int
    let end: Int
    let total: Int
    let currentPage: Int
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
        self.currentPage = page
        self.previousPage = page > 0 ? page - 1 : nil
        self.nextPage = page < lastPage ? page + 1 : nil
    }
}

enum AgentSessionPlanStepStatus: Equatable {
    case pending, inProgress, completed, unknown
    case providerValue(String)

    init(_ status: String) {
        switch status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "pending": self = .pending
        case "in_progress": self = .inProgress
        case "completed", "complete", "done": self = .completed
        case "": self = .unknown
        default: self = .providerValue(status)
        }
    }

    func label(locale: Locale) -> String {
        switch self {
        case .pending:
            String(localized: LocalizedStringResource("agentSession.factual.plan.status.pending", defaultValue: "Pending", locale: locale))
        case .inProgress:
            String(localized: LocalizedStringResource("agentSession.factual.plan.status.inProgress", defaultValue: "In progress", locale: locale))
        case .completed:
            String(localized: LocalizedStringResource("agentSession.factual.plan.status.completed", defaultValue: "Completed", locale: locale))
        case .unknown:
            String(localized: LocalizedStringResource("agentSession.factual.unknown", defaultValue: "Unknown", locale: locale))
        case .providerValue(let value): value
        }
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
