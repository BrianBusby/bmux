import SwiftUI
import BmuxAppKitSupportUI
import ProvenanceEngineContracts

private extension Color {
    static let bmuxTextTertiary = Color(nsColor: MatteTheme.dynamicColor(.textTertiary))
}

/// Displays a bounded page of the steps actually present in one reported plan.
struct AgentSessionPlanStepsView: View {
    let plan: ProvenanceCodingAgentPlanUpdateRecord
    @State private var page = 0
    @Environment(\.locale) private var locale

    var body: some View {
        let visible = AgentSessionPlanPage(steps: plan.steps, requestedPage: page)
        VStack(alignment: .leading, spacing: 6) {
            ForEach(visible.start..<visible.end, id: \.self) { index in
                let step = visible.steps[index]
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: AgentSessionFactualProjectionEvidenceRows.isPlanStepCompleted(step.status) ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(AgentSessionFactualProjectionEvidenceRows.isPlanStepCompleted(step.status)
                                         ? Color(nsColor: MatteTheme.dynamicColor(.success)) : Color.bmuxTextTertiary)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(step.text)
                            .font(.system(size: 12))
                            .foregroundStyle(Color(nsColor: MatteTheme.dynamicColor(.textSecondary)))
                            .fixedSize(horizontal: false, vertical: true)
                        Text(AgentSessionPlanStepStatus(step.status).label(locale: locale))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color.bmuxTextTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .textSelection(.enabled)
                }
            }
            if visible.previousPage != nil || visible.nextPage != nil {
                VStack(alignment: .leading, spacing: 4) {
                    Text(String.localizedStringWithFormat(
                        String(localized: "agentSession.factual.plan.page", defaultValue: "%d–%d of %d steps"),
                        visible.start + 1, visible.end, visible.total
                    ))
                    HStack {
                        Button(String(localized: "agentSession.factual.plan.previous", defaultValue: "Previous steps")) {
                            if let previous = visible.previousPage { page = previous }
                        }
                        .disabled(visible.previousPage == nil)
                        Button(String(localized: "agentSession.factual.plan.next", defaultValue: "Next steps")) {
                            if let next = visible.nextPage { page = next }
                        }
                        .disabled(visible.nextPage == nil)
                    }
                }
                .font(.system(size: 11))
                .buttonStyle(.link)
            }
        }
        .onChange(of: plan.steps.count) { _, _ in
            page = AgentSessionPlanPage(steps: plan.steps, requestedPage: page).currentPage
        }
    }
}
