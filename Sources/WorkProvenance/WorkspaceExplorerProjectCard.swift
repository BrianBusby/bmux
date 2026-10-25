import AppKit
import SwiftUI

/// One project summary in the Explorer overview.
struct WorkspaceExplorerProjectCard: View {
    let project: WorkspaceExplorerProject?
    let counts: WorkspaceExplorerCounts
    let workspaces: [WorkspaceExplorerWorkspace]
    let repositoryNamesByID: [String: String]
    let scope: WorkspaceExplorerScope
    let archiveAvailability: WorkspaceExplorerArchiveAvailability
    let openTotal: Int
    let matchingCount: Int?
    let isFocused: Bool
    let titleGeometry: Namespace.ID
    let onOpen: () -> Void
    let onInteractionChanged: (Bool) -> Void
    @State private var isHovered = false
    @FocusState private var hasKeyboardFocus: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 10) {
                Text(project?.name ?? String(localized: "explorer.unassigned", defaultValue: "Unassigned workspaces"))
                    .matchedGeometryEffect(id: "title:\(project?.id ?? "unassigned")", in: titleGeometry)
                    .font(.system(size: 16, weight: .bold))
                    .lineLimit(2)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(counts.workspaces.formatted()).font(.system(size: 24, weight: .bold))
                    Text(countLabel)
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                }
                if let matchingCount {
                    Text(String(format: String(localized: "explorer.matchOfScope", defaultValue:
                        "%d match filters / %d in scope"), matchingCount, counts.workspaces))
                        .font(.system(size: 11)).foregroundStyle(Color.accentColor)
                }
                Text(activitySummary)
                    .font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(2)
                if !repositories.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(repositories.prefix(3), id: \.self) { repository in
                            Text(repositoryNamesByID[repository] ?? repository)
                                .font(.system(size: 10, design: .monospaced))
                                .lineLimit(1).padding(.horizontal, 6).padding(.vertical, 3)
                                .background(Color(nsColor: .controlColor), in: Capsule())
                        }
                    }
                }
                if let last = workspaces.compactMap(\.lastActivityAt).max() {
                    HStack(spacing: 4) {
                        Text(String(localized: "explorer.lastActive", defaultValue: "Last active"))
                        Text(last, style: .relative)
                    }
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 90, alignment: .topLeading)
            .padding(14)
            .background(Color(nsColor: .controlBackgroundColor),
                in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isFocused ? Color.accentColor : Color(nsColor: .separatorColor),
                    lineWidth: isFocused ? 2 : 1))
            .shadow(color: .black.opacity(colorScheme == .dark ? (isHovered ? 0.5 : 0.45) :
                (isHovered ? 0.15 : 0.07)), radius: isHovered ? 10 : 4, y: isHovered ? 4 : 2)
            .offset(y: isHovered && !reduceMotion ? -1 : 0)
        }
        .buttonStyle(.plain)
        .focused($hasKeyboardFocus)
        .overlay(RoundedRectangle(cornerRadius: 14)
            .strokeBorder(hasKeyboardFocus ? Color.accentColor : .clear, lineWidth: 2)
            .padding(-2).allowsHitTesting(false))
        .onHover { hovering in
            isHovered = hovering
            onInteractionChanged(hovering || hasKeyboardFocus)
        }
        .onChange(of: hasKeyboardFocus) { _, focused in
            onInteractionChanged(isHovered || focused)
        }
        .onDisappear { onInteractionChanged(false) }
    }

    private var repositories: [String] {
        Array(Set(workspaces.compactMap(\.repository))).sorted {
            let left = repositoryNamesByID[$0] ?? $0
            let right = repositoryNamesByID[$1] ?? $1
            let order = left.localizedStandardCompare(right)
            return order == .orderedSame ? $0 < $1 : order == .orderedAscending
        }
    }

    private var activitySummary: String {
        let error = workspaces.filter { $0.displayedStatus == .error }.count
        let needsInput = workspaces.filter { $0.displayedStatus == .needsInput }.count
        let running = workspaces.filter { $0.displayedStatus == .running }.count
        let disconnected = workspaces.filter { $0.displayedStatus == .disconnected }.count
        var parts: [String] = []
        if error > 0 { parts.append(String(format: String(localized: "explorer.projectErrors", defaultValue: "%d error"), error)) }
        if needsInput > 0 { parts.append(String(format: String(localized: "explorer.projectNeedsInput", defaultValue: "%d needs input"), needsInput)) }
        if running > 0 { parts.append(String(format: String(localized: "explorer.projectRunning", defaultValue: "%d running"), running)) }
        if disconnected > 0 {
            parts.append(String(format: String(localized: "explorer.projectDisconnected", defaultValue:
                "%d disconnected"), disconnected))
        }
        if scope.state != .open && counts.closed > 0 {
            parts.append(String(format: String(localized: "explorer.projectClosed", defaultValue: "%d closed"), counts.closed))
        }
        return parts.isEmpty && !workspaces.isEmpty ?
            String(localized: "explorer.projectAllIdle", defaultValue: "all idle") :
            parts.joined(separator: " · ")
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
                return label + " · " + (archiveAvailability.closedCountLabel ?? "")
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
