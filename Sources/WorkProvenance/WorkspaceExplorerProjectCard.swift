import AppKit
import SwiftUI

/// One project summary in the Explorer overview.
struct WorkspaceExplorerProjectCard: View {
    let project: WorkspaceExplorerProject?
    let counts: WorkspaceExplorerCounts
    let scope: WorkspaceExplorerScope
    let openTotal: Int
    let matchingCount: Int?
    let isFocused: Bool
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 10) {
                Text(project?.name ?? String(localized: "explorer.unassigned", defaultValue: "Unassigned workspaces"))
                    .font(.system(size: 16, weight: .bold))
                    .lineLimit(2)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(counts.workspaces.formatted()).font(.system(size: 24, weight: .bold))
                    Text(countLabel)
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                }
                if let matchingCount {
                    Text(String(format: String(localized: "explorer.matchCount", defaultValue:
                        "%d match filters"), matchingCount))
                        .font(.system(size: 11)).foregroundStyle(Color.accentColor)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 90, alignment: .topLeading)
            .padding(14)
            .background(Color(nsColor: .controlBackgroundColor),
                in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isFocused ? Color.accentColor : Color(nsColor: .separatorColor),
                    lineWidth: isFocused ? 2 : 1))
        }
        .buttonStyle(.plain)
    }

    private var countLabel: String {
        switch scope.state {
        case .open:
            if scope.period == .anyTime {
                return String(localized: "explorer.count.open", defaultValue: "open workspaces")
            }
            return String(format: String(localized: "explorer.count.openPeriod", defaultValue:
                "matching open · %d open total"), openTotal)
        case .all:
            let label = scope.period == .anyTime ?
                String(localized: "explorer.count.all", defaultValue: "workspaces") :
                String(localized: "explorer.count.allPeriod", defaultValue: "matching workspaces")
            guard counts.closedKnown else {
                return label + " · " + String(localized: "explorer.count.closedUnknown", defaultValue: "closed unknown")
            }
            return label + " · " + String(format: String(localized: "explorer.count.breakdown", defaultValue:
                "%d open · %d closed"), counts.open, counts.closed)
        case .closed:
            return scope.period == .anyTime ?
                String(localized: "explorer.count.closed", defaultValue: "closed workspaces") :
                String(localized: "explorer.count.closedPeriod", defaultValue: "matching closed workspaces")
        }
    }
}
