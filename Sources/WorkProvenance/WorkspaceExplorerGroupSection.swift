import AppKit
import SwiftUI

/// Recursive display of one immutable grouping branch and its card snapshots.
struct WorkspaceExplorerGroupSection: View {
    let group: WorkspaceExplorerGroup
    let depth: Int
    let path: String
    let overview: Bool
    let collapsedPaths: Set<String>
    let activeFilters: [WorkspaceExplorerDimension: WorkspaceExplorerGroupKey]
    let projectsByID: [String: WorkspaceExplorerProject]
    let itemsByID: [String: WorkspaceExplorerHistoryItem]
    let projectCounts: [String: WorkspaceExplorerCounts]
    let projectOpenTotals: [String: Int]
    let scope: WorkspaceExplorerScope
    let matchingCounts: [String: Int]
    let focusedProjectID: String?
    let onOpenProject: (String) -> Void
    let onOpenWorkspace: (WorkspaceExplorerHistoryItem) -> Void
    let onHistory: (WorkspaceExplorerHistoryItem) -> Void
    let onReopen: (WorkspaceExplorerHistoryItem) -> Void
    let onCardFilter: (WorkspaceExplorerDimension, WorkspaceExplorerGroupKey) -> Void
    let onToggle: (String) -> Void
    let onFocus: (WorkspaceExplorerDimension, WorkspaceExplorerGroupKey) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let dimension = group.dimension {
                HStack(spacing: 8) {
                    Button {
                        onToggle(path)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: collapsedPaths.contains(path) ? "chevron.right" : "chevron.down")
                            Text(label)
                            Text(groupCount).foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: depth == 0 ? 15 : 13, weight: .semibold))
                    if let key = group.filterValue, activeFilters[dimension] != key {
                        Button(String(localized: "explorer.focus", defaultValue: "Focus")) {
                            onFocus(dimension, key)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    Spacer()
                }
            }
            if !collapsedPaths.contains(path) {
                if group.children.isEmpty {
                    cardGrid
                } else {
                    ForEach(Array(group.children.enumerated()), id: \.offset) { _, child in
                        WorkspaceExplorerGroupSection(group: child, depth: depth + 1,
                            path: path + "/" + String(reflecting: child.key),
                            overview: overview, collapsedPaths: collapsedPaths,
                            activeFilters: activeFilters, projectsByID: projectsByID,
                            itemsByID: itemsByID, projectCounts: projectCounts,
                            projectOpenTotals: projectOpenTotals, scope: scope,
                            matchingCounts: matchingCounts, focusedProjectID: focusedProjectID,
                            onOpenProject: onOpenProject, onOpenWorkspace: onOpenWorkspace,
                            onHistory: onHistory, onReopen: onReopen,
                            onCardFilter: onCardFilter, onToggle: onToggle, onFocus: onFocus)
                    }
                }
            }
        }
        .id(path)
        .padding(depth == 0 && group.dimension != nil ? 12 : 0)
        .background(depth == 0 && group.dimension != nil ? Color(nsColor: .controlBackgroundColor).opacity(0.45) : .clear,
            in: RoundedRectangle(cornerRadius: 12))
    }

    private var cardGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: overview ? 250 : 236), spacing: overview ? 12 : 10)],
                  spacing: overview ? 12 : 10) {
            if overview {
                ForEach(group.projectIDs, id: \.self) { id in
                    if let project = projectsByID[id] {
                        WorkspaceExplorerProjectCard(project: project,
                            counts: projectCounts[id] ?? WorkspaceExplorerCounts([], closedKnown: false),
                            scope: scope, openTotal: projectOpenTotals[id] ?? 0,
                            matchingCount: matchingCounts[id],
                            isFocused: focusedProjectID == id,
                            onOpen: { onOpenProject(id) })
                            .id("project:\(id)")
                            .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    }
                }
            } else {
                ForEach(group.workspaceIDs, id: \.self) { id in
                    if let item = itemsByID[id] {
                        WorkspaceExplorerWorkspaceCard(item: item,
                            onOpen: { onOpenWorkspace(item) },
                            onHistory: { onHistory(item) },
                            onReopen: { onReopen(item) },
                            onFilter: onCardFilter)
                            .id("workspace:\(id)")
                            .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    }
                }
            }
        }
        .scrollTargetLayout()
    }

    private var groupCount: String {
        if overview {
            return String(format: String(localized: "explorer.overviewGroupCount", defaultValue:
                "%d projects · %d in scope"), group.projectIDs.count, group.counts.workspaces)
        }
        if scope.state == .all && group.counts.closedKnown {
            return String(format: String(localized: "explorer.workspaceGroupBreakdown", defaultValue:
                "%d · %d open · %d closed"), group.counts.workspaces,
                group.counts.open, group.counts.closed)
        }
        return group.counts.workspaces.formatted()
    }

    private var label: String {
        group.key?.displayName(projectsByID: projectsByID) ?? group.value ?? ""
    }
}
