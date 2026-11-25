import Foundation

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
