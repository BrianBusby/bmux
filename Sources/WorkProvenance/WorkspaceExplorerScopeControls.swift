import SwiftUI

/// Explorer-wide state and activity controls driven by a value snapshot.
struct WorkspaceExplorerScopeControls: View {
    let scope: WorkspaceExplorerScope
    let onState: (WorkspaceExplorerScope.State) -> Void
    let onPeriod: (WorkspaceExplorerScope.Period) -> Void

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 2) {
                scopeButton(String(localized: "explorer.open", defaultValue: "Open"),
                    state: .open)
                scopeButton(String(localized: "explorer.past", defaultValue: "Past"),
                    state: .closed)
                scopeButton(String(localized: "explorer.all", defaultValue: "All"),
                    state: .all)
            }
            .padding(2)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            Menu(periodTitle(scope.period)) {
                periodOption(.anyTime)
                periodOption(.last24Hours)
                periodOption(.today)
                periodOption(.last7Days)
            }
            Spacer()
        }
        .font(.system(size: 12))
    }

    private func scopeButton(_ title: String, state: WorkspaceExplorerScope.State) -> some View {
        Button(title) { onState(state) }
            .buttonStyle(.plain)
            .padding(.horizontal, 12).padding(.vertical, 5)
            .background(scope.state == state ? Color.accentColor.opacity(0.18) : Color.clear,
                in: RoundedRectangle(cornerRadius: 6))
            .accessibilityAddTraits(scope.state == state ? .isSelected : [])
    }

    private func periodOption(_ period: WorkspaceExplorerScope.Period) -> some View {
        Button(periodTitle(period)) { onPeriod(period) }
    }

    private func periodTitle(_ period: WorkspaceExplorerScope.Period) -> String {
        switch period {
        case .anyTime: String(localized: "explorer.anyTime", defaultValue: "Any time")
        case .last24Hours: String(localized: "explorer.last24Hours", defaultValue: "Last 24 hours")
        case .today: String(localized: "explorer.today", defaultValue: "Today")
        case .last7Days: String(localized: "explorer.last7Days", defaultValue: "Last 7 days")
        }
    }
}
