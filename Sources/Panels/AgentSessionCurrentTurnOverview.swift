import SwiftUI
import ProvenanceEngineContracts

private extension Color {
    static let bmuxLinkGreen = Color(red: 0.478, green: 0.620, blue: 0.416)
}

struct AgentSessionCurrentTurnOverview: View {
    let turn: ProvenanceFactualSessionProjectionTurnSnapshot

    var body: some View {
        let objective = turnObjective(turn)
        let summary = turnAgentSummary(turn)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(String(localized: "agentSession.factual.latestTurn", defaultValue: "Current turn"))
                    .font(.system(size: 11, weight: .medium))
                    .tracking(1.2)
                    .foregroundStyle(Color.workspaceReferenceTextTertiary)
                Spacer()
                Text(turnElapsedText(turn))
                    .font(.system(size: 12))
                    .foregroundStyle(Color.workspaceReferenceTextTertiary)
            }
            Text(summary ?? objective ?? String(localized: "agentSession.factual.noTurns", defaultValue: "No turns observed."))
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.workspaceReferenceTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
            if let objective {
                VStack(alignment: .leading, spacing: 3) {
                    Text(String(localized: "agentSession.factual.objective", defaultValue: "Objective"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.workspaceReferenceTextTertiary)
                    Text(objective)
                        .font(.system(size: 13.5))
                        .foregroundStyle(Color.workspaceReferenceTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if summary == nil {
                Text(String(localized: "agentSession.factual.noAgentSummary", defaultValue: "No agent summary observed."))
                    .font(.system(size: 13.5))
                    .foregroundStyle(Color.workspaceReferenceTextTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 8) {
                Text(summary == nil
                     ? String(localized: "agentSession.factual.evidenceSource", defaultValue: "Observed evidence")
                     : String(localized: "agentSession.factual.source", defaultValue: "Agent-reported"))
                    .foregroundStyle(Color.workspaceReferenceTextTertiary)
                DisclosureGroup(String(localized: "agentSession.factual.details", defaultValue: "View evidence")) {
                    AgentSessionFactualProjectionTurnDetailView(turnSnapshot: turn)
                        .padding(.top, 6)
                }
                .font(.system(size: 12))
                .foregroundStyle(Color.bmuxLinkGreen)
            }
        }
        .padding(.leading, 14)
        .overlay(alignment: .leading) {
            Rectangle().fill(Color.bmuxLinkGreen).frame(width: 2)
        }
    }

    private func turnObjective(_ turn: ProvenanceFactualSessionProjectionTurnSnapshot) -> String? {
        let prompt = turn.submittedPrompt?.text.trimmingCharacters(in: .whitespacesAndNewlines)
        return prompt?.isEmpty == false ? prompt : nil
    }

    private func turnAgentSummary(_ turn: ProvenanceFactualSessionProjectionTurnSnapshot) -> String? {
        guard let output = AgentSessionFactualProjectionEvidenceRows.finalAssistantMessageText(for: turn)?
            .trimmingCharacters(in: .whitespacesAndNewlines), !output.isEmpty else { return nil }
        guard normalizeTurnText(output) != normalizeTurnText(turnObjective(turn) ?? "") else { return nil }
        return output
    }

    private func normalizeTurnText(_ text: String) -> String {
        text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ").lowercased()
    }

    private func turnElapsedText(_ turn: ProvenanceFactualSessionProjectionTurnSnapshot) -> String {
        guard let started = turn.turn.startedAt else {
            return String(localized: "agentSession.factual.unknown", defaultValue: "Unknown")
        }
        let end = turn.turn.completedAt ?? turn.turn.updatedAt
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2
        return formatter.string(from: max(0, end.timeIntervalSince(started)))
            ?? String(localized: "agentSession.factual.unknown", defaultValue: "Unknown")
    }
}
