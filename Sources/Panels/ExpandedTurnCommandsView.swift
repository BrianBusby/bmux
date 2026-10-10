import SwiftUI

struct ExpandedTurnCommandsView: View {
    let commands: [ExpandedTurnCommandRow]
    @Binding var navigation: ExpandedTurnCommandNavigation

    var body: some View {
        ExpandedTurnSection(title: String(localized: "agentSession.expanded.did", defaultValue: "What it did")) {
            if commands.isEmpty {
                Text(String(localized: "agentSession.expanded.commandsUnavailable", defaultValue: "Command evidence is unavailable for this turn."))
                    .foregroundStyle(.secondary)
            } else {
                let categories = commands.map(\.presentation.category)
                let matchingCount = categories.filter { navigation.selected == nil || $0 == navigation.selected }.count
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 135), alignment: .leading)], alignment: .leading) {
                    chip(nil, count: commands.count)
                    ForEach(ExpandedTurnCommandCategory.allCases, id: \.self) { category in
                        let count = categories.filter { $0 == category }.count
                        if count > 0 { chip(category, count: count) }
                    }
                }
                Text(String(localized: "agentSession.expanded.recordedOnly", defaultValue: "Counts describe recorded evidence; unrecorded activity is unavailable."))
                    .font(.caption).foregroundStyle(.secondary)
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(navigation.visibleIndices(categories: categories).map { commands[$0] }) { row in
                        let failed = ExpandedTurnStatus(raw: row.record.status).failed
                        ExpandedTurnCommandRowView(row: row, isExpanded: navigation.isExpanded(id: row.id, failed: failed)) {
                            navigation.toggle(id: row.id, failed: failed)
                        }
                    }
                }
                if matchingCount > navigation.visibleLimit {
                    Button(String.localizedStringWithFormat(String(localized: "agentSession.expanded.moreCommands", defaultValue: "Show more (%d remaining)"), matchingCount - navigation.visibleLimit)) {
                        navigation.showMore()
                    }
                }
            }
        }
    }

    private func chip(_ category: ExpandedTurnCommandCategory?, count: Int) -> some View {
        let selected = navigation.selected == category
        let title = category?.title ?? String(localized: "agentSession.expanded.all", defaultValue: "All")
        return Button { navigation.select(category) } label: {
            Text(verbatim: "\(title) \(count.formatted())")
                .font(.caption).padding(.horizontal, 8).padding(.vertical, 4)
                .frame(maxWidth: .infinity)
                .background(selected ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.06), in: Capsule())
                .overlay(Capsule().stroke(selected ? Color.accentColor : .secondary.opacity(0.3)))
        }
        .buttonStyle(.borderless)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}
