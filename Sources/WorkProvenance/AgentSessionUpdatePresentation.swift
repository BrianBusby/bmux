import Foundation

/// Labels for provider-visible summaries, including commentary and reasoning summaries.
enum AgentSessionUpdatePresentation {
    static var overviewTitle: String {
        String(localized: "agentSession.factual.blockersAndApproach", defaultValue: "Blockers & approach changes")
    }

    static func overviewCount(_ count: Int) -> String {
        String.localizedStringWithFormat(
            String(localized: "agentSession.factual.reasoningCount", defaultValue: "%d change(s)"), count
        )
    }

    static var countTitle: String {
        String(localized: "agentSession.factual.reasoning", defaultValue: "Reasoning")
    }

    static var detailTitle: String {
        String(localized: "agentSession.factual.reasoningSummary", defaultValue: "Reasoning summary")
    }

    static var runTitle: String {
        String(localized: "agentSession.expanded.reasoningSteps", defaultValue: "Reasoning steps")
    }

    static var activityBasis: String {
        String(localized: "agentSession.web.smartSession.activityBasis.visibleReasoningSummary", defaultValue: "Based on visible reasoning")
    }
}
