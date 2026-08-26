import Foundation
import AppKit
import BmuxFoundation
import SwiftUI

struct SessionTranscriptTurnCardView: View, Equatable {
    let card: SessionTranscriptTurnCard
    let isExpanded: Bool
    let onToggle: () -> Void

    static func == (lhs: SessionTranscriptTurnCardView, rhs: SessionTranscriptTurnCardView) -> Bool {
        lhs.card == rhs.card && lhs.isExpanded == rhs.isExpanded
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            metadata
            summary
            if isExpanded {
                details
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(Color.primary.opacity(isExpanded ? 0.16 : 0.08), lineWidth: 1)
        )
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                Text(
                    String.localizedStringWithFormat(
                        String(localized: "sessionIndex.turn.ordinal", defaultValue: "Turn %d"),
                        card.ordinal
                    )
                )
                .bmuxFont(size: 11, weight: .semibold)
                .foregroundColor(.secondary)
                .lineLimit(1)
                Spacer(minLength: 8)
                Image(systemName: "chevron.down")
                    .bmuxFont(size: 10, weight: .semibold)
                    .foregroundColor(.secondary.opacity(0.7))
                    .rotationEffect(.degrees(isExpanded ? 0 : -90))
            }
            Text(card.prompt)
                .bmuxFont(size: 13, weight: .semibold)
                .foregroundColor(.primary)
                .lineLimit(isExpanded ? 4 : 2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onToggle()
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(Text(card.prompt))
    }

    private var metadata: some View {
        VStack(alignment: .leading, spacing: 3) {
            metadataRow(
                systemImage: "clock",
                text: String.localizedStringWithFormat(
                    String(localized: "sessionIndex.turn.started", defaultValue: "Started %@"),
                    timeText(card.startedAt)
                )
            )
            metadataRow(
                systemImage: "checkmark.circle",
                text: String.localizedStringWithFormat(
                    String(localized: "sessionIndex.turn.finished", defaultValue: "Finished %@"),
                    timeText(card.finishedAt)
                )
            )
            metadataRow(
                systemImage: "timer",
                text: String.localizedStringWithFormat(
                    String(localized: "sessionIndex.turn.duration", defaultValue: "Duration %@"),
                    durationText(card.duration)
                )
            )
        }
    }

    private func metadataRow(systemImage: String, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .bmuxFont(size: 10, weight: .medium)
                .foregroundColor(.secondary.opacity(0.72))
                .frame(width: 12)
            Text(text)
                .bmuxFont(size: 11, monospacedDigit: true)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(String(localized: "sessionIndex.turn.summary.label", defaultValue: "Summary"))
                .bmuxFont(size: 10, weight: .semibold)
                .foregroundColor(.secondary.opacity(0.76))
            Text(card.summary)
                .bmuxFont(size: 12)
                .foregroundColor(.primary.opacity(0.9))
                .lineLimit(isExpanded ? 5 : 2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
                .padding(.vertical, 2)
            Text(String(localized: "sessionIndex.turn.details.label", defaultValue: "Details"))
                .bmuxFont(size: 10, weight: .semibold)
                .foregroundColor(.secondary.opacity(0.76))
                .padding(.bottom, 4)
            VStack(alignment: .leading, spacing: 0) {
                ForEach(SessionTranscriptDisplayRow.rows(from: card.details)) { row in
                    SessionTranscriptTurnView(row: row)
                        .id(row.id)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
        }
    }

    private func timeText(_ date: Date?) -> String {
        guard let date else {
            return String(localized: "sessionIndex.turn.time.unknown", defaultValue: "Unknown")
        }
        return SessionIndexView.absoluteFormatter.string(from: date)
    }

    private func durationText(_ duration: TimeInterval?) -> String {
        guard let duration else {
            return String(localized: "sessionIndex.turn.time.unknown", defaultValue: "Unknown")
        }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = duration >= 3_600 ? [.hour, .minute] : [.minute, .second]
        formatter.maximumUnitCount = 2
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration)
            ?? String.localizedStringWithFormat(
                String(localized: "sessionIndex.turn.duration.seconds", defaultValue: "%.0f sec"),
                duration
            )
    }
}
