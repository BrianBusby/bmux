import Foundation

/// Labels for provider-visible summaries, including commentary and reasoning summaries.
enum AgentSessionUpdatePresentation {
    static var overviewTitle: String {
        String(localized: "agentSession.factual.blockersAndApproach", defaultValue: "Agent updates")
    }

    static func overviewCount(_ count: Int) -> String {
        String.localizedStringWithFormat(
            String(localized: "agentSession.factual.reasoningCount", defaultValue: "%d total"), count
        )
    }

    static var countTitle: String {
        String(localized: "agentSession.factual.reasoning", defaultValue: "Agent updates")
    }

    static var detailTitle: String {
        String(localized: "agentSession.factual.reasoningSummary", defaultValue: "Agent update")
    }

    static var runTitle: String {
        String(localized: "agentSession.expanded.reasoningSteps", defaultValue: "Agent updates")
    }

    static var activityBasis: String {
        String(localized: "agentSession.web.smartSession.activityBasis.visibleReasoningSummary", defaultValue: "Based on an agent update")
    }
}
