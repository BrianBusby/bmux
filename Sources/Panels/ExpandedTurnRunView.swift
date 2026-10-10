import SwiftUI

struct ExpandedTurnRunView: View {
    let presentation: ExpandedTurnPresentation

    @ScaledMetric(relativeTo: .body) private var valueSize = 15

    var body: some View {
        ExpandedTurnSection(title: String(localized: "agentSession.expanded.run", defaultValue: "Run")) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), alignment: .leading)], alignment: .leading, spacing: 12) {
                fact(String(localized: "agentSession.factual.status", defaultValue: "Status"), presentation.reference.status, color: ExpandedTurnStatus(raw: presentation.reference.status).color)
                fact(String(localized: "agentSession.expanded.durationLabel", defaultValue: "Duration"), durationText)
                fact(String(localized: "agentSession.factual.model", defaultValue: "Model"), presentation.detail?.turn.model ?? "—")
                fact(String(localized: "agentSession.factual.commands", defaultValue: "Commands"), count(presentation.detail?.completedCommands.count))
                fact(String(localized: "agentSession.expanded.reasoningSteps", defaultValue: "Reasoning steps"), count(presentation.detail?.visibleReasoningSummaries.count))
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "agentSession.expanded.outputsFiles", defaultValue: "Outputs · Files")).font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Text(count(presentation.detail?.assistantMessages.count))
                            .accessibilityLabel(String(localized: "agentSession.factual.outputs", defaultValue: "Outputs"))
                            .accessibilityValue(count(presentation.detail?.assistantMessages.count))
                        Text(verbatim: "·").accessibilityHidden(true)
                        Text(count(presentation.detail?.fileChangeAttributions.count))
                            .accessibilityLabel(String(localized: "agentSession.factual.files", defaultValue: "Files"))
                            .accessibilityValue(count(presentation.detail?.fileChangeAttributions.count))
                    }.font(.system(size: valueSize, weight: .medium)).monospacedDigit()
                }
            }
            .padding(12).background(.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
            Rectangle().fill(.tint.opacity(0.4)).frame(height: 2).accessibilityHidden(true)
            ViewThatFits(in: .horizontal) {
                HStack { timestamp(start: true).fixedSize(); Spacer(); timestamp(start: false).fixedSize() }
                VStack(alignment: .leading, spacing: 4) { timestamp(start: true); timestamp(start: false) }
            }
            .font(.caption).foregroundStyle(.secondary).monospacedDigit()
        }
    }

    private func fact(_ label: String, _ value: String, color: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(verbatim: value).font(.system(size: valueSize, weight: .medium)).foregroundStyle(color)
                .monospacedDigit().fixedSize(horizontal: false, vertical: true)
        }.accessibilityElement(children: .combine)
    }

    private func count(_ value: Int?) -> String { presentation.count(value).map { $0.formatted() } ?? "—" }

    private var durationText: String {
        guard let duration = presentation.duration else { return "—" }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "—"
    }

    private func timestamp(start: Bool) -> some View {
        let date = start ? presentation.reference.startedAt : presentation.reference.completedAt
        return Text(String.localizedStringWithFormat(
            start ? String(localized: "agentSession.factual.started", defaultValue: "Started %@")
                : String(localized: "agentSession.factual.finished", defaultValue: "Finished %@"),
            date?.formatted(date: .abbreviated, time: .shortened) ?? "—"
        )).fixedSize(horizontal: false, vertical: true)
    }
}
