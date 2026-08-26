import SwiftUI
import ProvenanceEngineContracts

struct AgentSessionFactualProjectionTurnDetailView: View {
    let turnSnapshot: ProvenanceFactualSessionProjectionTurnSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(
                Array(AgentSessionFactualProjectionEvidenceRows.turnProperties(for: turnSnapshot).enumerated()),
                id: \.offset
            ) { _, property in
                turnPropertyRow(property)
            }
            if let plan = turnSnapshot.currentPlan {
                planRows(plan)
            }
            summaryCounts
            assistantOutputRows(turnSnapshot.assistantMessages)
            commandRows(turnSnapshot.completedCommands)
            reasoningRows(turnSnapshot.visibleReasoningSummaries)
            fileRows(turnSnapshot.fileChangeAttributions)
        }
    }

    @ViewBuilder
    private func turnPropertyRow(_ property: AgentSessionFactualProjectionEvidenceRows.TurnProperty) -> some View {
        switch property {
        case .prompt(let prompt):
            labeledText(String(localized: "agentSession.factual.prompt", defaultValue: "Prompt"), prompt, lineLimit: 4)
        case .providerTurnID(let providerTurnID):
            factRow(String(localized: "agentSession.factual.providerTurnID", defaultValue: "Provider turn ID"), providerTurnID)
        case .peTurnID(let peTurnID):
            factRow(String(localized: "agentSession.factual.peTurnID", defaultValue: "PE turn ID"), peTurnID)
        case .peThreadID(let peThreadID):
            factRow(String(localized: "agentSession.factual.peThreadID", defaultValue: "PE thread ID"), peThreadID)
        case .status(let status):
            factRow(String(localized: "agentSession.factual.status", defaultValue: "Status"), status)
        case .model(let model):
            factRow(String(localized: "agentSession.factual.model", defaultValue: "Model"), model)
        }
    }

    private func planRows(_ plan: ProvenanceCodingAgentPlanUpdateRecord) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(String(localized: "agentSession.factual.plan", defaultValue: "Current plan"))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            ForEach(plan.steps.prefix(6), id: \.id) { step in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    badge(step.status)
                    Text(step.text)
                        .font(.system(size: 12))
                        .lineLimit(2)
                }
            }
        }
    }

    private var summaryCounts: some View {
        HStack(spacing: 8) {
            countBadge(
                String(localized: "agentSession.factual.commands", defaultValue: "Commands"),
                turnSnapshot.completedCommands.count
            )
            countBadge(
                String(localized: "agentSession.factual.reasoning", defaultValue: "Reasoning"),
                turnSnapshot.visibleReasoningSummaries.count
            )
            countBadge(
                String(localized: "agentSession.factual.outputs", defaultValue: "Outputs"),
                turnSnapshot.assistantMessages.count
            )
            countBadge(
                String(localized: "agentSession.factual.files", defaultValue: "Files"),
                turnSnapshot.fileChangeAttributions.count
            )
        }
    }

    @ViewBuilder
    private func assistantOutputRows(_ messages: [ProvenanceCodingAgentAssistantMessageRecord]) -> some View {
        if let finalOutput = messages.last?.text {
            labeledText(
                String(localized: "agentSession.factual.finalOutput", defaultValue: "Final output"),
                finalOutput,
                lineLimit: nil
            )
        }
    }

    private func commandRows(_ commands: [ProvenanceCodingAgentCommandRecord]) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(AgentSessionFactualProjectionEvidenceRows.latestRows(commands, limit: 5), id: \.id) { command in
                labeledText(command.status, command.command, lineLimit: 2)
            }
        }
    }

    private func reasoningRows(_ summaries: [ProvenanceCodingAgentReasoningSummaryRecord]) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(summaries, id: \.id) { summary in
                labeledText(
                    String(localized: "agentSession.factual.reasoningSummary", defaultValue: "Reasoning summary"),
                    summary.text,
                    lineLimit: nil
                )
            }
        }
    }

    private func fileRows(_ attributions: [ProvenanceCodingAgentFileChangeAttributionRecord]) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(AgentSessionFactualProjectionEvidenceRows.latestRows(attributions, limit: 4), id: \.id) { attribution in
                labeledText(
                    String(localized: "agentSession.factual.fileChange", defaultValue: "File change"),
                    attribution.summary ?? attribution.paths.prefix(4).joined(separator: ", "),
                    lineLimit: 2
                )
            }
        }
    }

    private func factRow(_ label: String, _ value: String?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 84, alignment: .leading)
            Text(nonEmpty(value))
                .font(.system(size: 12))
                .lineLimit(2)
                .truncationMode(.middle)
        }
    }

    private func labeledText(_ label: String, _ text: String, lineLimit: Int?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            Text(nonEmpty(text))
                .font(.system(size: 12))
                .lineLimit(lineLimit)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func countBadge(_ label: String, _ count: Int) -> some View {
        badge("\(label): \(count)")
    }

    private func badge(_ text: String) -> some View {
        Text(nonEmpty(text))
            .font(.system(size: 10, weight: .medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.secondary.opacity(0.12), in: Capsule())
    }

    private func nonEmpty(_ value: String?) -> String {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmed.isEmpty { return trimmed }
        return String(localized: "agentSession.factual.unknown", defaultValue: "Unknown")
    }
}
