import Foundation
import AppKit
import SwiftUI
import ProvenanceEngineContracts

private extension Color {
    static let bmuxCard = Color(red: 0.122, green: 0.125, blue: 0.137)
    static let bmuxTextPrimary = Color(red: 0.949, green: 0.953, blue: 0.969)
    static let bmuxTextSecondary = Color(red: 0.737, green: 0.753, blue: 0.792)
    static let bmuxTextTertiary = Color(red: 0.635, green: 0.651, blue: 0.698)
}

struct AgentSessionFactualProjectionPriorTurnCardView: View {
    let item: AgentSessionFactualProjectionEvidenceRows.PriorTurnItem
    let ordinal: Int
    let isExpanded: Bool
    let onToggle: () -> Void

    @State private var detailPresentation: ExpandedTurnPresentation?
    @State private var commands: [ExpandedTurnCommandRow] = []
    @State private var navigation = ExpandedTurnCommandNavigation()

    private var presentation: ExpandedTurnPresentation {
        switch item {
        case .detail(let detail):
            ExpandedTurnPresentation(reference: .init(turn: detail.turn), detail: detail)
        case .reference(let reference):
            ExpandedTurnPresentation(reference: reference, detail: nil)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                onToggle()
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    header
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(isExpanded
                ? String(localized: "agentSession.expanded.expanded", defaultValue: "Expanded")
                : String(localized: "agentSession.expanded.collapsed", defaultValue: "Collapsed"))

            if isExpanded {
                expandedDetails
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.bmuxCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(Color.secondary.opacity(0.16))
        )
        .onChange(of: item, initial: true) { _, item in
            detailPresentation = presentation
            let records: [ProvenanceCodingAgentCommandRecord]
            if case .detail(let detail) = item { records = detail.completedCommands } else { records = [] }
            let previous = Dictionary(commands.map { ($0.id, $0.presentation) }, uniquingKeysWith: { first, _ in first })
            commands = records.map { record in
                let cached = previous[record.id]
                let display: ExpandedTurnCommandPresentation
                if let cached, cached.raw == record.command { display = cached }
                else { display = ExpandedTurnCommandPresentation(raw: record.command) }
                return ExpandedTurnCommandRow(record: record, presentation: display)
            }
            if let selected = navigation.selected,
               !commands.contains(where: { $0.presentation.category == selected }) {
                navigation.select(nil)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color.bmuxTextSecondary)
                .frame(width: 12)
            Text(compactTitle)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.bmuxTextPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
            badge(status)
            Spacer(minLength: 0)
            Text(compactDateText)
                .font(.system(size: 11))
                .foregroundStyle(Color.bmuxTextTertiary)
        }
    }

    private var compactTitle: String {
        let value = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if !value.isEmpty, value != String(localized: "agentSession.factual.prompt.missing", defaultValue: "No prompt captured") {
            let firstLine = value.components(separatedBy: .newlines).first ?? value
            let sentence = firstLine.split(separator: ".", maxSplits: 1).first.map(String.init) ?? firstLine
            let title = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
            if title.count <= 72 { return title }
            return String(title.prefix(69)).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
        }
        return String.localizedStringWithFormat(
            String(localized: "agentSession.factual.turnOrdinal", defaultValue: "Turn %d"), ordinal
        )
    }

    private var compactDateText: String {
        let relative = RelativeDateTimeFormatter()
        relative.unitsStyle = .abbreviated
        return relative.localizedString(for: finishedAt, relativeTo: Date())
    }

    private var expandedDetails: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()
            if let detailPresentation {
                ExpandedTurnDetailView(presentation: detailPresentation, commands: commands, navigation: $navigation)
            }
        }.padding(.top, 12)
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

    private var status: String {
        switch item {
        case .detail(let turnSnapshot):
            turnSnapshot.turn.status
        case .reference(let turn):
            turn.status
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
