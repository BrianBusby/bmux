import SwiftUI

struct ExpandedTurnCommandRowView: View {
    let row: ExpandedTurnCommandRow
    let isExpanded: Bool
    let onToggle: () -> Void

    @ScaledMetric(relativeTo: .body) private var labelSize = 13

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: onToggle) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right").accessibilityHidden(true)
                        Text(verbatim: row.record.status).foregroundStyle(ExpandedTurnStatus(raw: row.record.status).color)
                        Text(row.presentation.category.title).foregroundStyle(.secondary)
                    }.font(.caption)
                    Text(verbatim: row.presentation.isProxy
                         ? String(localized: "agentSession.expanded.proxy", defaultValue: "Run command via bmux proxy")
                         : row.presentation.preview)
                        .font(.system(size: labelSize, weight: .medium))
                        .fixedSize(horizontal: false, vertical: true)
                    if let target = row.presentation.target {
                        Text(verbatim: target).font(.system(size: 12, design: .monospaced)).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if row.presentation.isProxy {
                        Text(verbatim: row.presentation.preview).font(.system(size: 12, design: .monospaced)).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityValue(isExpanded
                ? String(localized: "agentSession.expanded.expanded", defaultValue: "Expanded")
                : String(localized: "agentSession.expanded.collapsed", defaultValue: "Collapsed"))
            if isExpanded {
                ExpandedTurnEvidenceText(text: row.record.command, monospaced: true)
                if let output = row.record.outputSummary, !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(String(localized: "agentSession.expanded.result", defaultValue: "Recorded result")).font(.caption).foregroundStyle(.secondary)
                    ExpandedTurnEvidenceText(text: output, monospaced: true)
                } else if ExpandedTurnStatus(raw: row.record.status).failed {
                    Text(String(localized: "agentSession.expanded.noError", defaultValue: "No error output recorded.")).font(.caption).foregroundStyle(.secondary)
                }
            }
        }.padding(10).background(.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
    }
}
