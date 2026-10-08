import SwiftUI

/// Disclosure state belongs to one session's history subtree, never the current-turn host.
struct ExpandedTurnHistoryView: View {
    let items: [AgentSessionFactualProjectionEvidenceRows.PriorTurnItem]
    @State private var expandedTurnIDs: Set<String> = []

    var body: some View {
        if items.isEmpty {
            Text(String(localized: "agentSession.factual.noPriorTurns", defaultValue: "No prior turns."))
                .font(.system(size: 12)).foregroundStyle(.secondary)
        } else {
            ForEach(Array(items.enumerated()), id: \.element.id) { offset, item in
                AgentSessionFactualProjectionPriorTurnCardView(
                    item: item, ordinal: offset + 1,
                    isExpanded: expandedTurnIDs.contains(item.id),
                    onToggle: {
                        if expandedTurnIDs.contains(item.id) { expandedTurnIDs.remove(item.id) }
                        else { expandedTurnIDs.insert(item.id) }
                    }
                )
            }
        }
    }
}
