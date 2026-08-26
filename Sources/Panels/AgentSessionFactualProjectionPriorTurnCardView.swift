import Foundation
import AppKit
import SwiftUI
import ProvenanceEngineContracts

struct AgentSessionFactualProjectionPriorTurnCardView: View {
    let item: AgentSessionFactualProjectionEvidenceRows.PriorTurnItem
    let ordinal: Int
    let isExpanded: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                onToggle()
            } label: {
                VStack(alignment: .leading, spacing: 10) {
                    header
                    Text(prompt)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                    metadata
                    labeledText(
                        String(localized: "agentSession.factual.summary", defaultValue: "Summary"),
                        summary,
                        lineLimit: 3
                    )
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                expandedDetails
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(Color.secondary.opacity(0.16))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(prompt))
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 12)
            Text(String.localizedStringWithFormat(
                String(localized: "agentSession.factual.turnOrdinal", defaultValue: "Turn %d"),
                ordinal
            ))
            .font(.system(size: 12, weight: .semibold))
            badge(status)
            Spacer(minLength: 0)
            Text(dateText(finishedAt))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }

    private var metadata: some View {
        VStack(alignment: .leading, spacing: 4) {
            metadataLine(
                systemImage: "clock",
                text: String.localizedStringWithFormat(
                    String(localized: "agentSession.factual.started", defaultValue: "Started %@"),
                    dateText(startedAt)
                )
            )
            metadataLine(
                systemImage: "checkmark.circle",
                text: String.localizedStringWithFormat(
                    String(localized: "agentSession.factual.finished", defaultValue: "Finished %@"),
                    dateText(finishedAt)
                )
            )
            metadataLine(
                systemImage: "timer",
                text: String.localizedStringWithFormat(
                    String(localized: "agentSession.factual.duration", defaultValue: "Duration %@"),
                    durationText
                )
            )
        }
    }

    private var expandedDetails: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()
            Text(String(localized: "agentSession.factual.details", defaultValue: "Details"))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            details
        }
        .padding(.top, 12)
    }

    @ViewBuilder
    private var details: some View {
        switch item {
        case .detail(let turnSnapshot):
            AgentSessionFactualProjectionTurnDetailView(turnSnapshot: turnSnapshot)
        case .reference(let turn):
            referenceRow(turn)
        }
    }

    private func referenceRow(_ turn: ProvenanceFactualSessionProjectionTurnReference) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            badge(turn.status)
            Text(turn.providerTurnID)
                .font(.system(size: 12, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 0)
            Text(dateText(turn.completedAt ?? turn.updatedAt))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }

    private func metadataLine(systemImage: String, text: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .labelStyle(.titleAndIcon)
    }

    private var prompt: String {
        switch item {
        case .detail(let turnSnapshot):
            if let text = turnSnapshot.submittedPrompt?.text.trimmingCharacters(in: .whitespacesAndNewlines),
               !text.isEmpty {
                return text
            }
            return String(localized: "agentSession.factual.prompt.missing", defaultValue: "No prompt captured")
        case .reference:
            return String(localized: "agentSession.factual.prompt.missing", defaultValue: "No prompt captured")
        }
    }

    private var summary: String {
        switch item {
        case .detail(let turnSnapshot):
            if let summary = turnSnapshot.fileChangeAttributions.compactMap(\.summary).last?.trimmingCharacters(in: .whitespacesAndNewlines),
               !summary.isEmpty {
                return summary
            }
            if let summary = turnSnapshot.visibleReasoningSummaries.last?.text.trimmingCharacters(in: .whitespacesAndNewlines),
               !summary.isEmpty {
                return summary
            }
            if !turnSnapshot.completedCommands.isEmpty {
                return String.localizedStringWithFormat(
                    String(localized: "agentSession.factual.summary.commands", defaultValue: "Ran %d commands"),
                    turnSnapshot.completedCommands.count
                )
            }
            return String.localizedStringWithFormat(
                String(localized: "agentSession.factual.summary.status", defaultValue: "Turn ended with status %@"),
                turnSnapshot.turn.status
            )
        case .reference(let turn):
            return String.localizedStringWithFormat(
                String(localized: "agentSession.factual.summary.status", defaultValue: "Turn ended with status %@"),
                turn.status
            )
        }
    }

    private var status: String {
        switch item {
        case .detail(let turnSnapshot):
            turnSnapshot.turn.status
        case .reference(let turn):
            turn.status
        }
    }

    private var startedAt: Date? {
        switch item {
        case .detail(let turnSnapshot):
            turnSnapshot.turn.startedAt
        case .reference(let turn):
            turn.startedAt
        }
    }

    private var finishedAt: Date {
        switch item {
        case .detail(let turnSnapshot):
            turnSnapshot.turn.completedAt ?? turnSnapshot.turn.updatedAt
        case .reference(let turn):
            turn.completedAt ?? turn.updatedAt
        }
    }

    private var durationText: String {
        guard let startedAt else {
            return String(localized: "agentSession.factual.unknown", defaultValue: "Unknown")
        }
        let duration = max(0, finishedAt.timeIntervalSince(startedAt))
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = duration >= 3_600 ? [.hour, .minute, .second] : [.minute, .second]
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2
        if let text = formatter.string(from: duration), !text.isEmpty {
            return text
        }
        return String.localizedStringWithFormat(
            String(localized: "agentSession.factual.duration.seconds", defaultValue: "%.0f sec"),
            duration
        )
    }

    private func labeledText(_ label: String, _ text: String, lineLimit: Int) -> some View {
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

    private func dateText(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }

    private func dateText(_ date: Date?) -> String {
        guard let date else {
            return String(localized: "agentSession.factual.unknown", defaultValue: "Unknown")
        }
        return dateText(date)
    }
}
